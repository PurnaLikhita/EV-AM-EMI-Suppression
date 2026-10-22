function mse = calculate_mse(reference, estimate)
%CALCULATE_MSE Mean squared error.
if numel(reference) ~= numel(estimate), error('calculate_mse:lengthMismatch', 'Signals must have equal length.'); end
mse = mean((reference(:)-estimate(:)).^2);
end
