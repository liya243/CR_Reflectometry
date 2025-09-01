function main_CR_temperature_sweep()
    % ������������� ������������
    addpath('core');
    addpath('hardware');
    addpath('adlink');
    adc = PCIe_9852_2CH_INIT(-1);
    tbox = GetTBOX();
    clkg = GetCLOCKGEN();
    
    % ��������� ������������ (����� ������� � ��������� ������ ����)
    experiment_name = '������������� ������������ ������';
    fiber_type = 'SMF-28'; % ��� �������
    fiber_length = 500; % ����� ������� � ������
    n_eff = 1.468; % ����������� ���������� �����������
    operator_name = '�����'; % ��� ���������
    
    %��������� ����� �������� � 10 ���������
    pulse_length = 10;
    ComSet(clkg, 50, pulse_length)
    
    %��������� ������� ������������ � 2000 ��
    scan_frequency = 2000;
    ComSet(clkg, 53, scan_frequency)
    
    %��������� ������� ������������� � 100 ���
    sampling_rate = 100; % ���
    ComSet(clkg, 56, 1)
    
    %��������� ���������������� ����������� ������ � 5 �������
    laser_temp_precision = 5;
    ComSet(tbox, 80, laser_temp_precision)
    
    % ��������� ��� �������� ����������� ����������
    target_tbox_temp = 64; % ������� ����������� ����������
    tbox_temp_precision = 1; %���������������� ����������� ����������
    tbox_temp_tolerance = 0; % ���������� ���������� ����������� ����������
    max_tbox_retries = 20; % ������������ ����� ������� ��������� ����������� ����������
    tbox_stabilization_time = 5; % ����� ������������ ����������� ����������, �������
    
    % ��������� ���������������� ����������� ����������
    fprintf('������������� ��������������� ����������� ����������: %.1f\n', tbox_temp_precision);
    ComSet(tbox, 90, tbox_temp_precision);
    
    % ��������� ����������� ����������
    fprintf('������������� ����������� ����������: %.1f\n', target_tbox_temp);
    ComSet(tbox, 10, target_tbox_temp);
    
    % �������� ������������ ����������� ����������
    fprintf('������� ������������ ����������� ����������...\n');
    tbox_temp_ok = false;
    tbox_retry = 1;
    measured_tbox_temp = NaN;
    
    while tbox_retry <= max_tbox_retries && ~tbox_temp_ok
        % ���� ������������ ����������� ����������
        fprintf('���� ������������ ����������� ���������� (%d ���)...\n', tbox_stabilization_time);
        pause(tbox_stabilization_time);
        
        % ��������� ������� ����������� ���������� ����� ������� 30
        current_tbox_temp_str = ComGet(tbox, 30);
        fprintf('����� �� ����������: %s\n', current_tbox_temp_str);
        
        % ������ ������ ����� �������� �������� �������� ����������� ����������
        temp_parts = strsplit(current_tbox_temp_str);
        if length(temp_parts) >= 3
            measured_tbox_temp = str2double(temp_parts{3});
            fprintf('����������� ����������: %.1f (�������: %.1f)\n', ...
                    measured_tbox_temp, target_tbox_temp);
            
            % ��������� ������������ ����������� ����������
            if abs(measured_tbox_temp - target_tbox_temp) <= tbox_temp_tolerance
                tbox_temp_ok = true;
                fprintf('����������� ���������� ����������� ���������\n');
            else
                fprintf('����������� ���������� �� �������������: ���������� %.1f\n', ...
                        abs(measured_tbox_temp - target_tbox_temp));
                tbox_retry = tbox_retry + 1;
                
                if tbox_retry > max_tbox_retries
                    fprintf('��������� ����� ������� ��� ����������. ���������� � ������� ������������.\n');
                    tbox_temp_ok = true; % ��� ����� ����������
                else
                    % ����������� ����� �������� ��� ��������� ��������
                    extra_wait = 2;
                    fprintf('���� ������������� %d ���...\n', extra_wait);
                    pause(extra_wait);
                end
            end
        else
            fprintf('�� ������� ��������� ����������� ����������. ������� %d/%d\n', ...
                    tbox_retry, max_tbox_retries);
            tbox_retry = tbox_retry + 1;
            
            if tbox_retry > max_tbox_retries
                fprintf('��������� ����� ������� ��� ����������. ���������� �����������.\n');
                tbox_temp_ok = true; % ��� ����� ����������
            end
        end
    end
    
    % ��������� ������������
    N = 100; % number of reflectograms per temperature
    L_m = 500; % fiber length in m
    T_max = 10; % ������������ �����������
    T_step = 1; % ��� �����������
    temperatures = -T_max:T_step:T_max; % �������� ����������
    
    % ��������� ��� �������� �����������
    max_temp_retries = 10; % ������������ ����� ������� ��������� �����������
    temp_tolerance = 0; % ���������� ���������� �����������, 
    stabilization_time = 0; % ����� ������������ �����������, �������
    
    % �������� ����� ��� ������
    CR = 'CR13'; % declare folder for experiment
    folder = datestr(now,'yyyy-mm-dd_HHMM');
    dir_dat = fullfile('test_data', CR, folder);
    if ~exist(dir_dat, 'dir'); mkdir(dir_dat); end
    
    % ��������������� ��������� ������
    all_traces = cell(length(temperatures), 1);
    measured_temps = zeros(length(temperatures), 1);
    temp_retry_counts = zeros(length(temperatures), 1);
    
    fprintf('�������� ����������� � ������������� �������������...\n');
    fprintf('�������� ����������: �� %d �� %d � ����� %d\n', -T_max, T_max, T_step);
    fprintf('������ �����������: �%.1f\n', temp_tolerance);
    
    % ������ ������� ������ ������������
    experiment_start_time = datetime('now');
    
    % ������� ���� �� ������������
    for i = 1:length(temperatures)
        target_temp = temperatures(i);
        temp_ok = false;
        temp_retry = 1;
        
        % ���� ��������� � �������� �����������
        while temp_retry <= max_temp_retries && ~temp_ok
            % ��������� �����������
            fprintf('������������� �����������: %d (������� %d/%d)\n', ...
                    target_temp, temp_retry, max_temp_retries);
            ComSet(tbox, 0, target_temp);
            
            % ���� ������������ �����������
            fprintf('���� ������������ ����������� (%d ���)...\n', stabilization_time);
            pause(stabilization_time);
            
            % ��������� ������� �����������
            current_temp_str = ComGet(tbox, 20);
            % ������ ������ "D 0 X.X" ����� �������� �������� ��������
            temp_parts = strsplit(current_temp_str);
            if length(temp_parts) >= 3
                measured_temp = str2double(temp_parts{3});
                fprintf('���������� �����������: %.1f\n', measured_temp);
                
                % ��������� ������������ �����������
                if abs(measured_temp - target_temp) <= temp_tolerance
                    temp_ok = true;
                    measured_temps(i) = measured_temp;
                    fprintf('����������� ����������� ���������\n');
                else
                    fprintf('����������� �� �������������: ���������� %.1f\n', ...
                            abs(measured_temp - target_temp));
                    temp_retry = temp_retry + 1;
                    
                    if temp_retry > max_temp_retries
                        fprintf('��������� ����� �������. ���������� ������� �����������.\n');
                        measured_temps(i) = measured_temp;
                        temp_ok = true; % ��� ����� ����������
                    else
                        % ����������� ����� �������� ��� ��������� ��������
                        extra_wait = 1;
                        fprintf('���� ������������� %d ���...\n', extra_wait);
                        pause(extra_wait);
                    end
                end
            else
                fprintf('�� ������� ��������� �����������. ������� %d/%d\n', ...
                        temp_retry, max_temp_retries);
                temp_retry = temp_retry + 1;
                
                if temp_retry > max_temp_retries
                    fprintf('��������� ����� �������. ���������� ������� �����������.\n');
                    measured_temps(i) = target_temp;
                    temp_ok = true; % ��� ����� ����������
                end
            end
        end
        
        temp_retry_counts(i) = temp_retry;
        
        % ������ ������������� ��� ������� �����������
        fprintf('������� %d �������������...\n', N);
        [traces, z] = cr_get_reflectograms_ch1(N, L_m, adc);
        
        % ��������� ������
        all_traces{i} = traces;
        
        % �������������� ����� ������� ����
        save(fullfile(dir_dat, sprintf('temp_%d_data.mat', target_temp)), ...
             'traces', 'z', 'target_temp', 'measured_temp', 'N', 'L_m', ...
             'temp_retry', 'temp_tolerance');
        
        fprintf('������ ��� ����������� %d (��������: %.1f) ���������.\n\n', ...
                target_temp, measured_temps(i));
    end
    
    % ������ ������� ��������� ������������
    experiment_end_time = datetime('now');
    experiment_duration = experiment_end_time - experiment_start_time;
    
    % ��������� ������������
    PCIe_9852_2CH_STOP(adc);
    
    % �������� ������ ������� ������ ��� �������� �����
    create_temperature_heatmap(all_traces, z, temperatures, measured_temps, dir_dat);
    
    % ���������� ���� ������ � ����������� � ��������
    save(fullfile(dir_dat, 'full_experiment_data.mat'), ...
         'all_traces', 'z', 'temperatures', 'measured_temps', ...
         'temp_retry_counts', 'temp_tolerance', 'N', 'L_m');
    
    % �������� ������ �� ������������
    create_experiment_report(dir_dat, experiment_name, operator_name, ...
        experiment_start_time, experiment_end_time, experiment_duration, ...
        fiber_type, fiber_length, n_eff, target_tbox_temp, tbox_temp_precision, measured_tbox_temp, ...
        tbox_temp_tolerance, tbox_retry, pulse_length, scan_frequency, ...
        sampling_rate, laser_temp_precision, N, T_max, T_step, temp_tolerance, ...
        max_temp_retries, stabilization_time, measured_temps, temp_retry_counts);
    
    fprintf('����������� ��������! ������ ��������� �: %s\n', dir_dat);
end

function create_experiment_report(save_dir, experiment_name, operator_name, ...
    start_time, end_time, duration, fiber_type, fiber_length, n_eff, ...
    target_tbox_temp, tbox_temp_precision, measured_tbox_temp, tbox_temp_tolerance, tbox_retries, ...
    pulse_length, scan_freq, sampling_rate, laser_temp_precision, ...
    N, T_max, T_step, temp_tolerance, max_temp_retries, stabilization_time, ...
    measured_temps, temp_retry_counts)
    
    % �������� ���������� ������ � ���������� ���������
    report_filename = fullfile(save_dir, 'experiment_report.txt');
    
    % ���������� fopen � ���������� ���������� ��� Windows
    fid = fopen(report_filename, 'w', 'n', 'windows-1251'); % ��� 'ISO-8859-1'
    
    if fid == -1
        error('�� ������� ������� ���� ������: %s', report_filename);
    end
    
    % ������� ��� ������ ����� � ����������� ����������
    write_line = @(text) fprintf(fid, '%s\r\n', text);
    write_empty = @() fprintf(fid, '\r\n');
    
    write_line('��ר� �� ������������');
    write_line('=====================');
    write_empty();
    
    write_line('����� ����������:');
    write_line('-----------------');
    write_line(sprintf('�������� ������������: %s', experiment_name));
    write_line(sprintf('��������: %s', operator_name));
    write_line(sprintf('���� ������: %s', datestr(start_time, 'yyyy-mm-dd HH:MM:SS')));
    write_line(sprintf('���� ���������: %s', datestr(end_time, 'yyyy-mm-dd HH:MM:SS')));
    write_line(sprintf('�����������������: %s', char(duration)));
    write_line(sprintf('����� � �������: %s', save_dir));
    write_empty();
    
    write_line('��������� �������:');
    write_line('------------------');
    write_line(sprintf('��� �������: %s', fiber_type));
    write_line(sprintf('����� �������: %d �', fiber_length));
    write_line(sprintf('����������� ���������� �����������: %.3f', n_eff));
    write_empty();
    
    write_line('��������� ����������:');
    write_line('---------------------');
    write_line(sprintf('������� ����������� ����������: %.1f', target_tbox_temp));
    write_line(sprintf('���������� ����������� ����������: %.1f', measured_tbox_temp));
    write_line(sprintf('������ ����������� ����������: �%.1f', tbox_temp_tolerance));
    write_line(sprintf('���������������� ����������� ����������: %d �������', tbox_temp_precision));
    write_line(sprintf('���������� ������� ���������: %d', tbox_retries));
    write_empty();
    
    write_line('��������� ������������:');
    write_line('----------------------');
    write_line(sprintf('����� ��������: %d ���������', pulse_length));
    write_line(sprintf('������� ������������: %d ��', scan_freq));
    write_line(sprintf('������� �������������: %d ���', sampling_rate));
    write_line(sprintf('�������� ����������� ������: %d �������', laser_temp_precision));
    write_empty();
    
    write_line('��������� �������������� ������������:');
    write_line('-------------------------------------');
    write_line(sprintf('���������� ������������� �� �����������: %d', N));
    write_line(sprintf('�������� ���������� ������: �� %d �� %d', -T_max, T_max));
    write_line(sprintf('��� ����������� ������: %d', T_step));
    write_line(sprintf('������ ����������� ������: �%.1f', temp_tolerance));
    write_line(sprintf('������������ ���������� �������: %d', max_temp_retries));
    write_line(sprintf('����� ������������: %d ���', stabilization_time));
    write_empty();
    
    write_line('���������� �������������� ������������ ������:');
    write_line('---------------------------------------------');
    write_line('����������� (����) | ����������� (��������) | �������');
    write_line('-------------------|------------------------|---------');
    
    for i = 1:length(measured_temps)
        write_line(sprintf('%17d | %22.1f | %8d', ...
                -T_max + (i-1)*T_step, measured_temps(i), temp_retry_counts(i)));
    end
    
    write_empty();
    write_line('����������:');
    write_line('----------');
    write_line(sprintf('- ����������� ���������� � ���������� ������������ ���������� (%.1f)', target_tbox_temp));
    write_line(sprintf('- ����������� ������ ���������� � ��������� �� %d �� %d', -T_max, T_max));
    write_line(sprintf('- ��� ������ ����������� ������ ��������� %d �������������', N));
    write_line('- ������ ����������� ����� ������� �������������� ����');
    write_line(sprintf('- ���������������� ����������: 1 ������� = 0.0004 * 2^(3 - %d) �C', tbox_temp_precision));
    
    fclose(fid);
    
    fprintf('����� �� ������������ �������: %s\n', report_filename);
end

function create_temperature_heatmap(all_traces, z, target_temps, measured_temps, save_dir)
    % �������� �������� �����
    
    % ��������� ������� ������ ��� ������ �����������
    mean_traces = zeros(length(z), length(target_temps));
    for i = 1:length(target_temps)
        mean_traces(:, i) = mean(all_traces{i}, 2);
    end
    
    % ������� ������
    figure('Position', [100, 100, 1200, 800]);
    
    % �������� �����
    subplot(2, 2, [1, 3]);
    imagesc(target_temps, z, mean_traces);
    xlabel('�����������');
    ylabel('�����, �');
    title('�������� ����� �������������');
    colorbar;
    axis xy;
    colormap('jet');
    
    % ������ ����������� �� ����������� � ��������� �����
    subplot(2, 2, 2);
    point_idx = round(length(z)/2); % �������� �������
    plot(target_temps, mean_traces(point_idx, :), 'o-', 'LineWidth', 2);
    xlabel('�����������');
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
            'DisplayName', sprintf('T=%d', target_temps(idx)));
    end
    hold off;
    xlabel('�����, �');
    ylabel('���������, �');
    title('�������������� ��� ������ ������������');
    legend;
    grid on;
    
    % ���������� ��������
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.png'));
    saveas(gcf, fullfile(save_dir, 'temperature_heatmap.fig'));
end