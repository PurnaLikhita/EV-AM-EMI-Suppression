function [y, e, w, mseCurve] = nlms_filter(x_ref, d, order, mu, epsVal)
% NLMS_FILTER  Normalised LMS -- same ANC architecture as lms_filter.m,
% but the step size is scaled by the instantaneous input power at each
% sample, giving faster and more robust convergence for signals whose
% power varies over time (relevant here since EMI power ramps up during
% the "acceleration" phase of the driving-state envelope).
%
%   e(n)       = d(n) - y(n)
%   w(n+1)     = w(n) + (mu / (||x(n)||^2 + eps)) * e(n) * x(n)
%
% Inputs / outputs: identical convention to lms_filter.m.
%
% NOTE: with 0 < mu < 2 NLMS is unconditionally stable in a strict
% textbook sense, but -- as with lms_filter.m -- a large mu still trades
% steady-state accuracy for speed. mu ~ 0.01 was found empirically to
% give the best steady-state SNR for this project's EMI model (order=32);
% see compare_algorithms.m.

    if length(x_ref) ~= length(d)
        error('nlms_filter:lengthMismatch', 'x_ref and d must be the same length.');
    end
    if mu <= 0 || mu >= 2
        error('nlms_filter:invalidStepSize', 'mu must satisfy 0 < mu < 2 (got %.4f).', mu);
    end

    N = length(x_ref);
    w = zeros(order,1);
    y = zeros(N,1);
    e = zeros(N,1);
    mseCurve = zeros(N,1);
    xbuf = zeros(order,1);

    for n = 1:N
        xbuf = [x_ref(n); xbuf(1:end-1)];
        y(n) = w' * xbuf;
        e(n) = d(n) - y(n);
        normFactor = (xbuf' * xbuf) + epsVal;
        w = w + (mu / normFactor) * e(n) * xbuf;
        mseCurve(n) = e(n)^2;
    end

    if any(isnan(e)) || any(isinf(e))
        error('nlms_filter:diverged', 'NLMS diverged (NaN/Inf in output). Reduce mu.');
    end
end
