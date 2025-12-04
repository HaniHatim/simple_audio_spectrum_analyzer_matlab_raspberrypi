%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Audio Spectrum Analyzer with Toggle Button (Mic <-> System Audio)
% Sends FFT bands to Raspberry Pi via UDP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc; close all force;

%% ====================== CONFIGURATION ================================
SAMPLE_RATE  = 44100;      
FRAME_SIZE   = 2048;        
FFT_SIZE     = 2048;          
NUM_BANDS    = 64;

% Raspberry Pi network config
RASPI_IP   = "10.245.1.158"; 
RASPI_PORT = 5005;
udpSender  = udpport("IPV4");

%% ====================== ENUMERATE DEVICES ============================

tempReader = audioDeviceReader;
deviceList = getAudioDevices(tempReader);
release(tempReader);

disp(" ");
disp("=============== AVAILABLE AUDIO INPUT DEVICES ===============");

for i = 1:length(deviceList)
    fprintf("%2d. %s\n", i, deviceList{i});
end

disp("=============================================================");
disp(" ");

% Detect microphone
micIndex = find(contains(lower(deviceList), "microphone"), 1);

% Detect system audio (Stereo Mix or VB Cable)
systemIndex = find(contains(lower(deviceList), ["stereo mix", "cable output", "vb-audio"]), 1);

% Fallbacks
if isempty(micIndex), micIndex = 1; end
if isempty(systemIndex), systemIndex = micIndex; end

% Start in mic mode
currentMode = "mic";


%% ====================== FUNCTION: CREATE DEVICE READER ===============

function dr = createReader(mode, deviceList, micIndex, systemIndex, rate, frames)
    if mode == "mic"
        selected = deviceList{micIndex};
    else
        selected = deviceList{systemIndex};
    end

    fprintf("Switching to: %s\n", selected);

    dr = audioDeviceReader( ...
        "Device", selected, ...
        "SampleRate", rate, ...
        "SamplesPerFrame", frames);
end

% Initialize reader
deviceReader = createReader(currentMode, deviceList, micIndex, systemIndex, SAMPLE_RATE, FRAME_SIZE);


%% ====================== LOCAL VISUALIZATION SETUP ====================

hFig = figure('Name', 'Spectrum Analyzer (Toggle Input)', ...
              'NumberTitle', 'off', ...
              'Color', 'k', ...
              'Position', [200 200 900 500]); 

hAx = axes('Parent', hFig, ...
           'Color', 'k', 'XColor', 'w', 'YColor', 'w');

hBar = bar(hAx, 1:NUM_BANDS, zeros(1, NUM_BANDS), ...
           'FaceColor', [0, 0.8, 1], ...
           'EdgeColor', 'none');

title(hAx, sprintf("Sending to %s ... (Mic Mode)", RASPI_IP), "Color", "w");
xlabel(hAx, "Frequency Bands", "Color", "w");
ylim(hAx, [0, 1]); 
xlim(hAx, [0.5, NUM_BANDS + 0.5]);


%% ====================== CREATE TOGGLE BUTTON =========================

uicontrol('Style', 'pushbutton', ...
          'String', 'Switch to System Audio', ...
          'Tag', 'ToggleButton', ...          % UNIQUE TAG
          'FontSize', 12, ...
          'BackgroundColor', [0.2 0.2 0.2], ...
          'ForegroundColor', 'w', ...
          'Position', [20 20 220 40], ...
          'Callback', @toggleDevice);


%% ====================== CALLBACK: TOGGLE AUDIO SOURCE ================

function toggleDevice(~, ~)
    persistent readerPtr modePtr titlePtr btnPtr
    
    % Load variables from base workspace
    readerPtr = evalin('base', 'deviceReader');
    modePtr   = evalin('base', 'currentMode');
    titlePtr  = evalin('base', 'hAx');
    btnPtr    = findobj('Tag', 'ToggleButton');   % SAFE lookup

    % Release reader before switching
    release(readerPtr);

    % Switch mode
    if modePtr == "mic"
        modePtr = "system";
        btnPtr.String = "Switch to Microphone";
        titlePtr.Title.String = "Sending to Pi... (System Audio Mode)";
    else
        modePtr = "mic";
        btnPtr.String = "Switch to System Audio";
        titlePtr.Title.String = "Sending to Pi... (Mic Mode)";
    end

    % Create new device reader
    readerPtr = createReader(modePtr, ...
        evalin('base','deviceList'), ...
        evalin('base','micIndex'), ...
        evalin('base','systemIndex'), ...
        evalin('base','SAMPLE_RATE'), ...
        evalin('base','FRAME_SIZE'));

    % Save back to base
    assignin('base','deviceReader', readerPtr);
    assignin('base','currentMode', modePtr);
end


%% ====================== FREQUENCY BIN SETUP ==========================

freq_bins   = logspace(log10(20), log10(SAMPLE_RATE/2), NUM_BANDS+1);
fft_indices = round(freq_bins / (SAMPLE_RATE/FFT_SIZE));
fft_indices(fft_indices == 0) = 1;

disp("Stream running. Use the button to switch input mode.");


%% ====================== MAIN PROCESSING LOOP =========================

try
    while ishandle(hFig)

        % Always fetch latest reader after switching
        deviceReader = evalin('base', 'deviceReader');

        audioData = deviceReader();

        % --- FFT ---
        windowedData = audioData .* hann(FRAME_SIZE);
        fftData      = fft(windowedData, FFT_SIZE);

        P2 = abs(fftData/FFT_SIZE);
        P1 = P2(1:FFT_SIZE/2+1);
        P1(2:end-1) = 2 * P1(2:end-1);

        % --- BINNING ---
        binnedData = zeros(1, NUM_BANDS);
        for i = 1:NUM_BANDS
            binnedData(i) = mean(P1(fft_indices(i):fft_indices(i+1)));
        end

        % --- NORMALIZE ---
        normalizedData = binnedData * 50;
        normalizedData(normalizedData > 1) = 1;

        % --- UPDATE PLOT ---
        set(hBar, 'YData', normalizedData);
        drawnow limitrate;

        % --- SEND TO PI ---
        jsonData = jsonencode(round(normalizedData, 3));
        write(udpSender, jsonData, "string", RASPI_IP, RASPI_PORT);
    end

catch ME
    release(deviceReader);
    rethrow(ME);
end

release(deviceReader);
disp("Audio device released.");
