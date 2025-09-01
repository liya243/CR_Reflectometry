function main_CR_temperature_sweep()
    % ������������� ������������
    addpath('core');
    addpath('hardware');
    addpath('adlink');
    adc = PCIe_9852_2CH_INIT(-1);
    tbox = GetTBOX();
    clkg = GetCLOCKGEN();
    
    % ��������� ������������
    N = 100; % number of reflectograms per temperature
    L_m = 500; % fiber length in m
    T_max = 2000; % ������������ �����������
    T_step = 1; % ��� �����������
    temperatures = -T_max:T_step:T_max; % �������� ����������
    
    % ����� ��� ������ � ��������� ��������
    opts = struct();
    opts.max_retries = 10;
    opts.min_correlation = 0.884;
    opts.max_std_ratio = 0.1;
    opts.z1 = 0; % �������� �������� ��������
    opts.z2 = 300;
    
    % �������� ����� ��� ������
    CR = 'CR13'; % declare folder for experiment
    folder = datestr(now,'yyyy-mm-dd_HHMM');
    dir_dat = fullfile('test_data', CR, folder);
    if ~exist(dir_dat, 'dir'); mkdir(dir_dat); end
    
    % ��������������� ��������� ������ ��� ������� �����
    mean_traces = zeros(ceil(L_m / (299792458 / (2 * 1.468 * 100e6))), length(temperatures));
    measured_temps = zeros(length(temperatures), 1);
    quality_info = cell(length(temperatures), 1);
    
    fprintf('�������� ����������� � ������������� �������������...\n');
    fprintf('�������� ����������: �� %d �� %d � ����� %d\n', -T_max, T_max, T_step);
    fprintf('��������� ������ ������� ������ (�������� ������)\n');
    
    % ������� ���� �� ������������
    for i = 1:length(temperatures)
        target_temp = temperatures(i);
        
        % ��������� �����������
        fprintf('������������� �����������: %d\n', target_temp);
        ComSet(tbox, 0, target_temp);
        
        % ���� ������������ �����������
        pause(2);
        
        % ��������� ������� �����������
        current_temp_str = ComGet(tbox, 20);
        temp_parts = strsplit(current_temp_str);
        if length(temp_parts) >= 3
            measured_temp = str2double(temp_parts{3});
            measured_temps(i) = measured_temp;
            fprintf('���������� �����������: %.1f\n', measured_temp);
        else
            measured_temps(i) = target_temp;
            fprintf('�� ������� ��������� �����������, ���������� �������: %d\n', target_temp);
        end
        
        % ������ ������������� � ��������� ������� ������
        fprintf('������� %d ������������� � ���������...\n', N);
        [mean_trace, z, info] = cr_get_reflectograms_ch1(N, L_m, adc, opts);
        
        % ��������� ������� ������ � ���������� � ��������
        mean_traces(:, i) = mean_trace;
        quality_info{i} = info;
        
        % �������������� ����� ������� ���� (������ ������� ������)
        save(fullfile(dir_dat, sprintf('temp_%d_data.mat', target_temp)), ...
             'mean_trace', 'z', 'target_temp', 'measured_temp', 'info', 'N', 'L_m');
        
        % ����� ���������� � ��������
        if info.quality_check_passed
            fprintf('? �������� �������� (����������: %.3f, std/mean: %.3f)\n\n', ...
                    info.correlation_score, info.std_ratio);
        else
            fprintf('? �������� ���� ���������� (����������: %.3f, std/mean: %.3f)\n\n', ...
                    info.correlation_score, info.std_ratio);
        end
    end
    
    % ��������� ������������
    PCIe_9852_2CH_STOP(adc);
    
    % �������� �������� �����
    create_temperature_heatmap(mean_traces, z, temperatures, measured_temps, dir_dat);
    
    % ���������� ���� ������ (������ ������� ������)
    save(fullfile(dir_dat, 'full_experiment_data.mat'), ...
         'mean_traces', 'z', 'temperatures', 'measured_temps', 'quality_info', 'N', 'L_m', 'opts');
    
    % ���������� ������ �� �������� ������
    save_quality_summary(quality_info, temperatures, measured_temps, dir_dat);
    
    fprintf('����������� ��������! ������ ��������� �: %s\n', dir_dat);
    fprintf('����� ������ �������� � ~%d ��� (��������� ������ ������� ������)\n', N);
end

function save_quality_summary(quality_info, target_temps, measured_temps, save_dir)
    % �������� ������ �� �������� ������
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
    
    % ������ �������� ������
    figure('Position', [100, 100, 1000, 800]);
    
    subplot(3,1,1);
    plot(measured_temps, correlation_scores, 'o-', 'LineWidth', 1);
    hold on;
    yline(0.884, 'r--', 'Min correlation');
    xlabel('�����������');
    ylabel('����������');
    title('�������� ������: ���������� ����� ��������');
    grid on;
    
    subplot(3,1,2);
    plot(measured_temps, std_ratios, 'o-', 'LineWidth', 1);
    hold on;
    yline(0.1, 'r--', 'Max std/mean');
    xlabel('�����������');
    ylabel('std/mean');
    title('�������� ������: ��������� std/mean');
    grid on;
    
    subplot(3,1,3);
    stem(measured_temps, retry_counts, 'filled');
    xlabel('�����������');
    ylabel('����� ����������');
    title('����� ������� ��� ���������� ��������');
    grid on;
    
    saveas(gcf, fullfile(save_dir, 'data_quality_summary.png'));
    saveas(gcf, fullfile(save_dir, 'data_quality_summary.fig'));
    
    % ���������� ������� �������
    quality_table = table(target_temps', measured_temps, correlation_scores, std_ratios, ...
                         retry_counts, quality_passed, ...
                         'VariableNames', {'TargetTemp', 'MeasuredTemp', 'Correlation', ...
                         'StdRatio', 'RetryCount', 'QualityPassed'});
    writetable(quality_table, fullfile(save_dir, 'quality_summary.csv'));
end

function create_temperature_heatmap(mean_traces, z, target_temps, measured_temps, save_dir)
    % �������� �������� ����� �� ������� �����
    
    % ������� ������
    figure('Position', [100, 100, 1200, 800]);
    
    % �������� �����
    subplot(2, 2, [1, 3]);
    imagesc(target_temps, z, mean_traces);
    xlabel('�����������, �C');
    ylabel('�����, �');
    title('�������� ����� ������� �������������');
    colorbar;
    axis xy;
    colormap('jet');
    
    % ������ ����������� �� ����������� � ��������� �����
    subplot(2, 2, 2);
    point_idx = round(length(z)/2); % �������� �������
    plot(target_temps, mean_traces(point_idx, :), 'o-', 'LineWidth', 2, 'MarkerSize', 4);
    xlabel('�����������, �C');
    ylabel('���������, �');
    title(sprintf('����������� � ����� z=%.1f �', z(point_idx)));
    grid on;
    
    % ������ ���������� ����� ��� ������ ������������
    subplot(2, 2, 4);
    temp_indices = [1, round(length(target_temps)/2), length(target_temps)];
    colors = ['r', 'g', 'b'];
    hold on;
    for i = 1:length(temp_indices)
        idx = temp_indices(i);
        plot(z, mean_traces(:, idx), colors(i), 'LineWidth', 1.5, ...
            'DisplayName', sprintf('T=%d�C', target_temps(idx)));
    end
    hold off;
    xlabel('�����, �');
    ylabel('���������, �');
    title('������� �������������� ��� ������ ������������');
    legend('Location', 'best');
    grid on;
    
    % ���������� ��������
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.png'));
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.fig'));
end