function [f, magnitudeDb] = calculate_fft(x, Fs)
%CALCULATE_FFT Single-sided, amplitude-normalised magnitude spectrum.
x = x(:); N = numel(x); X = fft(x);
nHalf = floor(N/2)+1;
magnitude = abs(X(1:nHalf))/N;
if nHalf > 2, magnitude(2:end-1) = 2*magnitude(2:end-1); end
f = (0:nHalf-1).'*Fs/N;
magnitudeDb = 20*log10(magnitude + eps);
end
