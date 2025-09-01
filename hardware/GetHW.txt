function GetHW()
    ports = GetComPorts();
    for i=1:length(ports)
        disp(ports{i});
    end
    %s = serial(info.AvailableSerialPorts{1}, 'BaudRate', 9600);
    %open_data = fopen(s);
    %line = fgetl (open_data);
    %scan_line = sscanf (line, '%f,%f,%f'); %(depending on the output)
    %fclose(s)
    % it returns as too many argument open_data = fopen(s)
    
    
    %fprintf(s,'V') %%get Version
    %idn = fscanf(s);
    %fclose(s)
    %
    %
end