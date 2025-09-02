% === Очистка экспериментальных данных через выбор папки ===

exp_dir = uigetdir('', 'Выберите папку с экспериментом');
if isequal(exp_dir, 0)
    disp('Операция отменена пользователем.');
    return;
end

input_file = fullfile(exp_dir, 'full_experiment_data.mat');
output_file = fullfile(exp_dir, 'full_experiment_data_clean.mat');

if ~exist(input_file, 'file')
    error('Файл %s не найден!', input_file);
end

load(input_file);

% --- Проверяем, что есть нужные переменные ---
if ~exist('all_traces', 'var') || ~exist('measured_temps', 'var')
    error('Нет переменных all_traces или measured_temps в файле!');
end

% --- Ищем хорошие температуры (не NaN, не пустые, адекватные трассы) ---
good = isfinite(measured_temps);

for k = 1:numel(all_traces)
    if isempty(all_traces{k})
        good(k) = false;
    elseif all(all(isnan(all_traces{k})))
        good(k) = false;
    elseif std(mean(all_traces{k},2),'omitnan') == 0
        good(k) = false;
    end
end

n_good = sum(good);
n_total = numel(measured_temps);
n_bad = n_total - n_good;

if n_bad == 0
    fprintf('Данные уже чистые: %d/%d хороших температур, ничего не сохранено.\n', n_good, n_total);
else
    fprintf('Оставлено %d/%d температур, удалено %d.\n', n_good, n_total, n_bad);

    % --- Оставляем только хорошие данные ---
    measured_temps = measured_temps(good);
    all_traces = all_traces(good);

    % --- Если есть target_temps, тоже фильтруем ---
    if exist('target_temps', 'var')
        target_temps = target_temps(good);
    end

    % --- z не меняется ---
    % --- Сохраняем в новый файл ---
    if exist('target_temps', 'var')
        save(output_file, 'all_traces', 'z', 'measured_temps', 'target_temps', '-v7.3');
    else
        save(output_file, 'all_traces', 'z', 'measured_temps', '-v7.3');
    end

    fprintf('Сохранено в файл %s\n', output_file);
end
