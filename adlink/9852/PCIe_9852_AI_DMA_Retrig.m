%%--------------------------------------------------------------------------
%	Company:		ADLINK													
%	Last update:	2016/05/23											
%                                                                          
%	This sample runs AI with DMA Single Buffer continuously.	
%																			
%	SyncMode:		ASync													
%   Channel:	    0														
%	Trigger Source:	SOFTWARE												
%	Trigger Type:	POST													
%	Delay:			Disabled												
%	ReTrigger:		Disabled												
%-------------------------------------------------------------------------- 
%%
    clc
    clear all;
    close all;
    addpath('../WDDASK');
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
%%
    card_type = WDDASK.PCIe_9852;%PCIe_9852 
    card_num = uint16(0); 
    TimeBase = WDDASK.WD_IntTimeBase;%WD_IntTimeBase
    ConvSrc = WDDASK.WD_AI_ADCONVSRC_TimePacer;%WD_AI_ADCONVSRC_TimePacer
    SyncMode = WDDASK.ASYNCH_OP;%async 
    AdRange = WDDASK.AD_B_10_V;%AD_B_10_V   1
    Channel = uint16(0);
    TrigMode = WDDASK.WD_AI_TRGMOD_POST;%WD_AI_TRGMOD_POST
    TrigSrc = WDDASK.WD_AI_TRGSRC_ExtD;%WD_AI_TRGSRC_SOFT
    TrigPol = WDDASK.WD_AI_TrgNegative;%WD_AI_TrgNegative
    anaTrigchan = uint16(0);
    anaTriglevel = 0.0;
    postTrigScans = uint32(0);
    preTrigScans = uint32(0);
    trigDelayTicks = uint32(0);
    reTrgCnt = uint32(10);
    modeCtrl = WDDASK.DAQSTEPPED;%DAQSTEPPED
    AI_ReadCount = uint32(10240);
    %buffer = zeros(1,AI_ReadCount,'uint16');
    volts = zeros(1,AI_ReadCount*reTrgCnt,'double');
    P9852_TIMEBASE = WDDASK.P9852_TIMEBASE;%200M check WDDASK.m
    ScanIntrv = uint32(1); %Scan Rate: P9852_TIMEBASE/1 = 200M Hz
    SampIntrv = uint32(1); %Sampling Rate: P9852_TIMEBASE/1 = 200M Hz
    SampleRate = double(P9852_TIMEBASE/SampIntrv);
    AutoReset = 1;
    AccessCnt = int32(0);
    Stopped = 0;
    bufferID = uint16(0);  	 
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
%     d.reserved = zeros(1,15);
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
    error = calllib(LIB,'WD_AI_CH_Config',card,Channel,AdRange);
    if error < 0
        calllib ('dasklib','WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_CH_Config failed with error code %d\n',error);
        return;
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

    %error = calllib(LIB,'WD_AI_Set_Mode',card,modeCtrl,1);
    %if error < 0
    %    calllib(LIB,'WD_Release_Card',card);
    %    unloadlibrary(LIB);
    %    fprintf('WD_AI_Set_Mode failed with error code %d\n',error);
    %    return;
    %end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %tpbuffer is voidPtr type.
    %And it is useless after returning from calllib.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%     tpbuffer2 = calllib(LIB,'WD_Buffer_Alloc',card,AI_ReadCount*8);
%     pbuffer = tpbuffer2+0;
%     pbuffer.Value = buffer;
    pbuffer = calllib(LIB,'WD_Buffer_Alloc',card,AI_ReadCount*2*reTrgCnt);
    setdatatype(pbuffer,'uint16Ptr',1,AI_ReadCount*reTrgCnt);

    %pbuffer = libpointer('uint16Ptr',buffer);
    [error,tpbuffer,bufferID] = calllib(LIB,'WD_AI_ContBufferSetup',card,pbuffer,AI_ReadCount*reTrgCnt,bufferID);
    if error < 0
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_ContBufferSetup failed with error code %d\n',error);
        return;
    end

    error = calllib(LIB,'WD_AI_ContReadChannel',card,Channel,bufferID,AI_ReadCount*reTrgCnt,ScanIntrv,SampIntrv,SyncMode);
    if error < 0 
        calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
        calllib(LIB,'WD_AI_ContBufferReset',card);
        calllib(LIB,'WD_Release_Card',card);
        unloadlibrary(LIB);
        fprintf('WD_AI_ContReadChannel failed with error code %d\n',error);
        return;
    end
    %Here is like kbhit() in C code , press anykey to exit loop
    figh = figure('keypressfcn',@(obj,ev) set(obj,'userdata',1));
    while isempty(get(figh,'userdata'))
        [error, Stopped] = calllib(LIB,'WD_AI_ConvertCheck',card,Stopped);
        if Stopped == 1
            break;
        end
        pause(0.001);
    end
    
    tic;    % Set the Time
    margin = 2; % margin in seconds for the TimeOut
    TimeOut = double(AI_ReadCount)/SampleRate + margin; % Acquisition time in seconds (plus margin)
    TimeLeft = TimeOut;
    fprintf('Start AI\n');
    calllib(LIB,'WD_AI_DMA_Transfer',card,bufferID);
    while isempty(get(figh,'userdata')) && TimeLeft>=0
        TimeLeft = TimeOut - toc;
        [error,Stopped,AccessCnt] = calllib(LIB,'WD_AI_AsyncCheck',card,Stopped,AccessCnt);
        if error < 0 
            calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
            calllib(LIB,'WD_AI_ContBufferReset',card);
            calllib(LIB,'WD_Release_Card',card);
            unloadlibrary(LIB);
            fprintf('WD_AI_AsyncCheck failed with error code %d\n',error);
            return;
        end
        if Stopped == true
            break;
        end
        pause(0.001);
    end
    fprintf('Stop AI\n');
    
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
    
    buffer = pbuffer.Value;
    [error,buffer,volts]=calllib(LIB,'WD_AI_ContVScale',card,AdRange,buffer,volts,AccessCnt);
    plot(volts);
    %plot(buffer);
    if ~AutoReset
        calllib(LIB,'WD_AI_ContBufferReset',card);
    end
    calllib (LIB,'WD_Buffer_Free',card,pbuffer);
    calllib (LIB,'WD_Release_Card',card);
    unloadlibrary(LIB);
    
    