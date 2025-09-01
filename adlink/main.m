addpath('serial_lib');
addpath('adlink');

%GetComPorts()
%GetHW()

tbox = GetTBOX();
disp(tbox);

clkg = GetCLOCKGEN();
disp(clkg);

%for i = 1:30
for i = 12000:200:15000
    %val = ComGet(tbox, 61);
    %disp([int2str(i), ' ', val]);
    val = ComSet(tbox, 73, i);
    data = PCIe_9852_AI_DMA(0);
    plot(data);
    pause(1);
end