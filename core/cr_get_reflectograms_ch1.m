function [R, z_m, info] = cr_get_reflectograms_ch1(N, L_m, adc, opts)
% CR_GET_REFLECTOGRAMS_CH1  Capture N reflectograms of length L (meters) from CH0.

    % ��������� ������� ���������� (������ arguments)
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
    
    % ��������� ��������� ��� �������� ��������
    if ~isfield(opts, 'max_retries') || isempty(opts.max_retries)
        opts.max_retries = 100; % ������������ ����� ������� ����������
    end
    
    if ~isfield(opts, 'min_correlation') || isempty(opts.min_correlation)
        opts.min_correlation = 0.884; % ����������� ���������� ����� ��������
    end
    
    if ~isfield(opts, 'max_std_ratio') || isempty(opts.max_std_ratio)
        opts.max_std_ratio = 0.15; % ������������ ��������� std/mean
    end
    
    % ��������� ��������� ��� ��������� ��������
    if ~isfield(opts, 'z1') || isempty(opts.z1)
        opts.z1 = 50; % ��������� ���������� �� ���������
    end
    
    if ~isfield(opts, 'z2') || isempty(opts.z2)
        opts.z2 = 300; % �������� ���������� �� ���������
    end
    
    % �������� ����� ������
    if ~isscalar(N) || ~isnumeric(N)
        error('N must be a numeric scalar');
    end
    
    if ~isscalar(L_m) || ~isnumeric(L_m)
        error('L_m must be a numeric scalar');
    end

    % ��������������� ��������� ������ ��� ������� �����
    dz = 299792458 / (2 * 1.468 * 100e6); % ������ �� ������
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
    last_R = []; % ��������� ��������� ����� ������
    
    while retry_count <= opts.max_retries && ~quality_ok
        try
            % Get segmented and aligned traces
            buff = PCIe_9852_2CH_GIGAGET(adc, N, segSize, opts.sync_ch);

            % First channel:
            R = buff{1};  % [segSize ? N], in volts
            last_R = R; % ��������� ��������� �����

            % Distance axis (m)
            z_m = (0:segSize-1).' * dz;
            
            % �������� �������� ������ ������ � ��������� ���������
            quality_ok = check_reflectogram_quality(R, z_m, opts);
            
            if ~quality_ok
                retry_count = retry_count + 1;
                if retry_count <= opts.max_retries
                    fprintf('�������� ������ ������. ������� %d/%d...\n', ...
                            retry_count, opts.max_retries);
                    pause(0.5);
                else
                    warning('�� ������� �������� ������������ ������ ����� %d �������', opts.max_retries);
                    visualize_reflectograms(last_R, z_m, opts);
                end
            end

        catch ME
            PCIe_9852_2CH_STOP(adc);
            rethrow(ME);
        end
    end
    
    % ��������� ���������� � ��������
    info.retry_count = retry_count;
    info.quality_check_passed = quality_ok;
    
    if quality_ok
        % ���� �������� ������ - ���������� ������� ������
        R_mean = mean(R, 2);
        [info.correlation_score, info.std_ratio] = calculate_quality_metrics(R, z_m, opts);
        info.raw_traces_count = N;
    else
        % ���� �������� �� ������ - ��� ����� ���������� ������� �� ��������� �������
        R_mean = mean(last_R, 2);
        [info.correlation_score, info.std_ratio] = calculate_quality_metrics(last_R, z_m, opts);
        info.raw_traces_count = N;
        info.quality_warning = '�������� �� ������������� ���������';
    end
end

% --------- ������������ ������������� ---------
function visualize_reflectograms(R, z_m, opts)
    figure('Name', '��������� ����� �������������', ...
           'NumberTitle', 'off', ...
           'Position', [100, 100, 1000, 600]);
    
    % ������� ����������
    subplot(2,1,1);
    
    % ������ ��� ������
    plot(z_m, R, 'LineWidth', 1);
    xlabel('����������, �');
    ylabel('���������, �');
    title(sprintf('��� %d ������������� (��������� �������)', size(R, 2)));
    grid on;
    
    % ��������� ����������� ��������� �������� ��������
    hold on;
    y_limits = ylim;
    fill([opts.z1, opts.z2, opts.z2, opts.z1], ...
         [y_limits(1), y_limits(1), y_limits(2), y_limits(2)], ...
         [0.9, 0.9, 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    text(mean([opts.z1, opts.z2]), mean(y_limits), ...
         '�������� �������� ��������', ...
         'HorizontalAlignment', 'center', 'BackgroundColor', 'white');
    hold off;
    
    % ������� ������ � ����������� ����������
    subplot(2,1,2);
    mean_trace = mean(R, 2);
    std_trace = std(R, 0, 2);
    
    plot(z_m, mean_trace, 'b', 'LineWidth', 2);
    hold on;
    fill([z_m; flipud(z_m)], ...
         [mean_trace - std_trace; flipud(mean_trace + std_trace)], ...
         [0.8, 0.8, 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    xlabel('����������, �');
    ylabel('���������, �');
    title('������� ������ � ����������� ����������');
    legend('�������', '�1?', 'Location', 'best');
    grid on;
    
    % ��������� ��������� � ��������� ��������
    [correlation_score, std_ratio] = calculate_quality_metrics(R, z_m, opts);
    annotation('textbox', [0.15, 0.01, 0.7, 0.05], ...
               'String', sprintf('����������: %.3f (min=%.3f), STD/mean: %.3f (max=%.3f)', ...
                                 correlation_score, opts.min_correlation, ...
                                 std_ratio, opts.max_std_ratio), ...
               'FitBoxToText', 'on', ...
               'BackgroundColor', 'white', ...
               'EdgeColor', 'red');
    
    drawnow; % �������������� ���������� �������
end

% --------- �������� �������� ������������� (� ������ ���������) ---------
function is_ok = check_reflectogram_quality(R, z_m, opts)
    % ��������� ������� �������� ������ � ��������� ���������
    [correlation_score, std_ratio] = calculate_quality_metrics(R, z_m, opts);
    
    % ��������� �������� ��������
    is_ok = (correlation_score >= opts.min_correlation) && ...
            (std_ratio <= opts.max_std_ratio);
    
    if ~is_ok
        fprintf('�������� ������: correlation=%.3f (min=%.3f), std_ratio=%.3f (max=%.3f)\n', ...
                correlation_score, opts.min_correlation, std_ratio, opts.max_std_ratio);
    end
end

% --------- ���������� ������ �������� (� ������ ���������) ---------
function [correlation_score, std_ratio] = calculate_quality_metrics(R, z_m, opts)
    % ���������� ������� ��� ���������� ��������� z1-z2
    idx_range = z_m >= opts.z1 & z_m <= opts.z2;
    
    % ���� � ��������� ��� �����, ���������� ���� ��������
    if ~any(idx_range)
        warning('�������� z1=%.2f - z2=%.2f �� �������� ������. ������������ ���� ��������.', opts.z1, opts.z2);
        idx_range = true(size(z_m));
    end
    
    % �������� ������ ������ �� ������� ���������
    R_range = R(idx_range, :);
    
    % 1. �������� ���������� ����� ��������
    if size(R_range, 2) > 1
        % ��������� �������� ����������
        corr_matrix = corr(R_range);
        % ����� ������� ���������� (�������� ���������)
        correlation_score = mean(corr_matrix(~eye(size(corr_matrix))));
    else
        correlation_score = 1; % ���� ������ ���� ������
    end
    
    % 2. �������� ��������� ������������ ���������� � ��������
    mean_trace = mean(R_range, 2);
    std_dev = std(R_range, 0, 2);
    
    % �������� ������� �� ����
    non_zero_mean = abs(mean_trace);
    non_zero_mean(non_zero_mean == 0) = 1; % �������� ���� �� 1
    std_ratio = mean(std_dev ./ non_zero_mean);
end

% --------- local helper ---------
function local_addpath_if_needed(p)
    if ~isempty(p) && exist(p, 'dir') && all(cellfun(@(x) ~strcmpi(x,p), strsplit(path,pathsep)))
        addpath(p);
    end
end