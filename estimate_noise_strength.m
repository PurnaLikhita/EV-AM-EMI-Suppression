function [noisePercent, label, noisePower] = estimate_noise_strength(received, expectedSignalPower)
%ESTIMATE_NOISE_STRENGTH Estimate interference power using calibrated signal power.
validateattributes(expectedSignalPower, {'numeric'}, {'scalar','positive','finite'});
noisePower = max(mean(received(:).^2) - expectedSignalPower, 0);
noisePercent = 100*noisePower/expectedSignalPower;
if noisePercent < 8
    label = 'Low';
elseif noisePercent < 15
    label = 'Medium';
elseif noisePercent < 25
    label = 'High';
else
    label = 'Very High';
end
end
