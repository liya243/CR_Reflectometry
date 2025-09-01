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
function res=PCIe_9852_2CH_GET(adc, channel, buffHeight, segmentSize, sync_ch)
    %clc %clear console
    %clear all;
    %close all;
    addpath('adlink/WDDASK');
    
    LIB = adc.LIB;
%     tf = libisloaded( adc.LIB );
%     
%     if ~tf
%         %check x64 or x86
%         if strcmp(computer('arch'),'win64')
%             DLL = 'WD-Dask64.dll';
%             HEADER = 'WD-Dask64_forMatlab.h';
%             LIB = 'dasklib';
%             EXT = 'wddaskex';
%         else
%             DLL = 'WD-Dask.dll';
%             HEADER = 'WD-Dask_forMatlab.h';
%             LIB = 'dasklib';
%             EXT = 'wddaskex';
%         end
%         %check DLL and HEADER 
%         if ~exist(DLL,'file') || ~exist(HEADER,'file') || ~exist([EXT '.h'],'file')
%             fprintf('DLL or HEADER is not found here\n');
%             return;
%         end
%     end
    %check lib loading
    
%% Function vars init
    accSize = buffHeight * segmentSize;
    if channel == -1
        accBuf0 = zeros(1,accSize,'double');
        accBuf1 = zeros(1,accSize,'double');
    else
        accBuf = zeros(1,accSize,'double');
    end
    %accBuf = zeros(buffHeight,segmentSize,'double');
    accPos = 1;
    trigIndex = 1;
    trigLevel = 0.5;
    trigger = false;
%% ADC Init
    AccessCnt = int32(0);
    Stopped = 0;
    HalfReady = 0;
    bufferID0 = uint16(0);
    bufferID1 = uint16(0);
    AI_ReadCount = adc.ReadCount;
    SampleRate = adc.SampleRate;
    card = adc.card;
    pbuffer0 = adc.pbuffer0;
    pbuffer1 = adc.pbuffer1;
    %LIB = adc.LIB;
    AdRange = adc.AdRange;
    
    volts = zeros(1,AI_ReadCount,'double');
 
    %%

    tic;    % Set the Time
    margin = 2; % margin in seconds for the TimeOut
    TimeOut = double(AI_ReadCount)/SampleRate + margin; % Acquisition time in seconds (plus margin)
    TimeLeft = TimeOut;
%     fprintf('Start AI\n');
    index = 0;
    %Here is like kbhit() in C code , press anykey to exit loop
    overrunFlag = uint16(0);
    
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
        %trying idea... if double buffer is in an overrun state, then reset
        %overrun and skip the current buffer in unknown unsynced state, so
        %then we can use next the fresh nice and good buffer
        [error, overrunFlag] = calllib('dasklib','WD_AI_AsyncDblBufferOverrun',card, 0, overrunFlag);%check overrun
        if error < 0 
            calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
            calllib(LIB,'WD_AI_ContBufferReset',card);
            calllib(LIB,'WD_Release_Card',card);
            unloadlibrary(LIB);
            fprintf('WD_AI_AsyncDblBufferOverrun failed with error code %d\n',error);
            return;
        end
        
        if overrunFlag==true && HalfReady ==true
            HalfReady=false;
            
            [error, overrunFlag] = calllib('dasklib','WD_AI_AsyncDblBufferOverrun',card, 1, overrunFlag);%clear overrun
            if error < 0 
                calllib(LIB,'WD_AI_AsyncClear',card,0,AccessCnt);
                calllib(LIB,'WD_AI_ContBufferReset',card);
                calllib(LIB,'WD_Release_Card',card);
                unloadlibrary(LIB);
                fprintf('WD_AI_AsyncDblBufferOverrun failed with error code %d\n',error);
                return;
            end
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
            
            calllib('dasklib','WD_AI_AsyncDblBufferHandled',card);
            %WD_AI_AsyncDblBufferHandled!!!!!!!!!!!!!!!!!!!!!! to protect
            %from overrun?!?!?!?!?!?!?!!?
            %NEED TESTS!!!!!!!!!!!
            
            %res=volts;
            %Stopped=true;
            %plot(volts);
            
            if channel == -1
%                 disp('All Channels');
                volts1 = volts(2:2:end);
                volts0 = volts(1:2:end);
                vsize = length(volts0);
            else
                vsize = length(volts);
            end
            %copy results

            for i=1:vsize
                if trigger%если синхра найдена
%                     if accPos == accSize
%                         disp('ACC END');
%                     end
                    
                    if trigIndex <= segmentSize && accPos <= accSize
                        if channel == -1
                            accBuf0(accPos) = volts0(i);
                            accBuf1(accPos) = volts1(i);
                        else
                            accBuf(accPos) = volts(i);
                        end
                        
                        accPos = accPos + 1;
                        trigIndex = trigIndex + 1;
                    else
                        trigger = false;
                        if accPos > accSize
                            %копирование и на выход
                            if channel == -1
                                res{1} = (reshape(accBuf0, [segmentSize,buffHeight])); %%return value
                                res{2} = (reshape(accBuf1, [segmentSize,buffHeight])); %%return value
                            else
                                res = (reshape(accBuf, [segmentSize,buffHeight])); %%return value
                            end
                            Stopped=true;
                            accPos=1;
                        end
                        trigIndex=1;
                    end
                else%поиск синхроимпульса подмешанному в рефлектограмму
                    if channel == -1
                        if sync_ch==0
                            if trigLevel >= 0 %если триггерный уровень > 0
                                if volts0(i) > trigLevel%если данные выше триггера
                                    trigger = true;
                                end
                            else%если триггерный уровень < 0
                                if volts0(i) < trigLevel
                                    trigger = true;
                                end
                            end
                        else
                            if trigLevel >= 0 %если триггерный уровень > 0
                                if volts1(i) > trigLevel%если данные выше триггера
                                    trigger = true;
                                end
                            else%если триггерный уровень < 0
                                if volts1(i) < trigLevel
                                    trigger = true;
                                end
                            end
                        end
                    else
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
            end

            %res = reshape(accBuf, [buffHeight,segmentSize]); %%return value
            %Stopped=true;
        end
        if Stopped == true
            break;
        end
        pause(0.001);
    end
    
%     fprintf('Done...\n');
    
end