function res=ComSet(port, register, value)
        s = serial(port, 'BaudRate', 57600);
        fopen(s);
        fprintf(s,'S %i %i\n', [register, value]);
        responce = fgetl(s); %fgets(s); %fscanf(s); %get answer
        %tf = strcmp(ver,'')
        %tb = contains(responce,'OK');
        tb = strncmp(responce,'OK', 2);
        if(tb)
            res = true;
        else
            res = false;
        end
        fclose(s);
end