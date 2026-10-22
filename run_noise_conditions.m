function [resultsTable, runs] = run_noise_conditions(Fs, duration, fc, modIndex, Ac, filterOrder, muLms, levels)
%RUN_NOISE_CONDITIONS Execute the mandatory LMS pipeline at each EMI level.
[s_am, m_t, carrier, t, signalPower] = generate_am_signal(Fs, duration, fc, modIndex, Ac);
n = numel(levels);
EMI_Level_Percent = zeros(n,1); Estimated_Noise_Percent = zeros(n,1);
SNR_Before_dB = zeros(n,1); SNR_After_dB = zeros(n,1);
MSE_Before = zeros(n,1); MSE_After = zeros(n,1); Noise_Reduction_Percent = zeros(n,1);
runs = repmat(struct('level',0,'t',[],'clean',[],'message',[],'carrier',[], ...
    'emi',[],'reference',[],'noisy',[],'estimated',0,'label','','filterOutput',[], ...
    'filtered',[],'weights',[],'mseCurve',[]), n, 1);
for k = 1:n
    [emi, ~, reference] = generate_emi(Fs, duration, levels(k), signalPower);
    noisy = add_emi(s_am, emi);
    [estimated, label] = estimate_noise_strength(noisy, signalPower);
    [filterOutput, filtered, weights, mseCurve] = lms_filter(reference, noisy, filterOrder, muLms);
    beforeNoise = mean((noisy-s_am).^2); afterNoise = mean((filtered-s_am).^2);
    EMI_Level_Percent(k) = levels(k); Estimated_Noise_Percent(k) = estimated;
    SNR_Before_dB(k) = calculate_snr(s_am, noisy); SNR_After_dB(k) = calculate_snr(s_am, filtered);
    MSE_Before(k) = calculate_mse(s_am, noisy); MSE_After(k) = calculate_mse(s_am, filtered);
    Noise_Reduction_Percent(k) = calculate_noise_reduction(beforeNoise, afterNoise);
    runs(k) = struct('level',levels(k),'t',t,'clean',s_am,'message',m_t,'carrier',carrier, ...
        'emi',emi,'reference',reference,'noisy',noisy,'estimated',estimated,'label',label, ...
        'filterOutput',filterOutput,'filtered',filtered,'weights',weights,'mseCurve',mseCurve);
end
resultsTable = table(EMI_Level_Percent, Estimated_Noise_Percent, SNR_Before_dB, SNR_After_dB, ...
    MSE_Before, MSE_After, Noise_Reduction_Percent);
end
