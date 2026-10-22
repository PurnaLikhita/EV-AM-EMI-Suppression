function [s_am, m_t, carrier, t, signalPower] = generate_am_signal(Fs, duration, fc, modIndex, Ac)
%GENERATE_AM_SIGNAL Create a scaled AM broadcast test signal.
validateattributes(Fs, {'numeric'}, {'scalar','positive','finite'});
validateattributes(duration, {'numeric'}, {'scalar','positive','finite'});
validateattributes(fc, {'numeric'}, {'scalar','positive','finite','<',Fs/2});
validateattributes(modIndex, {'numeric'}, {'scalar','>=',0,'<=',1});
validateattributes(Ac, {'numeric'}, {'scalar','positive','finite'});
t = (0:1/Fs:duration-1/Fs).';
% Multi-tone baseband is a repeatable proxy for programme audio.
m_t = 0.55*sin(2*pi*300*t) + 0.30*sin(2*pi*700*t) + 0.15*sin(2*pi*1200*t);
m_t = m_t / max(abs(m_t));
carrier = Ac*cos(2*pi*fc*t);
s_am = Ac*(1 + modIndex*m_t).*cos(2*pi*fc*t);
signalPower = mean(s_am.^2);
end
