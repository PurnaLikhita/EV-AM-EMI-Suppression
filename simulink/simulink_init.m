%% ========================================================================
%  SIMULINK_INIT
%  ------------------------------------------------------------------------
%  Run this BEFORE opening/running the Simulink model. It builds every
%  workspace variable the model's "From Workspace" blocks and MATLAB
%  Function block parameters need, reusing the exact same Stage 1-4
%  functions as the MATLAB pipeline (main.m) -- so the Simulink model is
%  guaranteed to see the identical AM signal / EMI / reference tap /
%  noise-strength estimate as your MATLAB results, not a re-derived
%  approximation.
%
%  See simulink/README_SIMULINK.md for exact block-by-block wiring
%  instructions that consume these variables.
%% ========================================================================

clear; clc;
addpath('..');   % so generate_am_signal.m etc. (one level up) are found

%% --- parameters: identical to main.m ---
Fs       = 100000;
Duration = 2;
fc       = 10000;
modIndex = 0.7;
Ac       = 1;
filterOrder = 32;
mu_lms      = 0.0015;

emiLevelPercent = 20;   % pick ONE level to drive through Simulink
                        % (re-run this script + the model for each of
                        % 5/10/20/30 to reproduce the full table)

%% --- Stages 1-4, exactly as in the MATLAB pipeline ---
[s_am, m_t, carrier, t, sigPower] = generate_am_signal(Fs, Duration, fc, modIndex, Ac);
[emi_t, emiPowerAchieved, refEmi_t] = generate_emi(Fs, Duration, emiLevelPercent, sigPower);
noisyAM = add_emi(s_am, emi_t);
[estNoisePercent, estNoiseLabel] = estimate_noise_strength(noisyAM, sigPower);

fprintf('Noise-strength estimate for this run: %.2f%% (%s)\n', estNoisePercent, estNoiseLabel);

%% --- package as [time, data] matrices for "From Workspace" blocks ---
% Simulink's "From Workspace" block (Simulink source block, no toolbox
% required) accepts an N-by-2 matrix [time, data] directly -- no need
% for timeseries/Simulink.SimulationData objects.
s_am_ws    = [t, s_am];      %#ok<NASGU>  used by the model
refEmi_ws  = [t, refEmi_t];  %#ok<NASGU>  used by the model
noisyAM_ws = [t, noisyAM];   %#ok<NASGU>  used by the model
% (emi_t itself is not fed separately into the model -- the pipeline
%  diagram's "Addition of Noise" step is done here in simulink_init.m,
%  same as add_emi.m, and its result noisyAM_ws is what the model reads.
%  This mirrors Stage 3 exactly; only the choice of doing the addition
%  in MATLAB vs. a Simulink Sum block differs -- see README_SIMULINK.md
%  for the alternative wiring if your report specifically requires an
%  explicit Sum block inside the model.)

%% --- scalars needed by the model's MATLAB Function / mask parameters ---
simFilterOrder = filterOrder; %#ok<NASGU>
simMuLms       = mu_lms;      %#ok<NASGU>
simStopTime    = Duration;    %#ok<NASGU>
simSampleTime  = 1/Fs;        %#ok<NASGU>

fprintf('Workspace ready. Open simulink/EV_EMI_model.slx (see README_SIMULINK.md) and run.\n');
