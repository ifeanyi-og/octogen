function [base, c0_q, c1_q, c2_q, c3_q, info] = gen_klin_tables_fpga(ascan, kclk, varargin)
%GEN_KLIN_TABLES_FPGA
% Generate base indices + quantized cubic interpolation coefficients
% directly usable in FPGA BRAM.
%
% Outputs:
%   base  : uint16 (0-based indices)
%   c*_q  : int32 (quantized Q format, e.g., Q2.16 in 18 bits)
%   info  : debug struct (optional)
%
% Default:
%   FRAC_BITS = 16, COEF_W = 18

    % -----------------------------
    % Parameters
    % -----------------------------
    p = inputParser;
    addParameter(p, 'A', -0.5);
    addParameter(p, 'FRAC_BITS', 16);
    addParameter(p, 'COEF_W', 18);
    addParameter(p, 'ForceMonotonic', true);
    parse(p, varargin{:});

    a         = p.Results.A;
    FRAC_BITS = p.Results.FRAC_BITS;
    COEF_W    = p.Results.COEF_W;

    x = ascan(:);
    k = kclk(:);
    N = numel(x);

    if numel(k) ~= N
        error('ascan and kclk must match length.');
    end

    % -----------------------------
    % Step 1: monotonic kclk
    % -----------------------------
    if p.Results.ForceMonotonic
        if k(end) >= k(1)
            k_mono = cummax(k);
        else
            k_mono = -cummax(-k);
        end
    else
        k_mono = k;
    end

    % detect direction
    if k_mono(end) > k_mono(1)
        k_dir = +1;
    else
        k_dir = -1;
    end

    % -----------------------------
    % Step 2: uniform k grid
    % -----------------------------
    if k_dir > 0
        k_uniform = linspace(k_mono(1), k_mono(end), N).';
        k_interp  = k_mono;
        n_interp  = (0:N-1).';
    else
        k_uniform = linspace(k_mono(end), k_mono(1), N).';
        k_interp  = flipud(k_mono);
        n_interp  = flipud((0:N-1).');
    end

    % -----------------------------
    % Step 3: fractional index
    % -----------------------------
    u = interp1(k_interp, n_interp, k_uniform, 'linear', 'extrap');

    % -----------------------------
    % Step 4: base + fractional offset
    % -----------------------------
    base = floor(u);

    base = max(min(base, N-3), 1);   % ensure valid taps
    t = u - base;
    t = max(min(t,1),0);

    % -----------------------------
    % Step 5: cubic coefficients
    % -----------------------------
    c0 = keys_kernel(t + 1, a);
    c1 = keys_kernel(t    , a);
    c2 = keys_kernel(1 - t, a);
    c3 = keys_kernel(2 - t, a);

    % normalize (important for stability)
    s = c0 + c1 + c2 + c3;
    c0 = c0 ./ s;
    c1 = c1 ./ s;
    c2 = c2 ./ s;
    c3 = c3 ./ s;

    % -----------------------------
    % Step 6: quantization (Q format)
    % -----------------------------
    scale = 2^FRAC_BITS;

    qmin = -2^(COEF_W-1);
    qmax =  2^(COEF_W-1) - 1;

    c0_q = round(c0 * scale);
    c1_q = round(c1 * scale);
    c2_q = round(c2 * scale);
    c3_q = round(c3 * scale);

    % saturation
    c0_q = int32(max(min(c0_q, qmax), qmin));
    c1_q = int32(max(min(c1_q, qmax), qmin));
    c2_q = int32(max(min(c2_q, qmax), qmin));
    c3_q = int32(max(min(c3_q, qmax), qmin));

    % base as uint (0-based indexing for FPGA)
    base = uint16(base);

    % -----------------------------
    % Debug info
    % -----------------------------
    info = struct();
    info.u = u;
    info.t = t;
    info.coeff_sum = c0 + c1 + c2 + c3;
    info.k_uniform = k_uniform;
end


% ==========================================================
function y = keys_kernel(x, a)
    ax = abs(x);
    y = zeros(size(x));

    m1 = ax < 1;
    y(m1) = (a+2).*ax(m1).^3 - (a+3).*ax(m1).^2 + 1;

    m2 = (ax >= 1) & (ax < 2);
    y(m2) = a.*ax(m2).^3 - 5*a.*ax(m2).^2 + 8*a.*ax(m2) - 4*a;
end