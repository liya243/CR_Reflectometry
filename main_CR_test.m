function main_CR_temperature_sweep()
    % Инициализация оборудования
    addpath('core');
    addpath('hardware');
    addpath('adlink');
    adc = PCIe_9852_2CH_INIT(-1);
    tbox = GetTBOX();
    clkg = GetCLOCKGEN();
    
    % Параметры эксперимента (можно вынести в отдельный конфиг файл)
    experiment_name = 'Температурное сканирование лазера';
    fiber_type = 'SMF-28'; % тип волокна
    fiber_length = 500; % длина волокна в метрах
    n_eff = 1.468; % эффективный показатель преломления
    operator_name = 'Ислам'; % имя оператора
    
    %Установка длины импульса в 10 дискретов
    pulse_length = 10;
    ComSet(clkg, 50, pulse_length)
    
    %Установка частоты сканирования в 2000 Гц
    scan_frequency = 2000;
    ComSet(clkg, 53, scan_frequency)
    
    %Установка частоты дискретизации в 100 МГц
    sampling_rate = 100; % МГц
    ComSet(clkg, 56, 1)
    
    %Установка чувствительности температуры лазера в 5 степень
    laser_temp_precision = 5;
    ComSet(tbox, 80, laser_temp_precision)
    
    % Параметры для проверки температуры термобокса
    target_tbox_temp = 64; % целевая температура термобокса
    tbox_temp_precision = 1; %чувствительность температуры термобокса
    tbox_temp_tolerance = 0; % допустимое отклонение температуры термобокса
    max_tbox_retries = 20; % максимальное число попыток установки температуры термобокса
    tbox_stabilization_time = 5; % время стабилизации температуры термобокса, секунды
    
    % Установка чувствительности температуры термобокса
    fprintf('Устанавливаем увствительность температуры термобокса: %.1f\n', tbox_temp_precision);
    ComSet(tbox, 90, tbox_temp_precision);
    
    % Установка температуры термобокса
    fprintf('Устанавливаем температуру термобокса: %.1f\n', target_tbox_temp);
    ComSet(tbox, 10, target_tbox_temp);
    
    % Ожидание установления температуры термобокса
    fprintf('Ожидаем установления температуры термобокса...\n');
    tbox_temp_ok = false;
    tbox_retry = 1;
    measured_tbox_temp = NaN;
    
    while tbox_retry <= max_tbox_retries && ~tbox_temp_ok
        % Ждем стабилизации температуры термобокса
        fprintf('Ждем стабилизации температуры термобокса (%d сек)...\n', tbox_stabilization_time);
        pause(tbox_stabilization_time);
        
        % Проверяем текущую температуру термобокса через команду 30
        current_tbox_temp_str = ComGet(tbox, 30);
        fprintf('Ответ от термобокса: %s\n', current_tbox_temp_str);
        
        % Парсим строку чтобы получить числовое значение температуры термобокса
        temp_parts = strsplit(current_tbox_temp_str);
        if length(temp_parts) >= 3
            measured_tbox_temp = str2double(temp_parts{3});
            fprintf('Температура термобокса: %.1f (целевая: %.1f)\n', ...
                    measured_tbox_temp, target_tbox_temp);
            
            % Проверяем соответствие температуры термобокса
            if abs(measured_tbox_temp - target_tbox_temp) <= tbox_temp_tolerance
                tbox_temp_ok = true;
                fprintf('Температура термобокса установлена корректно\n');
            else
                fprintf('Температура термобокса не соответствует: отклонение %.1f\n', ...
                        abs(measured_tbox_temp - target_tbox_temp));
                tbox_retry = tbox_retry + 1;
                
                if tbox_retry > max_tbox_retries
                    fprintf('Достигнут лимит попыток для термобокса. Продолжаем с текущей температурой.\n');
                    tbox_temp_ok = true; % все равно продолжаем
                else
                    % Увеличиваем время ожидания при повторных попытках
                    extra_wait = 2;
                    fprintf('Ждем дополнительно %d сек...\n', extra_wait);
                    pause(extra_wait);
                end
            end
        else
            fprintf('Не удалось прочитать температуру термобокса. Попытка %d/%d\n', ...
                    tbox_retry, max_tbox_retries);
            tbox_retry = tbox_retry + 1;
            
            if tbox_retry > max_tbox_retries
                fprintf('Достигнут лимит попыток для термобокса. Продолжаем эксперимент.\n');
                tbox_temp_ok = true; % все равно продолжаем
            end
        end
    end
    
    % Параметры эксперимента
    N = 100; % number of reflectograms per temperature
    L_m = 500; % fiber length in m
    T_max = 10; % максимальная температура
    T_step = 1; % шаг температуры
    temperatures = -T_max:T_step:T_max; % диапазон температур
    
    % Параметры для проверки температуры
    max_temp_retries = 10; % максимальное число попыток установки температуры
    temp_tolerance = 0; % допустимое отклонение температуры, 
    stabilization_time = 0; % время стабилизации температуры, секунды
    
    % Создание папки для данных
    CR = 'CR13'; % declare folder for experiment
    folder = datestr(now,'yyyy-mm-dd_HHMM');
    dir_dat = fullfile('test_data', CR, folder);
    if ~exist(dir_dat, 'dir'); mkdir(dir_dat); end
    
    % Предварительное выделение памяти
    all_traces = cell(length(temperatures), 1);
    measured_temps = zeros(length(temperatures), 1);
    temp_retry_counts = zeros(length(temperatures), 1);
    
    fprintf('Начинаем эксперимент с температурным сканированием...\n');
    fprintf('Диапазон температур: от %d до %d с шагом %d\n', -T_max, T_max, T_step);
    fprintf('Допуск температуры: ±%.1f\n', temp_tolerance);
    
    % Запись времени начала эксперимента
    experiment_start_time = datetime('now');
    
    % Главный цикл по температурам
    for i = 1:length(temperatures)
        target_temp = temperatures(i);
        temp_ok = false;
        temp_retry = 1;
        
        % Цикл установки и проверки температуры
        while temp_retry <= max_temp_retries && ~temp_ok
            % Установка температуры
            fprintf('Устанавливаем температуру: %d (попытка %d/%d)\n', ...
                    target_temp, temp_retry, max_temp_retries);
            ComSet(tbox, 0, target_temp);
            
            % Ждем стабилизации температуры
            fprintf('Ждем стабилизации температуры (%d сек)...\n', stabilization_time);
            pause(stabilization_time);
            
            % Проверяем текущую температуру
            current_temp_str = ComGet(tbox, 20);
            % Парсим строку "D 0 X.X" чтобы получить числовое значение
            temp_parts = strsplit(current_temp_str);
            if length(temp_parts) >= 3
                measured_temp = str2double(temp_parts{3});
                fprintf('Измеренная температура: %.1f\n', measured_temp);
                
                % Проверяем соответствие температуры
                if abs(measured_temp - target_temp) <= temp_tolerance
                    temp_ok = true;
                    measured_temps(i) = measured_temp;
                    fprintf('Температура установлена корректно\n');
                else
                    fprintf('Температура не соответствует: отклонение %.1f\n', ...
                            abs(measured_temp - target_temp));
                    temp_retry = temp_retry + 1;
                    
                    if temp_retry > max_temp_retries
                        fprintf('Достигнут лимит попыток. Используем текущую температуру.\n');
                        measured_temps(i) = measured_temp;
                        temp_ok = true; % все равно продолжаем
                    else
                        % Увеличиваем время ожидания при повторных попытках
                        extra_wait = 1;
                        fprintf('Ждем дополнительно %d сек...\n', extra_wait);
                        pause(extra_wait);
                    end
                end
            else
                fprintf('Не удалось прочитать температуру. Попытка %d/%d\n', ...
                        temp_retry, max_temp_retries);
                temp_retry = temp_retry + 1;
                
                if temp_retry > max_temp_retries
                    fprintf('Достигнут лимит попыток. Используем целевую температуру.\n');
                    measured_temps(i) = target_temp;
                    temp_ok = true; % все равно продолжаем
                end
            end
        end
        
        temp_retry_counts(i) = temp_retry;
        
        % Съёмка рефлектограмм для текущей температуры
        fprintf('Снимаем %d рефлектограмм...\n', N);
        [traces, z] = cr_get_reflectograms_ch1(N, L_m, adc);
        
        % Сохраняем данные
        all_traces{i} = traces;
        
        % Автосохранение после каждого шага
        save(fullfile(dir_dat, sprintf('temp_%d_data.mat', target_temp)), ...
             'traces', 'z', 'target_temp', 'measured_temp', 'N', 'L_m', ...
             'temp_retry', 'temp_tolerance');
        
        fprintf('Данные для температуры %d (измерено: %.1f) сохранены.\n\n', ...
                target_temp, measured_temps(i));
    end
    
    % Запись времени окончания эксперимента
    experiment_end_time = datetime('now');
    experiment_duration = experiment_end_time - experiment_start_time;
    
    % Остановка оборудования
    PCIe_9852_2CH_STOP(adc);
    
    % Создание общего массива данных для тепловой карты
    create_temperature_heatmap(all_traces, z, temperatures, measured_temps, dir_dat);
    
    % Сохранение всех данных с информацией о попытках
    save(fullfile(dir_dat, 'full_experiment_data.mat'), ...
         'all_traces', 'z', 'temperatures', 'measured_temps', ...
         'temp_retry_counts', 'temp_tolerance', 'N', 'L_m');
    
    % Создание отчёта об эксперименте
    create_experiment_report(dir_dat, experiment_name, operator_name, ...
        experiment_start_time, experiment_end_time, experiment_duration, ...
        fiber_type, fiber_length, n_eff, target_tbox_temp, tbox_temp_precision, measured_tbox_temp, ...
        tbox_temp_tolerance, tbox_retry, pulse_length, scan_frequency, ...
        sampling_rate, laser_temp_precision, N, T_max, T_step, temp_tolerance, ...
        max_temp_retries, stabilization_time, measured_temps, temp_retry_counts);
    
    fprintf('Эксперимент завершен! Данные сохранены в: %s\n', dir_dat);
end

function create_experiment_report(save_dir, experiment_name, operator_name, ...
    start_time, end_time, duration, fiber_type, fiber_length, n_eff, ...
    target_tbox_temp, tbox_temp_precision, measured_tbox_temp, tbox_temp_tolerance, tbox_retries, ...
    pulse_length, scan_freq, sampling_rate, laser_temp_precision, ...
    N, T_max, T_step, temp_tolerance, max_temp_retries, stabilization_time, ...
    measured_temps, temp_retry_counts)
    
    % Создание текстового отчёта в правильной кодировке
    report_filename = fullfile(save_dir, 'experiment_report.txt');
    
    % Используем fopen с правильной кодировкой для Windows
    fid = fopen(report_filename, 'w', 'n', 'windows-1251'); % или 'ISO-8859-1'
    
    if fid == -1
        error('Не удалось создать файл отчёта: %s', report_filename);
    end
    
    % Функция для записи строк с правильными переносами
    write_line = @(text) fprintf(fid, '%s\r\n', text);
    write_empty = @() fprintf(fid, '\r\n');
    
    write_line('ОТЧЁТ ОБ ЭКСПЕРИМЕНТЕ');
    write_line('=====================');
    write_empty();
    
    write_line('Общая информация:');
    write_line('-----------------');
    write_line(sprintf('Название эксперимента: %s', experiment_name));
    write_line(sprintf('Оператор: %s', operator_name));
    write_line(sprintf('Дата начала: %s', datestr(start_time, 'yyyy-mm-dd HH:MM:SS')));
    write_line(sprintf('Дата окончания: %s', datestr(end_time, 'yyyy-mm-dd HH:MM:SS')));
    write_line(sprintf('Продолжительность: %s', char(duration)));
    write_line(sprintf('Папка с данными: %s', save_dir));
    write_empty();
    
    write_line('Параметры волокна:');
    write_line('------------------');
    write_line(sprintf('Тип волокна: %s', fiber_type));
    write_line(sprintf('Длина волокна: %d м', fiber_length));
    write_line(sprintf('Эффективный показатель преломления: %.3f', n_eff));
    write_empty();
    
    write_line('Параметры термобокса:');
    write_line('---------------------');
    write_line(sprintf('Целевая температура термобокса: %.1f', target_tbox_temp));
    write_line(sprintf('Измеренная температура термобокса: %.1f', measured_tbox_temp));
    write_line(sprintf('Допуск температуры термобокса: ±%.1f', tbox_temp_tolerance));
    write_line(sprintf('Чувствительность температуры термобокса: %d степень', tbox_temp_precision));
    write_line(sprintf('Количество попыток установки: %d', tbox_retries));
    write_empty();
    
    write_line('Параметры оборудования:');
    write_line('----------------------');
    write_line(sprintf('Длина импульса: %d дискретов', pulse_length));
    write_line(sprintf('Частота сканирования: %d Гц', scan_freq));
    write_line(sprintf('Частота дискретизации: %d МГц', sampling_rate));
    write_line(sprintf('Точность температуры лазера: %d степень', laser_temp_precision));
    write_empty();
    
    write_line('Параметры температурного сканирования:');
    write_line('-------------------------------------');
    write_line(sprintf('Количество рефлектограмм на температуру: %d', N));
    write_line(sprintf('Диапазон температур лазера: от %d до %d', -T_max, T_max));
    write_line(sprintf('Шаг температуры лазера: %d', T_step));
    write_line(sprintf('Допуск температуры лазера: ±%.1f', temp_tolerance));
    write_line(sprintf('Максимальное количество попыток: %d', max_temp_retries));
    write_line(sprintf('Время стабилизации: %d сек', stabilization_time));
    write_empty();
    
    write_line('Результаты температурного сканирования лазера:');
    write_line('---------------------------------------------');
    write_line('Температура (цель) | Температура (измерено) | Попытки');
    write_line('-------------------|------------------------|---------');
    
    for i = 1:length(measured_temps)
        write_line(sprintf('%17d | %22.1f | %8d', ...
                -T_max + (i-1)*T_step, measured_temps(i), temp_retry_counts(i)));
    end
    
    write_empty();
    write_line('Примечания:');
    write_line('----------');
    write_line(sprintf('- Эксперимент проводился с постоянной температурой термобокса (%.1f)', target_tbox_temp));
    write_line(sprintf('- Температура лазера изменялась в диапазоне от %d до %d', -T_max, T_max));
    write_line(sprintf('- Для каждой температуры лазера снималось %d рефлектограмм', N));
    write_line('- Данные сохранялись после каждого температурного шага');
    write_line(sprintf('- Чувствительность термобокса: 1 попугай = 0.0004 * 2^(3 - %d) °C', tbox_temp_precision));
    
    fclose(fid);
    
    fprintf('Отчёт об эксперименте сохранён: %s\n', report_filename);
end

function create_temperature_heatmap(all_traces, z, target_temps, measured_temps, save_dir)
    % Создание тепловой карты
    
    % Вычисляем средние трассы для каждой температуры
    mean_traces = zeros(length(z), length(target_temps));
    for i = 1:length(target_temps)
        mean_traces(:, i) = mean(all_traces{i}, 2);
    end
    
    % Создаем фигуру
    figure('Position', [100, 100, 1200, 800]);
    
    % Тепловая карта
    subplot(2, 2, [1, 3]);
    imagesc(target_temps, z, mean_traces);
    xlabel('Температура');
    ylabel('Длина, м');
    title('Тепловая карта рефлектограмм');
    colorbar;
    axis xy;
    colormap('jet');
    
    % График зависимости от температуры в выбранной точке
    subplot(2, 2, 2);
    point_idx = round(length(z)/2); % середина волокна
    plot(target_temps, mean_traces(point_idx, :), 'o-', 'LineWidth', 2);
    xlabel('Температура');
    ylabel('Амплитуда, В');
    title(sprintf('Зависимость в точке z=%.1f м', z(point_idx)));
    grid on;
    
    % График нескольких трасс при разных температурах
    subplot(2, 2, 4);
    temp_indices = [1, round(length(target_temps)/2), length(target_temps)];
    colors = ['r', 'g', 'b'];
    hold on;
    for i = 1:length(temp_indices)
        idx = temp_indices(i);
        plot(z, mean_traces(:, idx), colors(i), 'LineWidth', 1.5, ...
            'DisplayName', sprintf('T=%d', target_temps(idx)));
    end
    hold off;
    xlabel('Длина, м');
    ylabel('Амплитуда, В');
    title('Рефлектограммы при разных температурах');
    legend;
    grid on;
    
    % Сохранение графиков
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.png'));
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.fig'));
end