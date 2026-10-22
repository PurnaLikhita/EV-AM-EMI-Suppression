function [emiSource, info] = preprocess_emi(voltage, sampleRateHz, cutoffHz, passbandReferenceHz, numTaps)
%PREPROCESS_EMI Remove low-frequency content with a base-MATLAB FIR high-pass.
%   The FIR is built with a Hamming window, normalized to unity magnitude at
%   passbandReferenceHz, and applied causally. Startup samples are discarded
%   to remove the filter transient. No Signal Processing Toolbox is needed.

voltage = voltage(:);
validateattributes(voltage, {'numeric'}, {'vector','real','finite'});
validateattributes(sampleRateHz, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(cutoffHz, {'numeric'}, {'scalar','real','finite','positive','<',sampleRateHz/2});
validateattributes(passbandReferenceHz, {'numeric'}, ...
    {'scalar','real','finite','>',cutoffHz,'<',sampleRateHz/2});
validateattributes(numTaps, {'numeric'}, {'scalar','integer','positive','>=',3});
if mod(numTaps,2) == 0
    error('preprocess_emi:evenTapCount', 'numTaps must be odd for a symmetric FIR.');
end
if numel(voltage) <= numTaps-1
    error('preprocess_emi:recordTooShort', 'The record is too short for the selected FIR startup discard.');
end

halfOrder = (numTaps-1)/2;
n = -halfOrder:halfOrder;
normalizedCutoff = cutoffHz / sampleRateHz;
lowpass = zeros(size(n));
center = (n == 0);
lowpass(center) = 2 * normalizedCutoff;
nonzero = ~center;
lowpass(nonzero) = sin(2*pi*normalizedCutoff*n(nonzero)) ./ (pi*n(nonzero));

highpass = -lowpass;
highpass(center) = highpass(center) + 1;
window = 0.54 - 0.46*cos(2*pi*(0:numTaps-1)/(numTaps-1));
coefficients = highpass .* window;
response = sum(coefficients .* exp(-1i*2*pi*passbandReferenceHz/sampleRateHz*(0:numTaps-1)));
if ~isfinite(abs(response)) || abs(response) <= eps
    error('preprocess_emi:invalidResponse', 'Could not normalize the FIR at the requested reference frequency.');
end
coefficients = coefficients / abs(response);

filtered = filter(coefficients, 1, voltage);
discarded = numTaps-1;
emiSource = filtered(discarded+1:end);

info = struct();
info.cutoffHz = cutoffHz;
info.passbandReferenceHz = passbandReferenceHz;
info.numTaps = numTaps;
info.discardedStartupSamples = discarded;
info.coefficients = coefficients;
end
