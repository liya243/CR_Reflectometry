function main_CR_temperature_sweep()
    % Инициализация оборудования
    addpath('core');
    addpath('hardware');
    addpath('adlink');
    adc = PCIe_9852_2CH_INIT(-1);
    tbox = GetTBOX();
    clkg = GetCLOCKGEN();
    
    % Параметры эксперимента
    N = 100; % number of reflectograms per temperature
    L_m = 500; % fiber length in m
    T_max = 2000; % максимальная температура
    T_step = 1; % шаг температуры
    temperatures = -T_max:T_step:T_max; % диапазон температур
    
    % Опции для съемки с проверкой качества
    opts = struct();
    opts.max_retries = 10;
    opts.min_correlation = 0.884;
    opts.max_std_ratio = 0.1;
    opts.z1 = 0; % диапазон проверки качества
    opts.z2 = 300;
    
    % Создание папки для данных
    CR = 'CR13'; % declare folder for experiment
    folder = datestr(now,'yyyy-mm-dd_HHMM');
    dir_dat = fullfile('test_data', CR, folder);
    if ~exist(dir_dat, 'dir'); mkdir(dir_dat); end
    
    % Предварительное выделение памяти для СРЕДНИХ трасс
    mean_traces = zeros(ceil(L_m / (299792458 / (2 * 1.468 * 100e6))), length(temperatures));
    measured_temps = zeros(length(temperatures), 1);
    quality_info = cell(length(temperatures), 1);
    
    fprintf('Начинаем эксперимент с температурным сканированием...\n');
    fprintf('Диапазон температур: от %d до %d с шагом %d\n', -T_max, T_max, T_step);
    fprintf('Сохраняем только средние трассы (экономия памяти)\n');
    
    % Главный цикл по температурам
    for i = 1:length(temperatures)
        target_temp = temperatures(i);
        
        % Установка температуры
        fprintf('Устанавливаем температуру: %d\n', target_temp);
        ComSet(tbox, 0, target_temp);
        
        % Ждем стабилизации температуры
        pause(2);
        
        % Проверяем текущую температуру
        current_temp_str = ComGet(tbox, 20);
        temp_parts = strsplit(current_temp_str);
        if length(temp_parts) >= 3
            measured_temp = str2double(temp_parts{3});
            measured_temps(i) = measured_temp;
            fprintf('Измеренная температура: %.1f\n', measured_temp);
        else
            measured_temps(i) = target_temp;
            fprintf('Не удалось прочитать температуру, используем целевую: %d\n', target_temp);
        end
        
        % Съёмка рефлектограмм и получение СРЕДНЕЙ трассы
        fprintf('Снимаем %d рефлектограмм и усредняем...\n', N);
        [mean_trace, z, info] = cr_get_reflectograms_ch1(N, L_m, adc, opts);
        
        % Сохраняем среднюю трассу и информацию о качестве
        mean_traces(:, i) = mean_trace;
        quality_info{i} = info;
        
        % Автосохранение после каждого шага (только средняя трасса)
        save(fullfile(dir_dat, sprintf('temp_%d_data.mat', target_temp)), ...
             'mean_trace', 'z', 'target_temp', 'measured_temp', 'info', 'N', 'L_m');
        
        % Вывод информации о качестве
        if info.quality_check_passed
            fprintf('? Качество отличное (корреляция: %.3f, std/mean: %.3f)\n\n', ...
                    info.correlation_score, info.std_ratio);
        else
            fprintf('? Качество ниже требуемого (корреляция: %.3f, std/mean: %.3f)\n\n', ...
                    info.correlation_score, info.std_ratio);
        end
    end
    
    % Остановка оборудования
    PCIe_9852_2CH_STOP(adc);
    
    % Создание тепловой карты
    create_temperature_heatmap(mean_traces, z, temperatures, measured_temps, dir_dat);
    
    % Сохранение всех данных (только средние трассы)
    save(fullfile(dir_dat, 'full_experiment_data.mat'), ...
         'mean_traces', 'z', 'temperatures', 'measured_temps', 'quality_info', 'N', 'L_m', 'opts');
    
    % Сохранение сводки по качеству данных
    save_quality_summary(quality_info, temperatures, measured_temps, dir_dat);
    
    fprintf('Эксперимент завершен! Данные сохранены в: %s\n', dir_dat);
    fprintf('Объем данных сокращен в ~%d раз (сохранены только средние трассы)\n', N);
end

function save_quality_summary(quality_info, target_temps, measured_temps, save_dir)
    % Создание сводки по качеству данных
    correlation_scores = zeros(length(quality_info), 1);
    std_ratios = zeros(length(quality_info), 1);
    retry_counts = zeros(length(quality_info), 1);
    quality_passed = false(length(quality_info), 1);
    
    for i = 1:length(quality_info)
        correlation_scores(i) = quality_info{i}.correlation_score;
        std_ratios(i) = quality_info{i}.std_ratio;
        retry_counts(i) = quality_info{i}.retry_count;
        quality_passed(i) = quality_info{i}.quality_check_passed;
    end
    
    % График качества данных
    figure('Position', [100, 100, 1000, 800]);
    
    subplot(3,1,1);
    plot(measured_temps, correlation_scores, 'o-', 'LineWidth', 1);
    hold on;
    yline(0.884, 'r--', 'Min correlation');
    xlabel('Температура');
    ylabel('Корреляция');
    title('Качество данных: корреляция между трассами');
    grid on;
    
    subplot(3,1,2);
    plot(measured_temps, std_ratios, 'o-', 'LineWidth', 1);
    hold on;
    yline(0.1, 'r--', 'Max std/mean');
    xlabel('Температура');
    ylabel('std/mean');
    title('Качество данных: отношение std/mean');
    grid on;
    
    subplot(3,1,3);
    stem(measured_temps, retry_counts, 'filled');
    xlabel('Температура');
    ylabel('Число пересъемок');
    title('Число попыток для достижения качества');
    grid on;
    
    saveas(gcf, fullfile(save_dir, 'data_quality_summary.png'));
    saveas(gcf, fullfile(save_dir, 'data_quality_summary.fig'));
    
    % Сохранение сводной таблицы
    quality_table = table(target_temps', measured_temps, correlation_scores, std_ratios, ...
                         retry_counts, quality_passed, ...
                         'VariableNames', {'TargetTemp', 'MeasuredTemp', 'Correlation', ...
                         'StdRatio', 'RetryCount', 'QualityPassed'});
    writetable(quality_table, fullfile(save_dir, 'quality_summary.csv'));
end

function create_temperature_heatmap(mean_traces, z, target_temps, measured_temps, save_dir)
    % Создание тепловой карты из средних трасс
    
    % Создаем фигуру
    figure('Position', [100, 100, 1200, 800]);
    
    % Тепловая карта
    subplot(2, 2, [1, 3]);
    imagesc(target_temps, z, mean_traces);
    xlabel('Температура, °C');
    ylabel('Длина, м');
    title('Тепловая карта средних рефлектограмм');
    colorbar;
    axis xy;
    colormap('jet');
    
    % График зависимости от температуры в выбранной точке
    subplot(2, 2, 2);
    point_idx = round(length(z)/2); % середина волокна
    plot(target_temps, mean_traces(point_idx, :), 'o-', 'LineWidth', 2, 'MarkerSize', 4);
    xlabel('Температура, °C');
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
            'DisplayName', sprintf('T=%d°C', target_temps(idx)));
    end
    hold off;
    xlabel('Длина, м');
    ylabel('Амплитуда, В');
    title('Средние рефлектограммы при разных температурах');
    legend('Location', 'best');
    grid on;
    
    % Сохранение графиков
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.png'));
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.fig'));
end