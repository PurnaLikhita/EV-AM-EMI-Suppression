function [y, e, w, mseCurve] = lms_filter(x_ref, d, order, mu)
%LMS_FILTER FIR least-mean-squares adaptive noise canceller.
x_ref = x_ref(:); d = d(:);
if numel(x_ref) ~= numel(d), error('lms_filter:lengthMismatch', 'Inputs must have equal length.'); end
validateattributes(order, {'numeric'}, {'scalar','integer','positive'});
validateattributes(mu, {'numeric'}, {'scalar','positive','finite'});
N = numel(d); w = zeros(order,1); y = zeros(N,1); e = zeros(N,1); mseCurve = zeros(N,1); xbuf = zeros(order,1);
for n = 1:N
    xbuf = [x_ref(n); xbuf(1:end-1)];
    y(n) = w.'*xbuf;
    e(n) = d(n)-y(n);
    w = w + mu*e(n)*xbuf;
    mseCurve(n) = e(n)^2;
end
if any(~isfinite(e)), error('lms_filter:diverged', 'Filter diverged; reduce mu.'); end
end
