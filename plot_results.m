function plot_results(runs, resultsTable, Fs, outputDir)
%PLOT_RESULTS Create report-ready waveform, spectrum, convergence and summary figures.
if ~exist(outputDir, 'dir'), mkdir(outputDir); end
sampleCount = min(round(0.015*Fs), numel(runs(1).t));
for k = 1:numel(runs)
    r = runs(k); idx = 1:sampleCount;
    fig = figure('Visible','off','Color','w','Name',sprintf('%d%% EMI waveform',r.level));
    plot(r.t(idx)*1e3,r.clean(idx),'LineWidth',1); hold on; plot(r.t(idx)*1e3,r.noisy(idx)); plot(r.t(idx)*1e3,r.filtered(idx));
    grid on; xlabel('Time (ms)'); ylabel('Amplitude'); title(sprintf('AM recovery at %d%% EMI',r.level)); legend('Clean AM','Noisy AM','LMS output','Location','best');
    exportgraphics(fig, fullfile(outputDir,sprintf('waveform_%02d.png',r.level))); close(fig);
    fig = figure('Visible','off','Color','w','Name',sprintf('%d%% EMI spectrum',r.level));
    [f,a] = calculate_fft(r.clean,Fs); [~,b] = calculate_fft(r.noisy,Fs); [~,c] = calculate_fft(r.filtered,Fs);
    plot(f/1e3,a,'LineWidth',1); hold on; plot(f/1e3,b); plot(f/1e3,c); xlim([0 20]); ylim([-100 5]); grid on;
    xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)'); title(sprintf('Spectrum at %d%% EMI',r.level)); legend('Clean AM','Noisy AM','LMS output','Location','best');
    exportgraphics(fig, fullfile(outputDir,sprintf('spectrum_%02d.png',r.level))); close(fig);
    fig = figure('Visible','off','Color','w','Name',sprintf('%d%% LMS convergence',r.level));
    plot(10*log10(movmean(r.mseCurve,200)+eps),'LineWidth',1); grid on; xlabel('Sample'); ylabel('Smoothed error power (dB)'); title(sprintf('LMS convergence at %d%% EMI',r.level));
    exportgraphics(fig, fullfile(outputDir,sprintf('convergence_%02d.png',r.level))); close(fig);
end
fig = figure('Visible','off','Color','w','Name','Performance summary');
tiledlayout(2,2); x = resultsTable.EMI_Level_Percent;
nexttile; plot(x,resultsTable.SNR_Before_dB,'o-',x,resultsTable.SNR_After_dB,'s-','LineWidth',1.4); grid on; xlabel('EMI level (%)'); ylabel('SNR (dB)'); legend('Before','After','Location','best'); title('SNR');
nexttile; bar(x,[resultsTable.MSE_Before resultsTable.MSE_After]); grid on; xlabel('EMI level (%)'); ylabel('MSE'); legend('Before','After'); title('MSE');
nexttile; plot(x,resultsTable.Noise_Reduction_Percent,'o-','LineWidth',1.4); grid on; xlabel('EMI level (%)'); ylabel('Reduction (%)'); title('Noise reduction');
nexttile; plot(x,resultsTable.Estimated_Noise_Percent,'o-',x,x,'--','LineWidth',1.4); grid on; xlabel('Configured EMI (%)'); ylabel('Estimated noise (%)'); legend('Estimate','Ideal','Location','best'); title('Estimator check');
exportgraphics(fig,fullfile(outputDir,'performance_summary.png')); close(fig);
fig = figure('Visible','off','Color','w','Name','Final LMS coefficients');
stem(runs(end).weights,'filled'); grid on; xlabel('Tap index'); ylabel('Coefficient');
title(sprintf('Final LMS FIR coefficients (%d%% EMI)', runs(end).level));
exportgraphics(fig,fullfile(outputDir,'final_filter_coefficients.png')); close(fig);
end
