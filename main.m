%% EV AM RADIO EMI SUPPRESSION -- mandatory LMS simulation
clear; clc; close all;
rng(42,'twister');                 % reproducible synthetic EMI/noise
Fs = 100000; Duration = 2; fc = 10000; modIndex = 0.7; Ac = 1;
filterOrder = 32; mu_lms = 0.0015; levels = [5 10 20 30];
if ~exist('results','dir'), mkdir('results'); end
[resultsTable, runs] = run_noise_conditions(Fs, Duration, fc, modIndex, Ac, filterOrder, mu_lms, levels);
disp('=== EV AM EMI SUPPRESSION: LMS RESULTS ==='); disp(resultsTable);
writetable(resultsTable, fullfile('results','final_results_table.csv'));
save(fullfile('results','final_results.mat'), 'resultsTable', 'runs', 'Fs', 'Duration', 'fc', 'modIndex', 'Ac', 'filterOrder', 'mu_lms', 'levels');
plot_results(runs, resultsTable, Fs, 'results');
fprintf('\nSaved results/final_results_table.csv, results/final_results.mat, and report figures in results/.\n');
