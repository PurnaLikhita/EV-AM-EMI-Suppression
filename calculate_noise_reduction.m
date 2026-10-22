function reductionPercent = calculate_noise_reduction(beforePower, afterPower)
%CALCULATE_NOISE_REDUCTION Fractional residual-noise reduction as percent.
validateattributes(beforePower, {'numeric'}, {'scalar','nonnegative','finite'});
validateattributes(afterPower, {'numeric'}, {'scalar','nonnegative','finite'});
reductionPercent = 100*(1 - afterPower/max(beforePower, eps));
end
