%%--------------------------------------------------------------------------
%	Company:		ADLINK													
%	Last update:	2020/03/20												
%                                                                          
%	This M file support you to use parameter name as Header file.												
%--------------------------------------------------------------------------
classdef WDDASK
    properties(Constant)
%TIMEBASE add by Karl
P9814_TIMEBASE = 80000000;
P9834_TIMEBASE = 80000000;
P9846_TIMEBASE = 40000000;
P9848_TIMEBASE = 1000000000;
P9852_TIMEBASE = 2000000000;	
%ADLink PCI Card Type
%PCI/PXI-9820
 PCI_9820        =uint16(hex2dec('1'));
%PXI 98x6 devices
 PXI_9816D       =uint16(hex2dec('2'));
 PXI_9826D       =uint16(hex2dec('3'));
 PXI_9846D       =uint16(hex2dec('4'));
 PXI_9846DW      =uint16(hex2dec('4'));
 PXI_9816H       =uint16(hex2dec('5'));
 PXI_9826H       =uint16(hex2dec('6'));
 PXI_9846H       =uint16(hex2dec('7'));
 PXI_9846HW      =uint16(hex2dec('7'));
 PXI_9816V       =uint16(hex2dec('8'));
 PXI_9826V       =uint16(hex2dec('9'));
 PXI_9846V       =uint16(hex2dec('a'));
 PXI_9846VW      =uint16(hex2dec('a'));
 PXI_9846VID     =uint16(hex2dec('b'));
%PCI 98x6 devices
 PCI_9816D       =uint16(hex2dec('12'));
 PCI_9826D       =uint16(hex2dec('13'));
 PCI_9846D       =uint16(hex2dec('14'));
 PCI_9846DW      =uint16(hex2dec('14'));
 PCI_9816H       =uint16(hex2dec('15'));
 PCI_9826H       =uint16(hex2dec('16'));
 PCI_9846H       =uint16(hex2dec('17'));
 PCI_9846HW      =uint16(hex2dec('17'));
 PCI_9816V       =uint16(hex2dec('18'));
 PCI_9826V       =uint16(hex2dec('19'));
 PCI_9846V       =uint16(hex2dec('1a'));
 PCI_9846VW      =uint16(hex2dec('1a'));
%PCIe 98x6 devices
 PCIe_9816D      =uint16(hex2dec('22'));
 PCIe_9826D      =uint16(hex2dec('23'));
 PCIe_9846D      =uint16(hex2dec('24'));
 PCIe_9846DW     =uint16(hex2dec('24'));
 PCIe_9816H      =uint16(hex2dec('25'));
 PCIe_9826H      =uint16(hex2dec('26'));
 PCIe_9846H      =uint16(hex2dec('27'));
 PCIe_9846HW     =uint16(hex2dec('27'));
 PCIe_9816V      =uint16(hex2dec('28'));
 PCIe_9826V      =uint16(hex2dec('29'));
 PCIe_9846V      =uint16(hex2dec('2a'));
 PCIe_9846VW     =uint16(hex2dec('2a'));
%PCIe/PXIe-9842
 PCIe_9842       =uint16(hex2dec('30'));
%PXIe-9848
 PXIe_9848       =uint16(hex2dec('32'));
%PCIe-9852
 PCIe_9852       =uint16(hex2dec('33'));
%PXIe-9852
 PXIe_9852       =uint16(hex2dec('34'));
%PCIe-9814
 PCIe_9814       =uint16(hex2dec('35'));
%PCIe-9834
 PCIe_9834       =uint16(hex2dec('37'));

%obsolete
 PCI_9816        =uint16(hex2dec('2'))%PXI_9816D;
 PCI_9826        =uint16(hex2dec('3'));%PXI_9826D;
 PCI_9846        =uint16(hex2dec('4'));%PXI_9846D;

 MAX_CARD        =uint16(32);
%Synchronous Mode
 SYNCH_OP        =uint16(1);
 ASYNCH_OP       =uint16(2);

%AD Range
 AD_B_10_V       =uint16(1);
 AD_B_5_V        =uint16(2);
 AD_B_2_5_V      =uint16(3);
 AD_B_1_25_V     =uint16(4);
 AD_B_0_625_V    =uint16(5);
 AD_B_0_3125_V   =uint16(6);
 AD_B_0_5_V      =uint16(7);
 AD_B_0_05_V     =uint16(8);
 AD_B_0_005_V    =uint16(9);
 AD_B_1_V       =uint16(10);
 AD_B_0_1_V     =uint16(11);
 AD_B_0_01_V    =uint16(12);
 AD_B_0_001_V   =uint16(13);
 AD_U_20_V      =uint16(14);
 AD_U_10_V      =uint16(15);
 AD_U_5_V       =uint16(16);
 AD_U_2_5_V     =uint16(17);
 AD_U_1_25_V    =uint16(18);
 AD_U_1_V       =uint16(19);
 AD_U_0_1_V     =uint16(20);
 AD_U_0_01_V    =uint16(21);
 AD_U_0_001_V   =uint16(22);
 AD_B_2_V       =uint16(23);
 AD_B_0_25_V    =uint16(24);
 AD_B_0_2_V     =uint16(25);
 AD_U_4_V       =uint16(26);
 AD_U_2_V       =uint16(27);
 AD_U_0_5_V     =uint16(28);
 AD_U_0_4_V     =uint16(29);
 AD_B_1_5_V     =uint16(30);
 AD_B_0_2145_V  =uint16(31);

 All_Channels   =int16(-1);

 WD_AI_ADCONVSRC_TimePacer =uint16(0);

 WD_AI_TRGSRC_SOFT      =uint16(hex2dec('00'));   
 WD_AI_TRGSRC_ANA       =uint16(hex2dec('01'));   
 WD_AI_TRGSRC_ExtD      =uint16(hex2dec('02'));   
 WD_AI_TRSRC_SSI_1      =uint16(hex2dec('03'));
 WD_AI_TRSRC_SSI_2      =uint16(hex2dec('04'));
 WD_AI_TRSRC_PXIStar    =uint16(hex2dec('05'));
 WD_AI_TRSRC_PXIeStar   =uint16(hex2dec('06'));            
 WD_AI_TRGMOD_POST      =uint16(hex2dec('00'));   %Post Trigger Mode
 WD_AI_TRGMOD_PRE       =uint16(hex2dec('01'));   %Pre-Trigger Mode
 WD_AI_TRGMOD_MIDL      =uint16(hex2dec('02'));   %Middle Trigger Mode
 WD_AI_TRGMOD_DELAY     =uint16(hex2dec('03'));   %Delay Trigger Mode
 WD_AI_TrgPositive      =uint16(hex2dec('1'));
 WD_AI_TrgNegative      =uint16(hex2dec('0'));

%obsolete
 WD_AI_TRSRC_PXIStart   =uint16(hex2dec('05'));

 WD_AIEvent_Manual      =uint16(hex2dec('80'));   %AI event manual reset

% define analog trigger Dedicated Channel 
 CH0ATRIG	   =uint16(hex2dec('00'));
 CH1ATRIG	   =uint16(hex2dec('01'));
 CH2ATRIG	   =uint16(hex2dec('02'));
 CH3ATRIG	   =uint16(hex2dec('03'));
 CH4ATRIG	   =uint16(hex2dec('04'));
 CH5ATRIG	   =uint16(hex2dec('05'));
 CH6ATRIG	   =uint16(hex2dec('06'));
 CH7ATRIG	   =uint16(hex2dec('07'));

% Time Base 
 WD_ExtTimeBase		  =uint16(hex2dec('0'));
 WD_SSITimeBase		  =uint16(hex2dec('1'));
	WD_StarTimeBase		  =uint16(hex2dec('2'));
 WD_IntTimeBase		  =uint16(hex2dec('3'));
	WD_PXI_CLK10		  	=uint16(hex2dec('4'));
	WD_PLL_REF_PXICLK10	  =uint16(hex2dec('4'));
	WD_PLL_REF_EXT10	  =uint16(hex2dec('5'));
	WD_PLL_REF_EXT		  =uint16(hex2dec('5'));%WD_PLL_REF_EXT10;
	WD_PXIe_CLK100		  =uint16(hex2dec('6'));
 WD_PLL_REF_PXIeCLK100	  =uint16(hex2dec('6'));
	WD_DBoard_TimeBase	  =uint16(hex2dec('7')); 

%SSI signal codes
 SSI_TIME        =uint16(15);
 SSI_TRIG_SRC1   =uint16(7);
 SSI_TRIG_SRC2   =uint16(5);
 SSI_TRIG_SRC2_S =uint16(5);
 SSI_TRIG_SRC2_T =uint16(6); 
 SSI_PRE_DATA_RDY =uint16(hex2dec('10'));
% signal lines
 PXI_TRIG_0      =uint16(0);
 PXI_TRIG_1      =uint16(1);
 PXI_TRIG_2      =uint16(2);
 PXI_TRIG_3      =uint16(3);
 PXI_TRIG_4      =uint16(4);
 PXI_TRIG_5      =uint16(5);
 PXI_TRIG_6      =uint16(6);
 PXI_TRIG_7      =uint16(7);
 PXI_STAR_TRIG   =uint16(8);
 TRG_IO		=uint16(9);

%SSI cable lines
 SSI_LINE_0      =uint16(0);
 SSI_LINE_1      =uint16(1);
 SSI_LINE_2      =uint16(2);
 SSI_LINE_3      =uint16(3);
 SSI_LINE_4      =uint16(4);
 SSI_LINE_5      =uint16(5);
 SSI_LINE_6      =uint16(6);
 SSI_LINE_7      =uint16(7);

%obsolete
 PXI_START_TRIG  =uint16(8);

%Software trigger op code
 SOFTTRIG_AI	 =uint16(hex2dec('1'));
 SOFTTRIG_AI_OUT	 =uint16(hex2dec('2'));
%DAQ Event type for the event message  
 DAQEnd   =uint16(0);
 DBEvent  =uint16(1);
 TrigEvent  =uint16(2);
%DAQ advanced mode  
 DAQSTEPPED    =uint16(hex2dec('1'));   
 RestartEn     =uint16(hex2dec('2'));
 DualBufEn     =uint16(hex2dec('4'));
 ManualSoftTrg =uint16(hex2dec('40'));
 DMASTEPPED    =uint16(hex2dec('80'));
 AI_AVE		 		=uint16(hex2dec('8'));
 AI_AVE_32		 	=uint16(hex2dec('10'));

%define ai channel parameter
 AI_RANGE	=uint16(0);
 AI_IMPEDANCE	=uint16(1);
 ADC_DITHER	=uint16(2);
 AI_COUPLING	=uint16(3);
 ADC_Bandwidth	=uint16(4);
 SIGNAL_FIR		=uint16(5);

%define ai channel parameter value
 IMPEDANCE_50Ohm =uint16(0);
 IMPEDANCE_HI	=uint16(1);

 ADC_DITHER_DIS	=uint16(0);	
 ADC_DITHER_EN	=uint16(1);

 DC_Coupling	=uint16(0);	
 AC_Coupling	=uint16(1);

 BANDWIDTH_DEVICE_DEFAULT 	=uint16(0);	
 BANDWIDTH_20M	=uint16(20);
 BANDWIDTH_100M	=uint16(100);

 FIR_DIS				=uint16(0);
 FIR_EN_20M		=uint16(1);
 FIR_EN_10M		=uint16(2);

%ai trigger out channel
 AITRIGOUT_CH0	=uint16(0);
 AITRIGOUT_PXI	=uint16(2);
 AITRIGOUT_PXI_TRIG_0	=uint16(2);
 AITRIGOUT_PXI_TRIG_1	=uint16(3);
 AITRIGOUT_PXI_TRIG_2	=uint16(4);
 AITRIGOUT_PXI_TRIG_3	=uint16(5);
 AITRIGOUT_PXI_TRIG_4	=uint16(6);
 AITRIGOUT_PXI_TRIG_5	=uint16(7);
 AITRIGOUT_PXI_TRIG_6	=uint16(8);
 AITRIGOUT_PXI_TRIG_7	=uint16(9);

%DIO Port Direction
 INPUT_PORT      =uint16(1);
 OUTPUT_PORT     =uint16(2);
%DIO Line Direction
 INPUT_LINE      =uint16(1);
 OUTPUT_LINE     =uint16(2);
%DIO mode
 SDI_En      =uint16(0);
 SDI_Dis     =uint16(1);

%Calibration Action
 CalLoad		=uint16(0);
 AutoCal		=uint16(1);
 CalCopy		=uint16(2);

%measure items
 VAL_MAX		=uint16(0);
 VAL_MIN		=uint16(1);

%TrigOUT Config
 WD_OutTrgPWidth_50ns   =uint16(hex2dec('0'));
 WD_OutTrgPWidth_100ns  =uint16(hex2dec('1'));
 WD_OutTrgPWidth_150ns  =uint16(hex2dec('2'));
 WD_OutTrgPWidth_200ns  =uint16(hex2dec('3'));
 WD_OutTrgPWidth_500ns  =uint16(hex2dec('4'));
 WD_OutTrgPWidth_1us    =uint16(hex2dec('5'));
 WD_OutTrgPWidth_2us    =uint16(hex2dec('6'));
 WD_OutTrgPWidth_5us    =uint16(hex2dec('7'));
 WD_OutTrgPWidth_10us   =uint16(hex2dec('8'));

%TrigOUT SRC/POL Config
 WD_OutTrgSrcAuto   =uint16(hex2dec('0'));
 WD_OutTrgSrcManual =uint16(hex2dec('1'));
 WD_OutTrg_Rising   =uint16(hex2dec('0'));
 WD_OutTrg_Fall     =uint16(hex2dec('10'));

	end
end