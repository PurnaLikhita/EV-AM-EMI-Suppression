%% ========================================================================
%  POSTPROCESS_SIMULINK_RESULTS
%  ------------------------------------------------------------------------
%  Run this AFTER the Simulink model has finished running (it expects
%  `noisyAM_log` and `filtered_log` to exist in the base workspace,
%  produced by the model's "To Workspace" blocks -- see
%  README_SIMULINK.md, "Block 9: To Workspace blocks").
%
%  Reuses the EXACT SAME metric functions as the MATLAB-only pipeline
%  (calculate_snr.m, calculate_mse.m, calculate_noise_reduction.m) so
%  Simulink results are directly comparable to main.m's results table.
%% ========================================================================

if ~exist('s_am', 'var') || ~exist('noisyAM_log', 'var') || ~exist('filtered_log', 'var')
    error(['Missing variables. Run simulink_init.m, then run the Simulink ' ...
           'model (which must log noisyAM_log and filtered_log via "To ' ...
           'Workspace" blocks), THEN run this script.']);
end

addpath('..');

% "To Workspace" blocks with Save format = Array produce an N-by-1
% vector directly; with the default "Timeseries" format, extract .Data:
if isa(noisyAM_log, 'timeseries')
    noisyAM_sim = noisyAM_log.Data(:);
else
    noisyAM_sim = noisyAM_log(:);
end
if isa(filtered_log, 'timeseries')
    filtered_sim = filtered_log.Data(:);
else
    filtered_sim = filtered_log(:);
end

N = min([length(s_am), length(noisyAM_sim), length(filtered_sim)]);
s_am_c        = s_am(1:N);
noisyAM_c     = noisyAM_sim(1:N);
filtered_c    = filtered_sim(1:N);

snrBefore = calculate_snr(s_am_c, noisyAM_c);
snrAfter  = calculate_snr(s_am_c, filtered_c);
mseBefore = calculate_mse(s_am_c, noisyAM_c);
mseAfter  = calculate_mse(s_am_c, filtered_c);
noisePowerBefore = mean((noisyAM_c - s_am_c).^2);
noisePowerAfter  = mean((filtered_c - s_am_c).^2);
reductionPct = calculate_noise_reduction(noisePowerBefore, noisePowerAfter);

fprintf('=== Simulink run results (level = %d%%) ===\n', emiLevelPercent);
fprintf('SNR before : %.2f dB\n', snrBefore);
fprintf('SNR after  : %.2f dB (improvement %.2f dB)\n', snrAfter, snrAfter-snrBefore);
fprintf('MSE before : %.4g\n', mseBefore);
fprintf('MSE after  : %.4g\n', mseAfter);
fprintf('Noise reduction: %.1f%%\n', reductionPct);
