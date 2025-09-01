function Compare_results()
    % Выбор папок с экспериментами
    exp1_dir = uigetdir('', 'Vyberite papku pervogo eksperimenta');
    exp2_dir = uigetdir('', 'Vyberite papku vtorogo eksperimenta');
    if isequal(exp1_dir,0) || isequal(exp2_dir,0), return; end

    % Zagruska i privedenie formata
    [data1, temps1] = load_experiment_data_means(exp1_dir); % Nz1 x Ntemps1
    [data2, temps2] = load_experiment_data_means(exp2_dir); % Nz2 x Ntemps2

    % Predprosmotr srednih reflektogramm
    figure;
    plot(data1.z, mean(data1.traces_mean,2,'omitnan'), 'b', 'LineWidth', 2); hold on;
    plot(data2.z, mean(data2.traces_mean,2,'omitnan'), 'r', 'LineWidth', 2);
    xlabel('Dlina, m'); ylabel('Amplituda, V');
    title('Srednie po temperature reflektogrammy (dlya vibora diapazona)');
    legend('Eksperiment 1','Eksperiment 2'); grid on;

    % Interaktivnyy vibor diapazona
    fprintf('Kliknite dve tochki na grafike dlya vibora diapazona z1-z2.\n');
    [z_range, ~] = ginput(2);
    z1 = min(z_range); z2 = max(z_range);
    fprintf('Vibran diapazon: z1=%.3f m, z2=%.3f m\n', z1, z2);

    % Otrezaem po diapazonu i privodim ko obschemu z-grid (po setke exp1)
    idx1 = find(data1.z >= z1 & data1.z <= z2);
    z_common = data1.z(idx1);
    T1_full = data1.traces_mean(idx1, :);

    idx2 = find(data2.z >= z1 & data2.z <= z2);
    z2_slice = data2.z(idx2);
    T2_slice = data2.traces_mean(idx2, :);
    [z2_slice, uniq_idx] = unique(z2_slice, 'stable');
    T2_slice = T2_slice(uniq_idx, :);
    if numel(z2_slice) < 2
        error('Slishkom malo tochek exp2 v viborannom diapazone z dlya interpolyatsii.');
    end
    T2_full = interp1(z2_slice, T2_slice, z_common, 'linear', 'extrap');

    % Saniruem temperatury i stolbtsy
    [T1, temps1] = sanitize_columns(T1_full, temps1);
    [T2, temps2] = sanitize_columns(T2_full, temps2);

    if size(T1,1) ~= size(T2,1)
        error('Nesovpadenie dlini z posle interpolyatsii.');
    end
    if isempty(T1) || isempty(T2)
        error('Posle ochistki ne ostalos validnyh temperatur.');
    end

    % Matritsa korrelyatsii
    C = compute_correlation_matrix(T1, T2);

    % Osi dlya vizualizatsii [-200,200]
    temps1_plot = normalize_temp_axis(temps1, -200, 200, size(C,1));
    temps2_plot = normalize_temp_axis(temps2, -200, 200, size(C,2));

    % Vizualizatsiya
    plot_correlation_heatmap(C, temps1_plot, temps2_plot, z1, z2, exp1_dir, exp2_dir);

    % Maksimum
    [mx, ij] = max(C(:)); [i,j] = ind2sub(size(C), ij);
    fprintf('\n=== Maksimalnaya korrelyatsiya ===\n');
    fprintf('Corr = %.4f mezhdu T1=%g i T2=%g\n', mx, safe_at(temps1,i), safe_at(temps2,j));
end

% ---- Vspomogatelnye funktsii ----

function [exp_data, temperatures] = load_experiment_data_means(exp_dir)
    mat_files = dir(fullfile(exp_dir, '*.mat'));
    mat_files = mat_files(~endsWith({mat_files.name}, '.bak') & ~startsWith({mat_files.name}, '.'));

    found_full = false; S = struct();
    for k = 1:numel(mat_files)
        if contains(mat_files(k).name, 'full_experiment_data')
            S = load(fullfile(exp_dir, mat_files(k).name));
            found_full = true; break;
        end
    end

    if found_full
        Mmean = cell_to_means(S.all_traces);
        exp_data.traces_mean = Mmean;
        exp_data.z = get_z(S);
        temperatures = get_temperatures(Mmean, S);
        [exp_data.traces_mean, temperatures] = drop_bad_columns(exp_data.traces_mean, temperatures);
        return;
    end

    all_cells = {}; temps = []; z_save = [];
    for k = 1:numel(mat_files)
        name = mat_files(k).name;
        if contains(name, 'temp_') && contains(name, '_data')
            D = load(fullfile(exp_dir, name));
            if isfield(D,'traces') && ~isempty(D.traces)
                all_cells{end+1} = D.traces;
                if isempty(z_save), z_save = get_z(D); end
                temp_val = pick_temp(D, name);
                temps(end+1) = temp_val; %#ok<AGROW>
            end
        end
    end
    if isempty(all_cells), error('Ne naydeny dannye v papke.'); end

    Mmean = cell_to_means(all_cells);
    exp_data.traces_mean = Mmean;
    exp_data.z = z_save;
    temperatures = temps(:).';
    [exp_data.traces_mean, temperatures] = drop_bad_columns(exp_data.traces_mean, temperatures);
end

function z = get_z(S)
    if isfield(S,'z'), z = S.z;
    elseif isfield(S,'z_m'), z = S.z_m;
    else, error('Ne naydena os z/z_m.');
    end
    z = z(:);
end

function T = get_temperatures(Mmean, S)
    if isfield(S,'measured_temps') && numel(S.measured_temps)==size(Mmean,2)
        T = S.measured_temps(:).';
    elseif isfield(S,'temperatures') && numel(S.temperatures)==size(Mmean,2)
        T = S.temperatures(:).';
    else
        if isfield(S,'measured_temps'), T = S.measured_temps(:).';
        elseif isfield(S,'temperatures'), T = S.temperatures(:).';
        else, T = nan(1,size(Mmean,2));
        end
        if numel(T) ~= size(Mmean,2), T = nan(1,size(Mmean,2)); end
    end
end

function val = pick_temp(D, filename)
    if isfield(D,'measured_temp') && isfinite(D.measured_temp)
        val = D.measured_temp; return;
    end
    if isfield(D,'target_temp') && isfinite(D.target_temp)
        val = D.target_temp; return;
    end
    expr = 'temp_([-+]?\d+(\.\d+)?)_data';
    tok = regexp(filename, expr, 'tokens', 'once');
    if ~isempty(tok), val = str2double(tok{1});
    else, val = NaN;
    end
end

function [Mmean, temperatures] = drop_bad_columns(Mmean, temperatures)
    good = isfinite(temperatures);
    temperatures = temperatures(good);
    Mmean = Mmean(:, good);
    keep = false(1, size(Mmean,2));
    for k = 1:size(Mmean,2)
        col = Mmean(:,k);
        if all(isnan(col)), keep(k)=false; continue; end
        s = nanstd(col);
        keep(k) = isfinite(s) && s > 0;
    end
    Mmean = Mmean(:, keep);
    temperatures = temperatures(keep);
end

function Mmean = cell_to_means(C)
    Nz = size(C{1},1);
    Ntemps = numel(C);
    Mmean = nan(Nz, Ntemps);
    for k = 1:Ntemps
        X = C{k};
        if isempty(X)
            Mmean(:,k) = NaN;
        else
            Mmean(:,k) = mean(X, 2, 'omitnan');
        end
    end
end

function [T_sanitized, temps_sanitized] = sanitize_columns(T, temps)
    [T, temps] = drop_bad_columns(T, temps);
    [temps_sanitized, order] = sort(temps);
    T_sanitized = T(:, order);
end

function C = compute_correlation_matrix(T1, T2)
    n1 = size(T1,2); n2 = size(T2,2);
    C = zeros(n1, n2);
    for i = 1:n1
        x = T1(:,i);
        xm = nanmean(x); xs = nanstd(x);
        x = x - xm;
        if ~(isfinite(xs) && xs>0), xs = NaN; end
        for j = 1:n2
            y = T2(:,j);
            ym = nanmean(y); ys = nanstd(y);
            y = y - ym;
            if ~(isfinite(ys) && ys>0), ys = NaN; end
            m = isfinite(x) & isfinite(y);
            if sum(m) < 3 || ~isfinite(xs) || ~isfinite(ys)
                C(i,j) = 0;
            else
                xx = x(m); yy = y(m);
                sx = std(xx, 0); sy = std(yy, 0);
                if sx==0 || sy==0
                    C(i,j) = 0;
                else
                    C(i,j) = (xx'*yy) / ((numel(xx)-1)*sx*sy);
                end
            end
        end
    end
    C(~isfinite(C)) = 0;
    C = max(-1, min(1, C));
end

function t_plot = normalize_temp_axis(t_raw, assumed_min, assumed_max, ncols)
    t = t_raw(:).'; good = isfinite(t); t = t(good);
    ok = ~isempty(t) && issorted(t) && (max(t)-min(t) <= 1e3) && numel(t)==ncols;
    if ok, t_plot = t;
    else, t_plot = linspace(assumed_min, assumed_max, ncols);
    end
end

function plot_correlation_heatmap(C, temps1, temps2, z1, z2, exp1_dir, exp2_dir)
    fig = figure('Name','Korrelyatsiya srednih reflektogramm',...
                 'Units','pixels','Position',[120 80 860 860]);
    imagesc(temps1, temps2, C.'); axis xy; axis image;
    colormap('jet'); caxis([0 1]);
    cb = colorbar; cb.Label.String = 'corr';
    xlabel('Eksperiment 1: temperatura (spec. ed.)');
    ylabel('Eksperiment 2: temperatura (spec. ed.)');
    title(sprintf('Korrelyatsiya srednih (z: %.3f–%.3f m)', z1, z2));
    [~, n1] = fileparts(exp1_dir); [~, n2] = fileparts(exp2_dir);
    out_png = sprintf('corr_means_%s_vs_%s.png', n1, n2);
    out_mat = sprintf('corr_means_%s_vs_%s.mat', n1, n2);
    saveas(fig, out_png);
    save(out_mat, 'C','temps1','temps2','z1','z2');
end

function v = safe_at(vec, idx)
    if idx>=1 && idx<=numel(vec) && isfinite(vec(idx)), v = vec(idx);
    else, v = NaN; end
end
