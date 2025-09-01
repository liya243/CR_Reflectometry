addpath('serial_lib');
addpath('adlink');
if ~exist('tbox', 'var')
    tbox = GetTBOX();
end
fprintf('Thermobox port: %s\n', tbox);

if ~exist('clkg', 'var')
    clkg = GetCLOCKGEN();
end
fprintf('ClockGen port: %s\n', clkg);

if exist('adc', 'var')
    clear adc;
end
adc = PCIe_9852_2CH_INIT(-1);

%for i = 35000:1000:52000
    %val = ComSet(tbox, 73, i);

ComSet(clkg,56, 1); %100MHz

if ~length(adc)==0
    for i = 1:1:128
        %n1=datetime();
        data = PCIe_9852_2CH_GIGAGET(adc, 256, 27000, 0);
        %n2=datetime();
        %disp(n2-n1);
        
        figure(1);
        plot(data{1});
        figure(2);
        plot(data{2});
        pause(1);
    end
    
    PCIe_9852_2CH_STOP(adc);
end
clear adc;