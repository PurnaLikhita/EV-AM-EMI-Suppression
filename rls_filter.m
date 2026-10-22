function [y, e, w, mseCurve] = rls_filter(x_ref, d, order, lambda, delta)
% RLS_FILTER  Recursive Least Squares -- same ANC architecture as
% lms_filter.m / nlms_filter.m, but tracks the full inverse
% autocorrelation matrix for much faster convergence at the cost of
% O(order^2) work per sample (vs O(order) for LMS/NLMS).
%
%   Pi(n)  = P(n-1) x(n)
%   k(n)   = Pi(n) / (lambda + x(n)' Pi(n))
%   e(n)   = d(n) - w(n-1)' x(n)
%   w(n)   = w(n-1) + k(n) e(n)
%   P(n)   = (P(n-1) - k(n) x(n)' P(n-1)) / lambda
%
% Inputs
%   x_ref, d, order  - as in lms_filter.m
%   lambda           - forgetting factor, 0 << lambda <= 1. lambda=1 is
%                       a plain (non-forgetting) RLS; lambda<1 lets the
%                       filter track a slowly time-varying environment
%                       (relevant here: EMI power/spectrum changes as
%                       the simulated "driving state" changes).
%   delta            - initial regularisation for P = (1/delta)*I.
%                       Larger delta -> more cautious/slower start.
%
% Outputs: identical convention to lms_filter.m.

    x_ref = x_ref(:);
    d = d(:);
    validateattributes(x_ref, {'numeric'}, {'vector','real','finite'});
    validateattributes(d, {'numeric'}, {'vector','real','finite'});
    validateattributes(order, {'numeric'}, {'scalar','integer','positive','finite'});
    validateattributes(lambda, {'numeric'}, {'scalar','real','finite','positive','<=',1});
    validateattributes(delta, {'numeric'}, {'scalar','real','finite','positive'});

    if numel(x_ref) ~= numel(d)
        error('rls_filter:lengthMismatch', 'x_ref and d must be the same length.');
    end

    N = numel(x_ref);
    w = zeros(order,1);
    P = (1/delta) * eye(order);
    y = zeros(N,1);
    e = zeros(N,1);
    mseCurve = zeros(N,1);
    xbuf = zeros(order,1);

    for n = 1:N
        xbuf = [x_ref(n); xbuf(1:end-1)];
        % Keep round-off from making the covariance matrix asymmetric.
        P = 0.5 * (P + P.');
        piVec = P * xbuf;
        denominator = lambda + xbuf' * piVec;
        if isnan(denominator) || isinf(denominator) || denominator <= 0
            error('rls_filter:invalidCovariance', ...
                'RLS covariance became invalid at sample %d.', n);
        end
        k = piVec / denominator;
        y(n) = w' * xbuf;
        e(n) = d(n) - y(n);
        w = w + k * e(n);
        P = (P - k * (xbuf' * P)) / lambda;
        P = 0.5 * (P + P.');
        mseCurve(n) = e(n)^2;

        if any(isnan(w)) || any(isinf(w)) || any(isnan(P(:))) || any(isinf(P(:))) || ...
                isnan(e(n)) || isinf(e(n))
            error('rls_filter:diverged', ...
                'RLS diverged at sample %d (non-finite state).', n);
        end
    end
end
