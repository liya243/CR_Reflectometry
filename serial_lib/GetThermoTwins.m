function res=GetThermoTwins()
    ports = GetComPorts();
    for i=2:length(ports)
        %disp(ports{i});
        s = serial(ports{i}, 'BaudRate', 57600);
        fopen(s);
        fprintf(s,'V\n'); %%get Version
        ver = fgetl(s); %fgets(s); %fscanf(s);
        %tf = strcmp(ver,'')
        %tb = strfind(ver,'ClockGen');
        tb = strncmp(ver,'ThermoTwins', 6);
        if(tb)
            res = ports{i};
        end
        fclose(s);
    end
end