function fix_CR_experiment_Fs(experiment_dir, Fs_actual, n_eff, regenerate_heatmap)
% FIX_CR_EXPERIMENT_FS  Пересчитать ось z под заданную фактическую Fs.
%
%   fix_CR_experiment_Fs(experiment_dir, Fs_actual)
%   fix_CR_experiment_Fs(experiment_dir, Fs_actual, n_eff)
%   fix_CR_experiment_Fs(experiment_dir, Fs_actual, n_eff, regenerate_heatmap)
%
% Параметры:
%   experiment_dir      Папка конкретного эксперимента (где лежат temp_*_data.mat)
%   Fs_actual           ФАКТИЧЕСКАЯ частота дискретизации (например, 100e6)
%   n_eff               Эффективный показатель преломления (по умолчанию 1.468)
%   regenerate_heatmap  true/false — пересоздать сводную картинку (по умолчанию true)
%
% Что делает:
%   1) Для каждого temp_*_data.mat:
%      - оценивает Fs_used, с которой построен текущий z, по dz и n_eff;
%      - масштабирует z: z := z * (Fs_used / Fs_actual);
%      - сохраняет в тот же файл (создаёт .bak рядом на всякий случай);
%      - добавляет в файл поля meta.Fs_used, meta.Fs_actual, meta.scale.
%   2) Аналогично правит full_experiment_data.mat (если есть).
%   3) По желанию пересобирает тепловую карту из исходных трасс.
%
% Автор: твоя добрая ИИ-помощница :)

    if nargin < 3 || isempty(n_eff), n_eff = 1.468; end
    if nargin < 4 || isempty(regenerate_heatmap), regenerate_heatmap = true; end

    c0 = 299792458; % м/с

    assert(isfolder(experiment_dir), 'Папка не найдена: %s', experiment_dir);
    fprintf('=== FIX Fs in: %s ===\n', experiment_dir);
    fprintf('Target Fs_actual = %.6g Hz, n_eff = %.4f\n', Fs_actual, n_eff);

    % --- Чиним все temp_*_data.mat ---
    files = dir(fullfile(experiment_dir, 'temp_*_data.mat'));
    if isempty(files)
        warning('Не найдено файлов temp_*_data.mat в %s', experiment_dir);
    end

    for k = 1:numel(files)
        fpath = fullfile(files(k).folder, files(k).name);
        S = load(fpath);

        % Осевое имя может быть z или z_m
        zvar = '';
        if isfield(S, 'z'),   z = S.z;   zvar = 'z';
        elseif isfield(S, 'z_m'), z = S.z_m; zvar = 'z_m';
        else
            warning('Пропускаю %s: не найдено поле z/z_m', files(k).name);
            continue;
        end

        % Оценим Fs_used по текущему z
        dz = median(diff(z(:)));
        if dz <= 0 || ~isfinite(dz)
            warning('Странный dz в %s, пропуск.', files(k).name);
            continue;
        end
        Fs_used = c0 / (2*n_eff*dz);
        scale  = Fs_used / Fs_actual;

        % Масштабируем ось
        z_new = z * scale;

        % Бэкап
        copyfile(fpath, [fpath, '.bak']);

        % Сохраняем обратно, дописывая метаинфу
        meta.Fs_used   = Fs_used;
        meta.Fs_actual = Fs_actual;
        meta.n_eff     = n_eff;
        meta.scale     = scale;
        meta.note      = 'z пересчитан как z*scale, где scale = Fs_used/Fs_actual';

        if isfield(S, 'traces')
            traces = S.traces; %#ok<NASGU>
        end
        if isfield(S, 'target_temp')
            target_temp = S.target_temp; %#ok<NASGU>
        end
        if isfield(S, 'measured_temp')
            measured_temp = S.measured_temp; %#ok<NASGU>
        end
        if isfield(S, 'N'), N = S.N; %#ok<NASGU>
        end
        if isfield(S, 'L_m'), L_m = S.L_m; %#ok<NASGU>
        end

        % Возвращаем в исходное имя переменной
        switch zvar
            case 'z',   z = z_new; %#ok<NASGU>
            case 'z_m', z_m = z_new; %#ok<NASGU>
        end

        save(fpath, '-struct', 'S', '-v7'); % сперва перезапишем исходные поля
        % а затем поверх докинем обновлённые оси/мету (чтобы точно сохранились)
        switch zvar
            case 'z',   save(fpath, 'z',   '-append');
            case 'z_m', save(fpath, 'z_m', '-append');
        end
        save(fpath, 'meta', '-append');

        fprintf('✔ %s: dz=%.4g m  Fs_used≈%.3f MHz  scale=%.6f (z обновлён)\n', ...
                files(k).name, dz, Fs_used/1e6, scale);
    end

    % --- Чиним full_experiment_data.mat (если есть) ---
    full_path = fullfile(experiment_dir, 'full_experiment_data.mat');
    if isfile(full_path)
        Sf = load(full_path);
        if isfield(Sf, 'z') || isfield(Sf, 'z_m')
            if isfield(Sf, 'z'),   z = Sf.z;   zvar = 'z';
            else,                  z = Sf.z_m; zvar = 'z_m';
            end
            dz = median(diff(z(:)));
            Fs_used = c0 / (2*n_eff*dz);
            scale  = Fs_used / Fs_actual;
            z_new  = z * scale;

            copyfile(full_path, [full_path, '.bak']);
            meta_full.Fs_used = Fs_used;
            meta_full.Fs_actual = Fs_actual;
            meta_full.n_eff = n_eff;
            meta_full.scale = scale;
            meta_full.note  = 'z пересчитан как z*scale, где scale = Fs_used/Fs_actual';

            % Перезаписываем
            if isfield(Sf, 'all_traces')
                all_traces = Sf.all_traces; %#ok<NASGU>
            end
            if isfield(Sf, 'temperatures')
                temperatures = Sf.temperatures; %#ok<NASGU>
            end
            if isfield(Sf, 'measured_temps')
                measured_temps = Sf.measured_temps; %#ok<NASGU>
            end
            if isfield(Sf, 'N'),  N = Sf.N; %#ok<NASGU>
            end
            if isfield(Sf, 'L_m'), L_m = Sf.L_m; %#ok<NASGU>
            end

            switch zvar
                case 'z',   z = z_new; %#ok<NASGU>
                case 'z_m', z_m = z_new; %#ok<NASGU>
            end

            save(full_path, '-struct', 'Sf', '-v7');
            switch zvar
                case 'z',   save(full_path, 'z',   '-append');
                case 'z_m', save(full_path, 'z_m', '-append');
            end
            save(full_path, 'meta_full', '-append');

            fprintf('✔ full_experiment_data.mat: Fs_used≈%.3f MHz, scale=%.6f (z обновлён)\n', ...
                    Fs_used/1e6, scale);
        else
            warning('full_experiment_data.mat: не найдено поле z/z_m — пропуск правки оси.');
        end
    else
        fprintf('full_experiment_data.mat не найден — пропускаю.\n');
    end

    % --- Пересобрать тепловую карту (по желанию) ---
    if regenerate_heatmap
        try
            Sf = load(fullfile(experiment_dir, 'full_experiment_data.mat'));
            if ~isfield(Sf, 'all_traces')
                warning('Нет all_traces в full_experiment_data.mat — не могу пересобрать теплокарту.');
            else
                if isfield(Sf, 'z'),   z = Sf.z;
                elseif isfield(Sf, 'z_m'), z = Sf.z_m;
                else, error('Нет z/z_m в full_experiment_data.mat после правки.');
                end
                all_traces = Sf.all_traces;
                temperatures = Sf.temperatures;
                % Построим средние трассы
                mean_traces = zeros(numel(z), numel(temperatures));
                for i = 1:numel(temperatures)
                    mean_traces(:, i) = mean(all_traces{i}, 2);
                end

                figure('Position', [100, 100, 1200, 800]);
                subplot(2,2,[1,3]);
                imagesc(temperatures, z, mean_traces);
                xlabel('Температура'); ylabel('Длина, м');
                title('Тепловая карта рефлектограмм (Fs исправлена)');
                colorbar; axis xy; colormap('jet');

                subplot(2,2,2);
                point_idx = round(numel(z)/2);
                plot(temperatures, mean_traces(point_idx,:), 'o-', 'LineWidth', 2);
                xlabel('Температура');
                ylabel('Амплитуда, В');
                title(sprintf('Зависимость в точке z=%.2f м', z(point_idx)));
                grid on;

                subplot(2,2,4);
                idx = [1, round(numel(temperatures)/2), numel(temperatures)];
                hold on;
                plot(z, mean_traces(:, idx(1)), 'LineWidth', 1.5, 'DisplayName', sprintf('T=%g', temperatures(idx(1))));
                plot(z, mean_traces(:, idx(2)), 'LineWidth', 1.5, 'DisplayName', sprintf('T=%g', temperatures(idx(2))));
                plot(z, mean_traces(:, idx(3)), 'LineWidth', 1.5, 'DisplayName', sprintf('T=%g', temperatures(idx(3))));
                hold off; legend; grid on;
                xlabel('Длина, м'); ylabel('Амплитуда, В');
                title('Рефлектограммы при разных температурах (Fs исправлена)');

                saveas(gcf, fullfile(experiment_dir, 'temperature_heatmap_corrected.png'));
                saveas(gcf, fullfile(experiment_dir, 'temperature_heatmap_corrected.fig'));
                fprintf('✔ Пересобрана тепловая карта: temperature_heatmap_corrected.*\n');
            end
        catch ME
            warning('Не удалось пересобрать теплокарту: %s', ME.message);
        end
    end

    fprintf('=== Готово. ===\n');
end
