%% ========================================================================
%  COMPARE_ALGORITHMS  (Part 11 / Sec. 22 -- OPTIONAL EXTENSION)
%  ------------------------------------------------------------------------
%  Compares LMS, NLMS, and RLS on the SAME AM+EMI signals used by main.m,
%  across all four required EMI levels. This does NOT replace or modify
%  the mandatory LMS-only pipeline in main.m / run_noise_conditions.m --
%  it is a separate, additional script, as required (Sec. 22: "NLMS/RLS
%  should not replace the required LMS system").
%
%  Run with:  compare_algorithms
%
%  These are fixed demonstration settings for the synthetic model. The
%  current NLMS setting can underperform; do not claim NLMS is inferior
%  without tuning it on validation data. run_measured_demo.m performs
%  validation-only NLMS selection for the measured-source simulation.
%% ========================================================================

clear; clc; close all;
if ~exist('results','dir'); mkdir('results'); end

%% --- same simulation parameters as main.m ---
Fs       = 100000;
Duration = 2;
fc       = 10000;
modIndex = 0.7;
Ac       = 1;
filterOrder = 32;

mu_lms    = 0.0015;   % same as main.m
mu_nlms   = 0.01;     % fixed synthetic-demo setting; not validation tuned
eps_nlms  = 1e-6;
% The coupling path in this finite simulation is fixed. A forgetting
% factor of 0.999 caused the covariance to grow in poorly excited tap
% directions over 200,000 samples, eventually producing NaN/Inf. Use
% non-forgetting RLS for this fixed-path comparison.
lambda_rls = 1.0;
delta_rls  = 0.01;

levels = [5 10 20 30];
algNames = {'LMS','NLMS','RLS'};

[s_am, ~, ~, t, sigPower] = generate_am_signal(Fs, Duration, fc, modIndex, Ac);

nLevels = length(levels);
nAlgs   = length(algNames);

Algorithm          = strings(nLevels*nAlgs,1);
EMI_Level           = zeros(nLevels*nAlgs,1);
SNR_Improvement_dB   = zeros(nLevels*nAlgs,1);
MSE_After              = zeros(nLevels*nAlgs,1);
NoiseReduction_Pct       = zeros(nLevels*nAlgs,1);
SettlingTime_Samples      = zeros(nLevels*nAlgs,1);

row = 0;
comparisonFig = figure('Name','Convergence Comparison (all levels)','Color','w');
tiledLayoutHandle = tiledlayout(2,2);

for iLvl = 1:nLevels
    lvl = levels(iLvl);
    [emi_t, ~, refEmi_t] = generate_emi(Fs, Duration, lvl, sigPower);
    noisyAM = add_emi(s_am, emi_t);
    snrBefore = calculate_snr(s_am, noisyAM);

    [~, e_lms]  = lms_filter(refEmi_t, noisyAM, filterOrder, mu_lms);
    [~, e_nlms] = nlms_filter(refEmi_t, noisyAM, filterOrder, mu_nlms, eps_nlms);
    [~, e_rls]  = rls_filter(refEmi_t, noisyAM, filterOrder, lambda_rls, delta_rls);

    es  = {e_lms, e_nlms, e_rls};
    % Measure suppression error against the known clean AM target. The
    % adaptive-filter residual itself contains the wanted AM signal.
    targetErrorPower = cellfun(@(e) (e - s_am).^2, es, 'UniformOutput', false);
    smoothWindow = 200;

    nexttile;
    hold on;
    for a = 1:nAlgs
        smoothError = movmean(targetErrorPower{a}, smoothWindow);
        plot(t, 10*log10(smoothError + eps));
    end
    xlabel('Time (s)'); ylabel('Error to clean AM (dB)');
    title(sprintf('%d%% EMI level', lvl));
    legend(algNames,'TextColor','k','Color','w');
    set(gca,'Color','w','XColor','k','YColor','k');
    grid on;

    for a = 1:nAlgs
        row = row + 1;
        e = es{a};
        errorPower = targetErrorPower{a};

        snrAfter = calculate_snr(s_am, e);
        mseAfter = calculate_mse(s_am, e);
        noisePowerBefore = mean((noisyAM - s_am).^2);
        noisePowerAfter  = mean((e - s_am).^2);
        reductionPct = calculate_noise_reduction(noisePowerBefore, noisePowerAfter);

        % Settling time: first 200-sample span that stays within 1 dB of
        % the final 10% mean target-error power.
        smoothed = movmean(errorPower, smoothWindow);
        steadyStart = max(1, floor(0.9*numel(smoothed)));
        steadyState = mean(smoothed(steadyStart:end));
        threshold = steadyState * 10^(1/10);
        forwardMax = movmax(smoothed, [0 smoothWindow-1]);
        idxSettled = find(forwardMax <= threshold, 1, 'first');
        if isempty(idxSettled)
            idxSettled = NaN;
        end

        Algorithm(row)             = algNames{a};
        EMI_Level(row)              = lvl;
        SNR_Improvement_dB(row)      = snrAfter - snrBefore;
        MSE_After(row)                = mseAfter;
        NoiseReduction_Pct(row)         = reductionPct;
        SettlingTime_Samples(row)        = idxSettled;
    end
end

saveas(comparisonFig, fullfile('results','algorithm_comparison_convergence.png'));

resultsTable = table(Algorithm, EMI_Level, SNR_Improvement_dB, MSE_After, ...
    NoiseReduction_Pct, SettlingTime_Samples);

disp(' ');
disp('=== LMS vs NLMS vs RLS COMPARISON (actual simulation results) ===');
disp(resultsTable);

writetable(resultsTable, fullfile('results','algorithm_comparison_table.csv'));
save(fullfile('results','algorithm_comparison.mat'), 'resultsTable');

%% --- computational complexity note (qualitative, per Sec. 22 table) ---
disp(' ');
disp('Computational complexity per sample (order = filter length):');
disp('  LMS  : O(order)    -- 2 multiply-adds per tap');
disp('  NLMS : O(order)    -- same as LMS plus one power/normalisation term');
disp('  RLS  : O(order^2)  -- full matrix-vector products with P (order x order)');
fprintf('For order=%d: LMS/NLMS ~%d ops/sample, RLS ~%d ops/sample (order of magnitude)\n', ...
    filterOrder, filterOrder, filterOrder^2);
