function snrDb = calculate_snr(cleanSignal, observedSignal)
%CALCULATE_SNR Signal-to-error ratio in dB.
if numel(cleanSignal) ~= numel(observedSignal), error('calculate_snr:lengthMismatch', 'Signals must have equal length.'); end
signalPower = mean(cleanSignal(:).^2);
errorPower = mean((observedSignal(:)-cleanSignal(:)).^2);
snrDb = 10*log10(signalPower/max(errorPower, eps));
end
