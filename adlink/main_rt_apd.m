addpath('serial_lib');
addpath('adlink');

%tbox = GetTBOX();
%disp(tbox);
%fprintf('Thermobox port: %s\n',tbox);

%clkg = GetCLOCKGEN();
%disp(clkg);
%fprintf('Clockgen port: %s\n',clkg);

from = 51000;
step = 500;
to = 53000;

volt = zeros(1,(to-from)/step, 'double');
stds = zeros(1,(to-from)/step, 'double');
mins = zeros(1,(to-from)/step, 'double');
maxs = zeros(1,(to-from)/step, 'double');
means = zeros(1,(to-from)/step, 'double');
k=1;

data = PCIe_9852_AI_DMA_DB_IN(0, 512, 8192, true); %reflectogram buffer

for i = from:step:to
   % val = ComSet(tbox, 73, i);
    %pause(1);
    disp(i);
    data = PCIe_9852_AI_DMA_DB_IN(0, 512, 8192, false); %reflectogram buffer
    plot(data);
    %figure(i);
    %plot(data);
%     
%     dt=data(200:length(data),:); %trimmed reflectograms (w/o sync, pulse)
%     
%     std_acc = 0;                %accumulator for mean std 
%     for j = 1:size(dt,2)
%         std_acc=std_acc+std(dt(:,j));
%     end
%     std_m=std_acc/size(dt,2);   %calc mean std... may be std2 better than mean std
%     disp(std_m);
%     
%     means(k)=mean2(dt);
%     mins(k)=mean(min(dt));
%     maxs(k)=mean(max(dt));
%     
%     stds(k)=std_m;
%     volt(k)=i;
%     k=k+1;
    %plot(dt);
end

% figure(1);
% plot(volt,stds);
% aaa = gca;
% %aaa.XAxis.Exponent=3;
% aaa.XAxis.Exponent=0;
% 
% figure(2);
% plot(volt,means,'','color',[.0 .5 .0]);
% hold on;
% plot(volt,mins','','color',[.0 .0 .7]);
% plot(volt,maxs','','color',[.7 .0 .0]);
% hold off;
% aaa = gca;
% %aaa.XAxis.Exponent=3;
% aaa.XAxis.Exponent=0;

