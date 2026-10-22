function [emi_t, achievedPower, reference] = generate_emi(Fs, duration, levelPercent, signalPower)
%GENERATE_EMI Synthetic EV inverter EMI and a correlated PWM-sync reference.
validateattributes(levelPercent, {'numeric'}, {'scalar','positive','finite'});
N = round(Fs*duration);
t = (0:N-1).'/Fs;
fsw = 2000;                         % assumed inverter switching frequency
% Start -> accelerate -> cruise envelope, bounded away from zero.
envelope = 0.35 + 0.65*(0.5 + 0.5*tanh((t-0.45)/0.12));
envelope = envelope .* (1 + 0.12*sin(2*pi*0.8*t));
harmonics = sin(2*pi*fsw*t) + 0.55*sin(2*pi*2*fsw*t+0.4) ...
    + 0.30*sin(2*pi*3*fsw*t+1.1) + 0.15*sin(2*pi*4*fsw*t+0.7);
reference = envelope .* harmonics;
% Unknown coupling path from the inverter reference to the antenna path.
coupled = filter([0.72 -0.36 0.18 0.08], 1, reference);
broadband = randn(N,1);
emiRaw = 0.88*coupled + 0.12*std(coupled)*broadband/std(broadband);
targetPower = signalPower * levelPercent/100;
emi_t = emiRaw * sqrt(targetPower/mean(emiRaw.^2));
achievedPower = mean(emi_t.^2);
end
