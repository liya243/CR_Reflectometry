% === Скрипт для анализа сдвига температурных соответствий между экспериментами ===

folder = uigetdir('', 'Выбери папку с fig-файлами корреляций');
if isequal(folder, 0), disp('Отмена.'); return; end

files = dir(fullfile(folder, 'Tbox_*-*.fig'));
if isempty(files)
    error('В папке нет файлов Tbox_*-*.fig');
end

delta_tbox = [];
mean_shift = [];
all_shifts = {};

for k = 1:numel(files)
    fname = files(k).name;
    % Разбираем разность температур термобокса из названия файла
    expr = 'Tbox_(\-?\d+)\-(\-?\d+)\.fig';
    tokens = regexp(fname, expr, 'tokens', 'once');
    if isempty(tokens)
        warning('Файл %s пропущен (не совпал паттерн)', fname);
        continue;
    end
    tbox1 = str2double(tokens{1});
    tbox2 = str2double(tokens{2});
    dT = tbox2 - tbox1;
    delta_tbox(end+1) = dT;

    % Открываем fig и ищем нужные переменные
    fig = openfig(fullfile(folder, fname), 'invisible');
    ax = findobj(fig, 'Type', 'axes');
    im = findobj(ax, 'Type', 'image');
    if isempty(im)
        warning('Не найден image в файле %s', fname); close(fig); continue; 
    end
    % Получаем C (матрицу корреляций) и оси
    C = im.CData;
    temps1 = ax.XTick;  % предположим, что ось температур как есть (или...)
    temps2 = ax.YTick;
    % Но лучше попробуем вытащить реальные значения из image:
    % (если temps1, temps2 не подходят, пробуем так)
    if isprop(im, 'XData') && isprop(im, 'YData')
        xdata = get(im, 'XData');
        ydata = get(im, 'YData');
        temps1 = linspace(xdata(1), xdata(end), size(C,2));
        temps2 = linspace(ydata(1), ydata(end), size(C,1));
    end

    % Для каждого значения по оси 2 (обычно строка) ищем максимум по оси 1 (столбцу)
    max_idx = zeros(1, size(C,1));
    max_T1 = zeros(1, size(C,1));
    for i = 1:size(C,1)
        [~, jmax] = max(C(i,:));   % максимум по столбцам
        max_idx(i) = jmax;
        max_T1(i) = temps1(jmax);
    end
    shift = max_T1 - temps2(:)';  % сдвиг соответствия температур
    all_shifts{k} = shift;

    % Сохраняем средний сдвиг (или медиану)
    mean_shift(end+1) = mean(shift, 'omitnan');
    close(fig);
end

% Строим график
figure('Name', 'Сдвиг соответствия температур vs разность Tbox');
scatter(delta_tbox, mean_shift, 80, 'o', 'MarkerFaceColor', 'w', 'LineWidth',2); % только точки
hold on;

% Линейный тренд
p = polyfit(delta_tbox, mean_shift, 1);
x_fit = linspace(min(delta_tbox), max(delta_tbox), 100);
y_fit = polyval(p, x_fit);
plot(x_fit, y_fit, 'r-', 'LineWidth', 2);

% Формула тренда (в виде "y = a*x + b")
text_x = min(x_fit) + 0.05*range(x_fit);
text_y = max(y_fit) - 0.05*range(y_fit);
trend_str = sprintf('\\DeltaT_{laser} = %.3g \\cdot \\DeltaT_{box} %+g', p(1), p(2));
text(text_x, text_y, trend_str, 'FontSize', 14, 'Color', 'r', 'BackgroundColor', 'w');

xlabel('\Delta T_{box} = T_{box,2} - T_{box,1} (попугаи)');
ylabel('Средний сдвиг температур соответствия (\DeltaT_{laser}, попугаи)');
grid on;
title('Средний сдвиг температур лазера vs разность температур термобокса');

hold off;
