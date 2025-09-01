function res=ComGet(port, register)
        s = serial(port, 'BaudRate', 57600);
        fopen(s);
        fprintf(s,'G %i\n', register);
        responce = fgetl(s); %fgets(s); %fscanf(s); %get answer
        %tf = strcmp(ver,'')
        %tb = contains(ver,'OK');
        %if(tb==true)
        %    res = true;
        %else
        %    res = false;
        %end
        res = responce;
        fclose(s);
end