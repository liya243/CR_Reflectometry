addpath('serial_lib');
addpath('adlink');

tbox = GetTBOX();
disp(tbox);

%clkg = GetCLOCKGEN();
%disp(clkg);

%for i = 35000:1000:52000
    %val = ComSet(tbox, 73, i);
    data = PCIe_9852_AI_DMA_DB_IN(0, 512, 16384, true);
    
    plot(data);
    pause(1);
%end