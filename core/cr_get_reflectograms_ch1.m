function [R, z_m, info] = cr_get_reflectograms_ch1(N, L_m, adc, opts)
% CR_GET_REFLECTOGRAMS_CH1  Capture N reflectograms of length L (meters) from CH0.

    % Обработка входных параметров (вместо arguments)
    if nargin < 4
        opts = struct();
    end
    
    if ~isfield(opts, 'Fs') || isempty(opts.Fs)
        opts.Fs = 100e6;
    end
    
    if ~isfield(opts, 'n_eff') || isempty(opts.n_eff)
        opts.n_eff = 1.468;
    end
    
    if ~isfield(opts, 'sync_ch') || isempty(opts.sync_ch)
        opts.sync_ch = 0;
    end
    
    % Добавляем параметры для проверки качества
    if ~isfield(opts, 'max_retries') || isempty(opts.max_retries)
        opts.max_retries = 100; % максимальное число попыток пересъёмки
    end
    
    if ~isfield(opts, 'min_correlation') || isempty(opts.min_correlation)
        opts.min_correlation = 0.884; % минимальная корреляция между трассами
    end
    
    if ~isfield(opts, 'max_std_ratio') || isempty(opts.max_std_ratio)
        opts.max_std_ratio = 0.15; % максимальное отношение std/mean
    end
    
    % Добавляем параметры для диапазона проверки
    if ~isfield(opts, 'z1') || isempty(opts.z1)
        opts.z1 = 50; % начальная координата по умолчанию
    end
    
    if ~isfield(opts, 'z2') || isempty(opts.z2)
        opts.z2 = 300; % конечная координата по умолчанию
    end
    
    % Проверка типов данных
    if ~isscalar(N) || ~isnumeric(N)
        error('N must be a numeric scalar');
    end
    
    if ~isscalar(L_m) || ~isnumeric(L_m)
        error('L_m must be a numeric scalar');
    end

    % Предварительное выделение памяти для СРЕДНИХ трасс
    dz = 299792458 / (2 * 1.468 * 100e6); % метров на отсчет
    segSize = max(16, ceil(L_m / dz));
    mean_traces = zeros(segSize, length(temperatures));
    info = struct('Fs', opts.Fs, 'n_eff', opts.n_eff, ...
                  'dz_m', dz, 'segSize', segSize, ...
                  'requested_L_m', L_m, 'sync_ch', opts.sync_ch);

    % --- prepare paths to adlink ---
    local_addpath_if_needed('adlink');

    % --- capture with quality check and retry ---
    retry_count = 0;
    quality_ok = false;
    last_R = []; % сохраняем последний пакет данных
    
    while retry_count <= opts.max_retries && ~quality_ok
        try
            % Get segmented and aligned traces
            buff = PCIe_9852_2CH_GIGAGET(adc, N, segSize, opts.sync_ch);

            % First channel:
            R = buff{1};  % [segSize ? N], in volts
            last_R = R; % сохраняем последний пакет

            % Distance axis (m)
            z_m = (0:segSize-1).' * dz;
            
            % Проверка качества данных только в указанном диапазоне
            quality_ok = check_reflectogram_quality(R, z_m, opts);
            
            if ~quality_ok
                retry_count = retry_count + 1;
                if retry_count <= opts.max_retries
                    fprintf('Качество данных низкое. Попытка %d/%d...\n', ...
                            retry_count, opts.max_retries);
                    pause(0.5);
                else
                    warning('Не удалось получить качественные данные после %d попыток', opts.max_retries);
                    visualize_reflectograms(last_R, z_m, opts);
                end
            end

        catch ME
            PCIe_9852_2CH_STOP(adc);
            rethrow(ME);
        end
    end
    
    % Добавляем информацию о качестве
    info.retry_count = retry_count;
    info.quality_check_passed = quality_ok;
    
    if quality_ok
        % Если качество прошло - возвращаем среднюю трассу
        R_mean = mean(R, 2);
        [info.correlation_score, info.std_ratio] = calculate_quality_metrics(R, z_m, opts);
        info.raw_traces_count = N;
    else
        % Если качество не прошло - все равно возвращаем среднюю из последней попытки
        R_mean = mean(last_R, 2);
        [info.correlation_score, info.std_ratio] = calculate_quality_metrics(last_R, z_m, opts);
        info.raw_traces_count = N;
        info.quality_warning = 'Качество не соответствует критериям';
    end
end

% --------- Визуализация рефлектограмм ---------
function visualize_reflectograms(R, z_m, opts)
    figure('Name', 'Последний пакет рефлектограмм', ...
           'NumberTitle', 'off', ...
           'Position', [100, 100, 1000, 600]);
    
    % Создаем подграфики
    subplot(2,1,1);
    
    % Рисуем все трассы
    plot(z_m, R, 'LineWidth', 1);
    xlabel('Расстояние, м');
    ylabel('Амплитуда, В');
    title(sprintf('Все %d рефлектограмм (последняя попытка)', size(R, 2)));
    grid on;
    
    % Добавляем обозначение диапазона проверки качества
    hold on;
    y_limits = ylim;
    fill([opts.z1, opts.z2, opts.z2, opts.z1], ...
         [y_limits(1), y_limits(1), y_limits(2), y_limits(2)], ...
         [0.9, 0.9, 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    text(mean([opts.z1, opts.z2]), mean(y_limits), ...
         'Диапазон проверки качества', ...
         'HorizontalAlignment', 'center', 'BackgroundColor', 'white');
    hold off;
    
    % Средняя трасса и стандартное отклонение
    subplot(2,1,2);
    mean_trace = mean(R, 2);
    std_trace = std(R, 0, 2);
    
    plot(z_m, mean_trace, 'b', 'LineWidth', 2);
    hold on;
    fill([z_m; flipud(z_m)], ...
         [mean_trace - std_trace; flipud(mean_trace + std_trace)], ...
         [0.8, 0.8, 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    xlabel('Расстояние, м');
    ylabel('Амплитуда, В');
    title('Средняя трасса ± стандартное отклонение');
    legend('Среднее', '±1?', 'Location', 'best');
    grid on;
    
    % Добавляем аннотацию с метриками качества
    [correlation_score, std_ratio] = calculate_quality_metrics(R, z_m, opts);
    annotation('textbox', [0.15, 0.01, 0.7, 0.05], ...
               'String', sprintf('Корреляция: %.3f (min=%.3f), STD/mean: %.3f (max=%.3f)', ...
                                 correlation_score, opts.min_correlation, ...
                                 std_ratio, opts.max_std_ratio), ...
               'FitBoxToText', 'on', ...
               'BackgroundColor', 'white', ...
               'EdgeColor', 'red');
    
    drawnow; % Принудительное обновление графика
end

% --------- Проверка качества рефлектограмм (с учетом диапазона) ---------
function is_ok = check_reflectogram_quality(R, z_m, opts)
    % Вычисляем метрики качества только в указанном диапазоне
    [correlation_score, std_ratio] = calculate_quality_metrics(R, z_m, opts);
    
    % Проверяем критерии качества
    is_ok = (correlation_score >= opts.min_correlation) && ...
            (std_ratio <= opts.max_std_ratio);
    
    if ~is_ok
        fprintf('Качество данных: correlation=%.3f (min=%.3f), std_ratio=%.3f (max=%.3f)\n', ...
                correlation_score, opts.min_correlation, std_ratio, opts.max_std_ratio);
    end
end

% --------- Вычисление метрик качества (с учетом диапазона) ---------
function [correlation_score, std_ratio] = calculate_quality_metrics(R, z_m, opts)
    % Определяем индексы для выбранного диапазона z1-z2
    idx_range = z_m >= opts.z1 & z_m <= opts.z2;
    
    % Если в диапазоне нет точек, используем весь диапазон
    if ~any(idx_range)
        warning('Диапазон z1=%.2f - z2=%.2f не содержит данных. Используется весь диапазон.', opts.z1, opts.z2);
        idx_range = true(size(z_m));
    end
    
    % Выбираем только данные из нужного диапазона
    R_range = R(idx_range, :);
    
    % 1. Проверка корреляции между трассами
    if size(R_range, 2) > 1
        % Вычисляем попарные корреляции
        corr_matrix = corr(R_range);
        % Берем среднюю корреляцию (исключая диагональ)
        correlation_score = mean(corr_matrix(~eye(size(corr_matrix))));
    else
        correlation_score = 1; % если только одна трасса
    end
    
    % 2. Проверка отношения стандартного отклонения к среднему
    mean_trace = mean(R_range, 2);
    std_dev = std(R_range, 0, 2);
    
    % Избегаем деления на ноль
    non_zero_mean = abs(mean_trace);
    non_zero_mean(non_zero_mean == 0) = 1; % заменяем нули на 1
    std_ratio = mean(std_dev ./ non_zero_mean);
end

% --------- local helper ---------
function local_addpath_if_needed(p)
    if ~isempty(p) && exist(p, 'dir') && all(cellfun(@(x) ~strcmpi(x,p), strsplit(path,pathsep)))
        addpath(p);
    end
end