function noisySignal = add_emi(cleanSignal, emiSignal)
%ADD_EMI Add EMI to a clean received AM signal.
if ~isequal(size(cleanSignal), size(emiSignal))
    error('add_emi:sizeMismatch', 'cleanSignal and emiSignal must have identical sizes.');
end
noisySignal = cleanSignal + emiSignal;
end
