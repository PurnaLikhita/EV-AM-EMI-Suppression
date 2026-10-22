function e = lms_matlab_function_block(x_ref, d, order, mu)
%#codegen
% LMS_MATLAB_FUNCTION_BLOCK  Paste this INSIDE a Simulink "MATLAB
% Function" block (do not call it as a normal .m file -- it is written
% here as a plain function only so the code can be reviewed/edited in a
% text editor before pasting).
%
% This is the SAME algorithm as lms_filter.m, restructured for
% sample-by-sample streaming execution using `persistent` state, which
% is how a Simulink MATLAB Function block must be written (it is called
% once per simulation time step, not once for a whole vector).
%
% BLOCK SETUP (see README_SIMULINK.md Sec. "Block 6"):
%   Inputs:  x_ref (scalar, reference tap), d (scalar, noisy AM sample)
%   Outputs: e (scalar, filtered/recovered AM sample)
%   Parameters (block mask or workspace constants): order, mu
%     -- wire these to simFilterOrder / simMuLms from simulink_init.m,
%        or hardcode order=32, mu=0.0015 to match main.m exactly.

    persistent w xbuf
    if isempty(w)
        w    = zeros(order,1);
        xbuf = zeros(order,1);
    end

    xbuf = [x_ref; xbuf(1:end-1)];
    y = w' * xbuf;
    e = d - y;
    w = w + mu * e * xbuf;
end
