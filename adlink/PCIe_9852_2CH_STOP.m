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
function PCIe_9852_2CH_STOP(adc)
    %clc %clear console
    %clear all;
    %close all;
    addpath('adlink/WDDASK');
    %check x64 or x86
        
    fprintf('Stop AI\n');
    
    AccessCnt = int32(0);
    
    [error,temp,AccessCnt] = calllib(adc.LIB,'WD_AI_AsyncClear',adc.card,0,AccessCnt);
    if error < 0
        calllib(adc.LIB,'WD_AI_ContBufferReset',adc.card);
        calllib(adc.LIB,'WD_Release_Card',adc.card);
        unloadlibrary(adc.LIB);
        fprintf('WD_AI_AsyncClear failed with error code %d\n',error);
        return;
    end
    
    %if ~AutoReset
        calllib(adc.LIB,'WD_AI_ContBufferReset',adc.card);
    %end
    
    calllib (adc.LIB,'WD_Buffer_Free',adc.card,adc.pbuffer0);
    calllib (adc.LIB,'WD_Buffer_Free',adc.card,adc.pbuffer1);
    calllib (adc.LIB,'WD_Release_Card',adc.card);
    unloadlibrary(adc.LIB);
end