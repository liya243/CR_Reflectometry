addpath('adlink');
CR_NO_TRIG = true;                 % �������� ����� ��������

adc = PCIe_9852_2CH_INIT(-1);

% ������ ���� ������� ����� (����., 20000 ��������) � ���������
segmentSize = 20000;               % ������ 20�100 ���. ��� �����������
buffHeight  = 1;                   % ���� �������
buf = PCIe_9852_2CH_GIGAGET(adc, buffHeight, segmentSize, 0);  % sync_ch=0 ��� ������

PCIe_9852_2CH_STOP(adc);

ch0 = buf{1}(:,1); % ch1 = buf{2}(:,1);

% ��� �������/��������� �� ��������� Fs
clkg = GetCLOCKGEN();
rr1 = sscanf(ComGet(clkg,56),'D %*d %d');   % RR-1
Fs  = 200e6/(rr1+1);
t = (0:numel(ch0)-1)'/Fs;                   % �������

figure(10); clf; 
subplot(2,1,1); plot(t, ch0); grid on; xlabel('t, s'); ylabel('CH0, V'); title('RAW CH0');
%subplot(2,1,2); plot(t, ch1); grid on; xlabel('t, s'); ylabel('CH1, V'); title('RAW CH1');
