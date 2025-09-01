function res = ComSet(port, register, value)
    s = serial(port, 'BaudRate', 57600, 'Timeout', 1);
    fopen(s);
    % отправл€ем с CRLF Ч многим MCU так надЄжнее
    fprintf(s, 'S %i %i\r\n', [register, value]);
    % читаем одну строку ответа
    resp = strtrim(fgetl(s));
    fclose(s);

    % успех если начинаетс€ с 'OK' или с 'Y'
    res = strncmpi(resp,'OK',2) || strncmpi(resp,'Y',1);
end