%% RUN_MEASURED_DEMO Offline AM cancellation using the measured charger source
% This is a measured-source simulation, not a live EV receiver experiment.
% The recorded CSV is charger voltage; an assumed coupling FIR creates the
% simulated interference/reference relationship used by the ANC filters.

clear; clc; close all;

%% Dataset and signal settings
Fs = 1e6;                         % verified dataset sampling rate
selectedDurationSeconds = 0.2;   % first 200,000 samples for a quick run
maxSamples = round(selectedDurationSeconds * Fs);
datasetPath = fullfile('data','EVCharger_Lab_Data_V1.CSV');
[recordedVoltage, datasetInfo] = load_emi_dataset(datasetPath, Fs, maxSamples);

% Keep the 27 kHz and 54 kHz charger components representable. This carrier
% is a scaled simulation carrier, not an AM broadcast carrier measurement.
fc = 100e3;
modIndex = 0.7;
Ac = 1;
filterOrder = 32;
targetInputSNRdB = 5;
muLms = 0.0015;
lambdaRls = 1.0;
deltaRls = 0.01;
muNlmsCandidates = [0.05 0.10 0.20 0.40];
epsNlms = 1e-6;

%% Preprocess and align signals
[emiReferenceRaw, preprocessingInfo] = preprocess_emi( ...
    recordedVoltage, Fs, 20e3, 27e3, 201);
N = numel(emiReferenceRaw);
[cleanAM, ~, ~, ~, ~] = generate_am_signal(Fs, N/Fs, fc, modIndex, Ac);
cleanAM = cleanAM(:);

% Chronological 45/20/25 split with 5% unused guard gaps between blocks.
nTrain = floor(0.45*N);
nValidation = floor(0.20*N);
nTest = floor(0.25*N);
nGuard = floor(0.05*N);
trainIdx = 1:nTrain;
validationStart = nTrain+nGuard+1;
validationIdx = validationStart:validationStart+nValidation-1;
testStart = validationIdx(end)+nGuard+1;
testIdx = testStart:testStart+nTest-1;
if isempty(testIdx) || testIdx(end) > N
    error('run_measured_demo:invalidSplit', 'The selected record is too short for the configured split.');
end

referenceRms = sqrt(mean(emiReferenceRaw(trainIdx).^2));
if ~isfinite(referenceRms) || referenceRms <= eps
    error('run_measured_demo:invalidReference', 'Preprocessed training reference has near-zero power.');
end
reference = emiReferenceRaw / referenceRms;

% The measured source is passed through an assumed coupling path. Gain is
% calibrated only on training samples to target the requested input SNR.
couplingPath = [0.72 -0.36 0.18 0.08];
coupledSource = filter(couplingPath, 1, reference);
targetNoisePower = mean(cleanAM(trainIdx).^2) / 10^(targetInputSNRdB/10);
coupledTrainPower = mean(coupledSource(trainIdx).^2);
if ~isfinite(coupledTrainPower) || coupledTrainPower <= eps
    error('run_measured_demo:invalidCoupling', 'Coupled training source has near-zero power.');
end
sourceGain = sqrt(targetNoisePower/coupledTrainPower);
interference = sourceGain * coupledSource;
noisyAM = cleanAM + interference;

%% Tune NLMS on validation data only
validationMSE = zeros(numel(muNlmsCandidates),1);
for k = 1:numel(muNlmsCandidates)
    [~, validationOutput] = nlms_filter(reference(validationIdx), noisyAM(validationIdx), ...
        filterOrder, muNlmsCandidates(k), epsNlms);
    validationMSE(k) = calculate_mse(cleanAM(validationIdx), validationOutput);
end
[bestValidationMSE, bestIdx] = min(validationMSE);
muNlms = muNlmsCandidates(bestIdx);

%% Evaluate each filter on the held-out test block
cleanTest = cleanAM(testIdx);
noisyTest = noisyAM(testIdx);
referenceTest = reference(testIdx);
inputSNRdB = calculate_snr(cleanTest, noisyTest);
mseBefore = calculate_mse(cleanTest, noisyTest);

timer = tic;
[~, outputLms] = lms_filter(referenceTest, noisyTest, filterOrder, muLms);
timeLms = toc(timer);
timer = tic;
[~, outputNlms] = nlms_filter(referenceTest, noisyTest, filterOrder, muNlms, epsNlms);
timeNlms = toc(timer);
timer = tic;
[~, outputRls] = rls_filter(referenceTest, noisyTest, filterOrder, lambdaRls, deltaRls);
timeRls = toc(timer);

outputs = {outputLms(:), outputNlms(:), outputRls(:)};
algorithms = {'LMS';'NLMS';'RLS'};
parameters = {sprintf('mu=%.5g',muLms); ...
    sprintf('mu=%.5g (validation tuned)',muNlms); ...
    sprintf('lambda=%.5g, delta=%.5g',lambdaRls,deltaRls)};
executionTime = [timeLms;timeNlms;timeRls];
outputSNR = zeros(3,1);
mseAfter = zeros(3,1);
noiseReductionPct = zeros(3,1);
for k = 1:3
    outputSNR(k) = calculate_snr(cleanTest, outputs{k});
    mseAfter(k) = calculate_mse(cleanTest, outputs{k});
    noiseReductionPct(k) = calculate_noise_reduction(mseBefore, mseAfter(k));
end

resultsTable = table(algorithms, repmat({'measured-source simulation'},3,1), ...
    repmat({datasetInfo.filePath},3,1), repmat({datasetInfo.channel},3,1), ...
    repmat(Fs,3,1), repmat(targetInputSNRdB,3,1), repmat(inputSNRdB,3,1), ...
    outputSNR, outputSNR-inputSNRdB, repmat(mseBefore,3,1), mseAfter, ...
    noiseReductionPct, executionTime, repmat(filterOrder,3,1), parameters, ...
    [NaN;bestValidationMSE;NaN], ...
    'VariableNames', {'Algorithm','DataMode','DatasetFile','Channel','SamplingRate_Hz', ...
    'Target_Input_SNR_dB','Input_SNR_dB','Output_SNR_dB','SNR_Improvement_dB', ...
    'MSE_Before','MSE_After','NoiseReduction_Pct','ExecutionTime_s','FilterLength', ...
    'Parameter','Validation_MSE'});

%% Save outputs and a reproducibility log
outDir = fullfile('results','measured_source_simulation');
if ~exist(outDir,'dir')
    mkdir(outDir);
end
metricsPath = fullfile(outDir,'metrics.csv');
writetable(resultsTable, metricsPath);

figureHandle = figure('Name','Measured-source simulation','Color','w');
layout = tiledlayout(2,1);
title(layout,'Measured charger source with simulated AM/reference coupling');
timeTest = (0:numel(cleanTest)-1)'/Fs;
smoothWindow = max(1,round(0.001*Fs));
nexttile;
hold on;
colors = lines(3);
for k = 1:3
    targetErrorPower = (outputs{k}-cleanTest).^2;
    plot(timeTest,10*log10(movmean(targetErrorPower,smoothWindow)+eps), ...
        'Color',colors(k,:));
end
xlabel('Time in held-out test block (s)');
ylabel('Error against clean AM (dB)');
title('Moving target-error power');
legend(algorithms,'Location','best');
grid on;

nexttile;
showN = min(2500,numel(cleanTest));
hold on;
plot(timeTest(1:showN)*1e3,cleanTest(1:showN),'k','LineWidth',1);
plot(timeTest(1:showN)*1e3,noisyTest(1:showN),'Color',[0.75 0.25 0.2]);
plot(timeTest(1:showN)*1e3,outputs{2}(1:showN),'Color',[0.1 0.45 0.8]);
xlabel('Time (ms)');
ylabel('Amplitude (simulation units)');
title(sprintf('Test waveform preview; best validation NLMS candidate = %.3g',muNlms));
legend({'Clean AM','Noisy input','NLMS output'},'Location','best');
grid on;
saveas(figureHandle,fullfile(outDir,'measured_source_comparison.png'));

logPath = fullfile(outDir,'experiment_log.txt');
fid = fopen(logPath,'w');
if fid < 0
    error('run_measured_demo:logOpenFailed','Could not create experiment log: %s',logPath);
end
fprintf(fid,'Mode: measured-source offline simulation\n');
fprintf(fid,'Dataset: %s\n',datasetInfo.filePath);
fprintf(fid,'Channel: %s\n',datasetInfo.channel);
fprintf(fid,'Units: %s\n',datasetInfo.units);
fprintf(fid,'Sampling rate (Hz): %.0f\n',Fs);
fprintf(fid,'CSV samples available: %d\n',datasetInfo.sourceSampleCount);
fprintf(fid,'CSV samples selected: %d (%.6f s)\n',datasetInfo.selectedSampleCount,datasetInfo.selectedDurationSeconds);
fprintf(fid,'Preprocessed samples used: %d\n',N);
fprintf(fid,'High-pass cutoff / normalization (Hz): %.0f / %.0f\n', ...
    preprocessingInfo.cutoffHz,preprocessingInfo.passbandReferenceHz);
fprintf(fid,'FIR taps / startup samples discarded: %d / %d\n', ...
    preprocessingInfo.numTaps,preprocessingInfo.discardedStartupSamples);
fprintf(fid,'AM carrier (scaled simulation Hz): %.0f\n',fc);
fprintf(fid,'Target training input SNR (dB): %.2f\n',targetInputSNRdB);
fprintf(fid,'Observed held-out input SNR (dB): %.4f\n',inputSNRdB);
fprintf(fid,'Split fractions train/validation/test/each guard: 0.45 / 0.20 / 0.25 / 0.05\n');
fprintf(fid,'NLMS candidates: %s\n',mat2str(muNlmsCandidates));
fprintf(fid,'Selected NLMS step size: %.6g\n',muNlms);
fprintf(fid,'Synthetic coupling path: %s\n',mat2str(couplingPath));
fprintf(fid,'Metrics CSV: %s\n',metricsPath);
fclose(fid);

save(fullfile(outDir,'run_data.mat'),'resultsTable','datasetInfo','preprocessingInfo', ...
    'Fs','fc','targetInputSNRdB','muLms','muNlms','lambdaRls','deltaRls', ...
    'validationMSE','outputs','cleanTest','noisyTest','referenceTest','testIdx');
disp(resultsTable);
fprintf('\nSaved measured-source simulation outputs to: %s\n',outDir);
fprintf('Note: measured charger voltage is used as the EMI source; receiver coupling and the AM target remain simulated.\n');
