%%--------------------------------------------------------------------------
%	Company:		ADLINK													
%	Last update:	2016/05/23											
%                                                                          
%	This sample runs AI with DMA Double Buffer continuously.	
%																			
%	SyncMode:		ASync													
%   Channel:	    0														
%	Trigger Source:	SOFTWARE												
%	Trigger Type:	POST													
%	Delay:			Disabled												
%	ReTrigger:		Disabled												
%-------------------------------------------------------------------------- 
%%
function res=PCIe_9852_AI_DMA_DB_IN(channel, buffHeight, segmentSize, init)
    %clc %clear console
    %clear all;
    %close all;
    addpath('adlink/WDDASK');
    %check x64 or x86
    if strcmp(computer('arch'),'win64')
        DLL = 'WD-Dask64.dll';
        HEADER = 'WD-Dask64_forMatlab.h';
        LIB = 'dasklib';
        EXT = 'wddaskex';
    else
        DLL = 'WD-Dask.dll';
        HEADER = 'WD-Dask_forMatlab.h';
        LIB = 'dasklib';
        EXT = 'wddaskex';
    end
    %check DLL and HEADER 
    if ~exist(DLL,'file') || ~exist(HEADER,'file') || ~exist([EXT '.h'],'file')
        fprintf('DLL or HEADER is not found here\n');
        return;
    end
    %check lib loading
    if ~libisloaded(LIB)
        [notfound,warnings] = loadlibrary(DLL,HEADER,'alias',LIB,'addheader',EXT);
        if ~libisloaded(LIB)
            fprintf('Load lib failed\n');
            return;
        end
    end
    
%% Function vars init
    accSize = buffHeight * segmentSize;
    accBuf = zeros(1,accSize,'double');
    %accBuf = zeros(buffHeight,segmentSize,'double');
    accPos = 1;
    trigIndex = 1;
    trigLevel = -1.0;
    trigger = false;
%% ADC Init
    card_type = WDDASK.PCIe_9852;%PCIe_9852
    card_num = uint16(0); 
    %TimeBase = WDDASK.WD_IntTimeBase;%WD_IntTimeBase
    TimeBase = WDDASK.WD_ExtTimeBase;%WD_IntTimeBase
    ConvSrc = WDDASK.WD_AI_ADCONVSRC_TimePacer;%WD_AI_ADCONVSRC_TimePacer
    SyncMode = WDDASK.ASYNCH_OP;%async
    %AdRange = WDDASK.AD_B_10_V;%AD_B_10_V   
    AdRange = WDDASK.AD_B_2_V;
    Impedance = WDDASK.IMPEDANCE_50Ohm;
    P9852_AI_IMPEDANCE = WDDASK.AI_IMPEDANCE;
    %Channel = uint16(0);
    Channel = uint16(channel);
    TrigMode = WDDASK.WD_AI_TRGMOD_POST;%WD_AI_TRGMOD_POST
    TrigSrc = WDDASK.WD_AI_TRGSRC_SOFT;%WD_AI_TRGSRC_SOFT
    TrigPol = WDDASK.WD_AI_TrgNegative;%WD_AI_TrgNegative
    anaTrigchan = uint16(0);
    anaTriglevel = 0.0;
    postTrigScans = uint32(0);
    preTrigScans = uint32(0);
    trigDelayTicks = uint32(0);
    reTrgCnt = uint32(1);
    modeCtrl = WDDASK.DAQSTEPPED;%DAQSTEPPED
    %AI_ReadCount = uint32(1024000); %~ 100e6/1024000 = 97 Hz
    %AI_ReadCount = uint32(2048000); %~ 100e6/2048000 = 48.8 Hz
    %AI_ReadCount = uint32(4096000); %~ 100e6/4096000 = 24.4 Hz
    %AI_ReadCount = uint32(8192000); %~ 100e6/8192000 = 12.2 Hz
    AI_ReadCount = uint32(8912896); % 17 MB/2 ~ 100e6/8912896 = 11.22 Hz
    %buffer0 = zeros(1,AI_ReadCount,'uint16');
    %buffer1 = zeros(1,AI_ReadCount,'uint16');
    volts = zeros(1,AI_ReadCount,'double');
    P9852_TIMEBASE = WDDASK.P9852_TIMEBASE;%200M check WDDASK.m
    ScanIntrv = uint32(1); %Scan Rate: P9852_TIMEBASE/1 = 200M Hz
    SampIntrv = uint32(1); %Sampling Rate: P9852_TIMEBASE/1 = 200M Hz
    SampleRate = double(P9852_TIMEBASE/SampIntrv);
    AutoReset = 1;
    AccessCnt = int32(0);
    Stopped = 0;
    HalfReady = 0;
    bufferID0 = uint16(0);
    bufferID1 = uint16(0);
    %%
    %=== Typical Main procedure ===
    card = calllib(LIB,'WD_Register_Card',card_type,card_num);
    if card < 0 
        unloadlibrary(LIB);
        error = card;
        fprintf('WD_Register_Card failed with error code %d\n',error);
        return;
    end
        % uncomment for  WD_GetDeviceProperties
%     d.card_type = uint16(0);
%     d.num_of_channel = uint16(0);
%     d.data_width = uint16(0);
%     d.default_range = uint16(0);
%     d.ctrKHz = 0;
%     d.bdbase =0;
%     d.mask =0;
%     d.reserved = zeros(1,19);
%     pCardProp = libpointer('s_DAS_IOT_DEV_PROPPtr',d);
%     [error,cardProp]=calllib(LIB,'WD_GetDeviceProperties',card,0,pCardProp);
%     if error < 0
%         clear pCardProp;
%         clear cardProp;
%         clear d;
%         calllib ('dasklib','WD_Release_Card',card);
%         unloadlibrary(LIB);
%         fprintf('WD_GetDeviceProperties failed with error code %d\n',error);
%         return;
%     end
%     AdRange = cardProp.default_range;  
%     clear pCardProp;
%     clear cardProp;
%     clear d;
if init==true
    error = calllib(LIB,'WD_AI_CH_Config',card,Channel,AdRange);
    if error < 0
        calllib ('dasklib','WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_CH_Config failed with error code %d\n',error);
        return;
    end
    
    error = calllib(LIB,'WD_AI_CH_ChangeParam',card,Channel,P9852_AI_IMPEDANCE, Impedance);
    if error < 0
        calllib ('dasklib','WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_CH_ChangeParam failed with error code %d\n',error);
        return;
    end
end    
    error = calllib(LIB,'WD_AI_Config',card,TimeBase,1,ConvSrc,0,AutoReset);
    if error < 0
        calllib ('dasklib','WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_Config failed with error code %d\n',error);
        return;
    end

    error = calllib(LIB,'WD_AI_Trig_Config',card,TrigMode,TrigSrc,TrigPol,anaTrigchan,anaTriglevel,postTrigScans,preTrigScans,trigDelayTicks,reTrgCnt);
    if error < 0
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_Trig_Config failed with error code %d\n',error);
        return;
    end  

    error = calllib(LIB,'WD_AI_AsyncDblBufferMode',card,1);
    if error < 0
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_AsyncDblBufferMode failed with error code %d\n',error);
        return;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %tpbuffer0 and tpbuffer0 are voidPtr type.
    %And they are useless after returning from calllib.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    pbuffer0 = calllib(LIB,'WD_Buffer_Alloc',card,AI_ReadCount*2);
    setdatatype(pbuffer0,'uint16Ptr',1,AI_ReadCount);    
    %pbuffer0 = libpointer('uint16Ptr',buffer0);
    [error,tpbuffer0,bufferID0] = calllib(LIB,'WD_AI_ContBufferSetup',card,pbuffer0,AI_ReadCount,bufferID0);
    if error < 0
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_ContBufferSetup failed with error code %d\n',error);
        return;
    end
    
    pbuffer1 = calllib(LIB,'WD_Buffer_Alloc',card,AI_ReadCount*2);
    setdatatype(pbuffer1,'uint16Ptr',1,AI_ReadCount);
    %pbuffer1 = libpointer('uint16Ptr',buffer1);
    [error,tpbuffer1,bufferID1] = calllib(LIB,'WD_AI_ContBufferSetup',card,pbuffer1,AI_ReadCount,bufferID1);
    if error < 0
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_ContBufferSetup failed with error code %d\n',error);
        return;
    end

    error = calllib(LIB,'WD_AI_ContReadChannel',card,Channel,0,AI_ReadCount,ScanIntrv,SampIntrv,SyncMode);
    if error < 0 
        calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
        calllib(LIB,'WD_AI_ContBufferReset',card);
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_ContReadChannel failed with error code %d\n',error);
        return;
    end
    
    tic;    % Set the Time
    margin = 2; % margin in seconds for the TimeOut
    TimeOut = double(AI_ReadCount)/SampleRate + margin; % Acquisition time in seconds (plus margin)
    TimeLeft = TimeOut;
    %fprintf('Start AI\n');
    index = 0;
    %Here is like kbhit() in C code , press anykey to exit loop
    
    %figh = figure('keypressfcn',@(obj,ev) set(obj,'userdata',1));
    %while isempty(get(figh,'userdata')) && TimeLeft>=0
    while TimeLeft>=0
        TimeLeft = TimeOut - toc;
        [error, HalfReady, Stopped] = calllib('dasklib','WD_AI_AsyncDblBufferHalfReady',card, HalfReady, Stopped);
        if error < 0 
            calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
            calllib(LIB,'WD_AI_ContBufferReset',card);
            calllib(LIB,'WD_Release_Card',card);
            unloadlibrary(LIB);
            fprintf('WD_AI_AsyncDblBufferHalfReady failed with error code %d\n',error);
            return;
        end
        if HalfReady == true
            tic;
            TimeLeft = TimeOut;%reset TimeLeft for next buffer   
            
            if index == 0
                buffer0 = pbuffer0.Value;
                [error,buffer0,volts]=calllib(LIB,'WD_AI_ContVScale',card,AdRange,buffer0,volts,AI_ReadCount);
                index = 1;
                %fprintf('Buffer 0 HalfReady , press anykey on figure to stop\n');
            else
                buffer1 = pbuffer1.Value;
                [error,buffer1,volts]=calllib(LIB,'WD_AI_ContVScale',card,AdRange,buffer1,volts,AI_ReadCount);
                index = 0;
                %fprintf('Buffer 1 HalfReady , press anykey on figure to stop\n');
            end
            %res=volts;
            %Stopped=true;
            %plot(volts);
            
            %copy results
            for i=1:length(volts)
                if trigger%если синхра найдена
                    if accPos == accSize
                        %disp('XXX END');
                    end
                    
                    if trigIndex <= segmentSize && accPos <= accSize
                        accBuf(accPos) = volts(i);
                        
                        accPos = accPos + 1;
                        trigIndex = trigIndex + 1;
                    else
                        trigger = false;
                        if accPos > accSize
                            %копирование и на выход
                            res = (reshape(accBuf, [segmentSize,buffHeight])); %%return value
                            Stopped=true;
                            accPos=1;
                        end
                        trigIndex=1;
                    end
                else%поиск синхроимпульса подмешанному в рефлектограмму
                   if trigLevel >= 0 %если триггерный уровень > 0
                       if volts(i) > trigLevel%если данные выше триггера
                           trigger = true;
                       end
                   else%если триггерный уровень < 0
                       if volts(i) < trigLevel
                           trigger = true;
                       end
                   end
%                    if accPos<accSize
%                        trigger=true; %for debug
%                    end
                end
            end

            %res = reshape(accBuf, [buffHeight,segmentSize]); %%return value
            %Stopped=true;
        end
        if Stopped == true
            break;
        end
        pause(0.001);
    end
   % fprintf('Stop AI\n');
    
    if TimeLeft < 0
        calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
        calllib(LIB,'WD_AI_ContBufferReset',card);
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_ConvertCheck time out.\n');
        return;
    end
 
    [error,temp,AccessCnt] = calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
    if error < 0
        calllib(LIB,'WD_AI_ContBufferReset',card);
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_AsyncClear failed with error code %d\n',error);
        return;
    end
    
    if ~AutoReset
        calllib(LIB,'WD_AI_ContBufferReset',card);
    end
    
    calllib (LIB,'WD_Buffer_Free',card,pbuffer0);
    calllib (LIB,'WD_Buffer_Free',card,pbuffer1);
    calllib (LIB,'WD_Release_Card',card);
    unloadlibrary(LIB);
end