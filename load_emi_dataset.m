function [samples, metadata] = load_emi_dataset(filePath, sampleRateHz, maxSamples)
%LOAD_EMI_DATASET Read the project's headerless, single-column charger CSV.
%   [SAMPLES, METADATA] = LOAD_EMI_DATASET(FILEPATH, SAMPLERATEHZ, MAXSAMPLES)
%   validates the numeric column and optionally returns only the first
%   MAXSAMPLES. The dataset's sample rate is supplied by its information
%   sheet; it is not inferred from the CSV values.

if nargin < 1 || isempty(filePath)
    filePath = fullfile('data','EVCharger_Lab_Data_V1.CSV');
end
if nargin < 2 || isempty(sampleRateHz)
    sampleRateHz = 1e6;
end
if nargin < 3 || isempty(maxSamples)
    maxSamples = Inf;
end

validateattributes(sampleRateHz, {'numeric'}, {'scalar','real','finite','positive'});
if ~(isnumeric(maxSamples) && isscalar(maxSamples) && ...
        (isinf(maxSamples) || (isfinite(maxSamples) && maxSamples > 0 && fix(maxSamples) == maxSamples)))
    error('load_emi_dataset:invalidLimit', 'maxSamples must be a positive integer or Inf.');
end
if ~isfile(filePath)
    error('load_emi_dataset:fileNotFound', ...
        'Dataset not found: %s. Put EVCharger_Lab_Data_V1.CSV in the project data folder.', filePath);
end

try
    raw = readmatrix(filePath, 'FileType','text');
catch cause
    error('load_emi_dataset:readFailed', ...
        'Could not read the CSV file %s: %s', filePath, cause.message);
end
if isempty(raw) || ~isnumeric(raw) || size(raw,2) ~= 1
    error('load_emi_dataset:unexpectedShape', ...
        'Expected one headerless numeric column; found a %d-by-%d array.', size(raw,1), size(raw,2));
end
if any(~isfinite(raw(:,1)))
    error('load_emi_dataset:nonFiniteData', 'CSV contains blank, NaN, or Inf samples.');
end

samples = raw(:,1);
sourceSampleCount = numel(samples);
if isfinite(maxSamples)
    samples = samples(1:min(numel(samples),maxSamples));
end

metadata = struct();
metadata.filePath = char(filePath);
metadata.channel = 'Column 1: single-phase voltage (V)';
metadata.sampleRateHz = sampleRateHz;
metadata.sourceSampleCount = sourceSampleCount;
metadata.selectedSampleCount = numel(samples);
metadata.selectedDurationSeconds = numel(samples) / sampleRateHz;
metadata.units = 'V';
end
