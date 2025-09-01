function res=GetComPorts()
    info = instrhwinfo('serial');
    if isempty(info.AvailableSerialPorts)
       error('No ports free!');
    end
    res=info.AvailableSerialPorts;
    %s = serial(info.AvailableSerialPorts{1}, 'BaudRate', 9600);
    %open_data = fopen(s);
    %line = fgetl (open_data);
    %scan_line = sscanf (line, '%f,%f,%f'); %(depending on the output)
    %fclose(s)
    % it returns as too many argument open_data = fopen(s)
end

GetComPorts();