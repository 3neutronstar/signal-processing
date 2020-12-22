clc;
%% Load audio file
[OriginalAudio,Fs] = audioread('audio.flac');

% Sampling Frequency와 Bit Resolution을 찾기 위한 audioinfo 함수
info = audioinfo('audio.flac');

% Write the original audio file in assigned format before Transmission
audiowrite('beforeTransmissionFile.wav',OriginalAudio,44100);

%% Parameters 

%Audioinfo 함수를 통해 얻은 값
SamplingFrequency = 44100;
BitResolution = 16;


%Modulation / Demodulation Parameter
CarrierFrequency = 10000;
CarrierAmplitude = 0;
CarrierAmplitudeDemod = 0;
InitialPhaseForModulation = 0;
FrequencyDeviation = 5000;


%% 모노와 스테레오 구분(큰 의미 없음)
wid = size(OriginalAudio,1);
if(wid ==1)
    OriginalAudio = OriginalAudio(:);
end

%% 시간축 생성
t = (0:1/SamplingFrequency:((size(OriginalAudio, 1)-1)/SamplingFrequency))';
t = t(:, ones(1, size(OriginalAudio, 2)));

%% DSB
%Modulation
ModulatedDSBSignal = (OriginalAudio) .* cos(2 * pi * CarrierFrequency * t + InitialPhaseForModulation);

% Demodulation (Carrier를 곱하여 (위상이 같다고 가정) 복조한다.)
DemodulatedDSBSignal = ModulatedDSBSignal .* cos(2*pi * CarrierFrequency * t + InitialPhaseForModulation);
% Low-pass Filter (Carrier을 곱할 경우 두개의 Sideband가 생기므로 Baseband의 반대쪽을 없앤다)
DemodulatedDSBSignal = lowpass(DemodulatedDSBSignal,10000,SamplingFrequency);
%신호 정규화
DemodulatedDSBSignalNorm = DemodulatedDSBSignal./(max(abs(DemodulatedDSBSignal))); 

% Audio 출력
audiowrite('receviedDSBSoundFile.wav',DemodulatedDSBSignalNorm,SamplingFrequency);


%% AM
%정규화를 위한 DC Bias 값을 찾는다.
AMBias = abs(min(OriginalAudio));

%Modulation
ModulatedAMSignal = (OriginalAudio + AMBias) .* cos(2 * pi * CarrierFrequency * t + InitialPhaseForModulation);
%Demodulation (Envelope Detector with Hilbert Transform)   
DemodulatedAMSignal = abs(hilbert(ModulatedAMSignal).*exp(-1i*2*pi*CarrierFrequency*t));
%Demodulation 신호 정규화
DemodulatedAMSignalNorm = DemodulatedAMSignal./(max(abs(DemodulatedAMSignal(50000:500000,1:2)))); 
 
% Audio 출력
audiowrite('receviedAmSoundFile.wav',DemodulatedAMSignalNorm,SamplingFrequency);

%% FM
%modulation
int_x = cumsum(OriginalAudio)/SamplingFrequency; %% m(t)를 적분하여 위상 함수를 만든다.
ModulatedFMSignal = cos(2*pi*CarrierFrequency*t + 2*pi*FrequencyDeviation*int_x + InitialPhaseForModulation);    %%FM signal의 정의

% demodulation (Hilbert 변환을 이용한 Demodulation)
yq = hilbert(ModulatedFMSignal).*exp(-1i*2*pi*CarrierFrequency*t);
DemodulatedFMSignal = (1/(2*pi*FrequencyDeviation))*[zeros(1,size(yq,2)); diff(unwrap(angle(yq)))*SamplingFrequency];

%%신호 정규화
DemodulatedFMSignalNorm = DemodulatedFMSignal./(max(abs(DemodulatedFMSignal(50000:500000,1:2)))); 
%Audio out
audiowrite('receviedFmSoundFile.wav',DemodulatedFMSignalNorm,SamplingFrequency);


%% Noise channel for AM and FM

%Modulation
ModulatedAMSignalNoise = awgn(ModulatedAMSignal,40);
%Demodulation (Envelope Detector with Hilbert Transform)   
DemodulatedAMSignalNoise = abs(hilbert(ModulatedAMSignalNoise).*exp(-1i*2*pi*CarrierFrequency*t));
%Demodulation 신호 정규화
DemodulatedAMSignalNormNoise = lowpass(DemodulatedAMSignalNoise./(max(abs(DemodulatedAMSignalNoise(50000:500000,1:2)))),5000,SamplingFrequency); 
 
% Audio 출력
audiowrite('receviedAmSoundFileNoise.wav',DemodulatedAMSignalNormNoise,SamplingFrequency);


%modulation
ModulatedFMSignalNoise = awgn(ModulatedFMSignal,40);

% demodulation (Hilbert 변환을 이용한 Demodulation)
yqNoise = hilbert(ModulatedFMSignalNoise).*exp(-1i*2*pi*CarrierFrequency*t);
DemodulatedFMSignalNoise = lowpass((1/(2*pi*FrequencyDeviation))*[zeros(1,size(yqNoise,2)); diff(unwrap(angle(yqNoise)))*SamplingFrequency],5000,SamplingFrequency);

%%신호 정규화
DemodulatedFMSignalNormNoise = DemodulatedFMSignalNoise./(max(abs(DemodulatedFMSignalNoise(50000:500000,1:2)))); 
%Audio out
audiowrite('receviedFmSoundFileNoise.wav',DemodulatedFMSignalNormNoise,SamplingFrequency);




%% plot
% Plot the orginal and received signal/sound
f1=figure('Name','Code based Time Domain Plots');
OriginalSignal = subplot(7,1,1);
plot(OriginalSignal,OriginalAudio);
title('Original Voice Signal')
xlabel('Time');
ylabel('Amplitude'); 

% spctrum of DSB modulated signal
fftDSB = fft(ModulatedDSBSignal);         % Compute DFT of AM
MagDSB = abs(fftDSB);                               % Magnitude
spectrumfDSB = (-(length(fftDSB)/2):length(fftDSB)/2-1)*SamplingFrequency/length(fftDSB);        % Frequency vector
subplot(7,1,3)
plot(spectrumfDSB,MagDSB)
title('DSB Magnitude')
% Received demodulated am signal signal
DemodulatedDSB = subplot(7,1,2);
plot(DemodulatedDSB, DemodulatedDSBSignalNorm);
title('DSB Demodulated Signal');
xlabel('Time');
ylabel('Amplitude');

% spctrum of AM modulated signal
fftAM = fft(ModulatedAMSignal);         % Compute DFT of AM
MagAM = abs(fftAM);                               % Magnitude
SpectrumfAM = (-(length(fftAM)/2):length(fftAM)/2-1)*SamplingFrequency/length(fftAM);        % Frequency vector
subplot(7,1,5)
plot(SpectrumfAM,MagAM)
ylim([0 2500]);
title('AM Magnitude')

% Received demodulated am signal signal
DemodulatedAM = subplot(7,1,4);
plot(DemodulatedAM, DemodulatedAMSignalNorm);
title('AM Demodulated Signal');
xlabel('Time');
ylabel('Amplitude');

% spctrum of FM modulated signal
fftFM = fft(ModulatedFMSignal);         % Compute DFT of FM
MagFM = abs(fftFM);                               % Magnitude
spectrumfFM = (-(length(fftFM)/2):length(fftFM)/2-1)*SamplingFrequency/length(fftFM);        % Frequency vector
subplot(7,1,7)
plot(spectrumfFM,MagFM)
ylim([0 2500]);
title('FM Magnitude')

% FM demodulated signal
DemodulatedFM = subplot(7,1,6);
plot(DemodulatedFM, DemodulatedFMSignalNorm);
ylim([-1 1]);
title('FM Demodulated Signal');
xlabel('Time');
ylabel('Amplitude');


%% Load audio file
[OriginalAudio_AM,Fs_AM] = audioread('AM_demodulated.wav'); % AM
[OriginalAudio_narrow_FM,Fs_narrow_FM] = audioread('narrow_FM_demodulated.wav'); % Narrowband FM
[OriginalAudio_wide_FM,Fs_wide_FM] = audioread('wide_FM_demodulated.wav'); % Wideband FM
[OriginalAudio_AM_mod,Fs_AM_mod] = audioread('AM_modulated.wav'); % AM
[OriginalAudio_narrow_FM_mod,Fs_narrow_FM_mod] = audioread('narrow_FM_modulated.wav'); % Narrowband FM
[OriginalAudio_wide_FM_mod,Fs_wide_FM_mod] = audioread('wide_FM_modulated.wav'); % Wideband FM
%AM 신호 정규화
OriginalAudio_AM_Norm = OriginalAudio_AM./(max(abs(OriginalAudio_AM))); 
OriginalAudio_AM_mod_Norm=OriginalAudio_AM_mod./(max(abs(OriginalAudio_AM_mod)));
%Narrow FM 신호 정규화
OriginalAudio_narrow_FM_Norm = OriginalAudio_narrow_FM./(max(abs(OriginalAudio_narrow_FM))); 
OriginalAudio_narrow_FM_mod_Norm = OriginalAudio_narrow_FM_mod./(max(abs(OriginalAudio_narrow_FM_mod))); 
%Wide FM 신호 정규화
OriginalAudio_wide_FM_mod_Norm=OriginalAudio_wide_FM_mod./(max(abs(OriginalAudio_wide_FM_mod)));
OriginalAudio_wide_FM=vertcat(zeros(6500,2),OriginalAudio_wide_FM(7000:end,:));
OriginalAudio_wide_FM_Norm = OriginalAudio_wide_FM./(max(abs(OriginalAudio_wide_FM))); 

%% simulink plot
% Plot the orginal and received signal/sound
f2=figure('Name','Simulink based Time Domain Plots');
OriginalSignal = subplot(7,1,1);
plot(OriginalSignal,OriginalAudio);
title('Original Voice Signal')
xlabel('Time');
ylabel('Amplitude'); 

% spctrum of AM modulated signal
fftAM_simulink = fft(OriginalAudio_AM_mod_Norm);         % Compute DFT of AM
MagAM_simulink = abs(fftAM_simulink);                               % Magnitude
spectrumfAM_simulink = (-(length(fftAM_simulink)/2):length(fftAM_simulink)/2-1)*SamplingFrequency/length(fftAM_simulink);        % Frequency vector
subplot(7,1,3)
plot(spectrumfAM_simulink,MagAM_simulink)
title('simulink AM Magnitude')
ylim([0 5000]);

% Received demodulated AM signal
AM_simulink = subplot(7,1,2);
plot(AM_simulink, OriginalAudio_AM_Norm);
title('simulink AM Demodulated Signal');
xlabel('Time');
ylabel('Amplitude');

% spctrum of simulink narrow FM modulated signal
fftFM_narrow_simulink = fft(OriginalAudio_narrow_FM_mod_Norm);         % Compute DFT of FM
MagFM_narrow_simulink = abs(fftFM_narrow_simulink);                               % Magnitude
SpectrumfFM_narrow = (-(length(fftFM_narrow_simulink)/2):length(fftFM_narrow_simulink)/2-1)*SamplingFrequency/length(fftFM_narrow_simulink);        % Frequency vector
subplot(7,1,5)
plot(SpectrumfFM_narrow,MagFM_narrow_simulink)
ylim([0 20000]);
title('simulink Narrow FM Magnitude')

% Received demodulated narrow FM signal
narrow_FM_simulink = subplot(7,1,4);
plot(narrow_FM_simulink, OriginalAudio_narrow_FM_Norm);
title('simulink Narrow FM Demodulated Signal');
xlabel('Time');
ylabel('Amplitude');

% spctrum of Wide modulated FM signal
fftFM_wide_simulink = fft(OriginalAudio_wide_FM_mod_Norm);         % Compute DFT of FM
MagFM_wide_simulink = abs(fftFM_wide_simulink);                               % Magnitude
spectrumfFM_wide = (-(length(fftFM_wide_simulink)/2):length(fftFM_wide_simulink)/2-1)*SamplingFrequency/length(fftFM_wide_simulink);        % Frequency vector
subplot(7,1,7)
plot(spectrumfFM_wide,MagFM_wide_simulink)
ylim([0 2500]);
title('simulink Wide FM Magnitude')

% simulink wide FM demodulated signal
wide_FM_simulink = subplot(7,1,6);
plot(wide_FM_simulink, OriginalAudio_wide_FM_Norm);
ylim([-1 1]);
title('simulink Wide FM Demodulated Signal');
xlabel('Time');
ylabel('Amplitude');