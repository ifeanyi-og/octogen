function [base, c0_q, c1_q, c2_q, c3_q, info] = gen_klin_tables_fpga(kclk, varargin)
%GEN_KLIN_TABLES_FPGA
% Generate base indices and quantized cubic interpolation coefficients
% for FPGA k-linearization, using only the sampling geometry vector.
%
% Inputs:
%   kclk : sampling geometry vector (monotonic or approximately monotonic)
%
% Name-value options:
%   'A'              : Keys cubic parameter (default = -0.5)
%   'FRAC_BITS'      : fractional bits for fixed-point coeffs (default = 16)
%   'COEF_W'         : coefficient bit width (default = 18)
%   'ForceMonotonic' : force monotonic kclk via cumulative max/min (default = true)
%
% Outputs:
%   base  : uint16, 0-based base indices for FPGA
%   c0_q  : int32, quantized coefficient for tap base-1
%   c1_q  : int32, quantized coefficient for tap base
%   c2_q  : int32, quantized coefficient for tap base+1
%   c3_q  : int32, quantized coefficient for tap base+2
%   info  : debug struct
%
% Notes:
%   - base is clamped so taps [base-1, base, base+1, base+2] are valid
%   - coefficients are normalized before quantization
%   - quantized coeffs are saturated to signed COEF_W range

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

    k = kclk(:);
    N = numel(k);

    if N < 4
        error('kclk must contain at least 4 samples.');
    end

    % -----------------------------
    % Step 1: enforce monotonic geometry
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
    % Step 2: build uniform target grid
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
    % Step 3: map uniform-k positions into raw sample index space
    % -----------------------------
    u = interp1(k_interp, n_interp, k_uniform, 'linear', 'extrap');

    % -----------------------------
    % Step 4: base index + fractional offset
    % -----------------------------
    % Clamp mapped positions into valid sample-index space
    u = max(min(u, N-1), 0);
    
    % True 0-based FPGA base index
    base = floor(u);
    
    % Fractional offset
    t = u - base;
    t = max(min(t, 1), 0);

    % -----------------------------
    % Step 5: Keys cubic coefficients
    % -----------------------------
    c0 = keys_kernel(t + 1, a);   % tap at base-1
    c1 = keys_kernel(t    , a);   % tap at base
    c2 = keys_kernel(1 - t, a);   % tap at base+1
    c3 = keys_kernel(2 - t, a);   % tap at base+2

    % Normalize to improve numerical stability
    s = c0 + c1 + c2 + c3;
    c0 = c0 ./ s;
    c1 = c1 ./ s;
    c2 = c2 ./ s;
    c3 = c3 ./ s;

    % -----------------------------
    % Step 6: quantize to signed fixed-point
    % -----------------------------
    scale = 2^FRAC_BITS;

    qmin = -2^(COEF_W-1);
    qmax =  2^(COEF_W-1) - 1;

    c0_q = round(c0 * scale);
    c1_q = round(c1 * scale);
    c2_q = round(c2 * scale);
    c3_q = round(c3 * scale);

    c0_q = int32(max(min(c0_q, qmax), qmin));
    c1_q = int32(max(min(c1_q, qmax), qmin));
    c2_q = int32(max(min(c2_q, qmax), qmin));
    c3_q = int32(max(min(c3_q, qmax), qmin));

    % base stays 0-based for FPGA use
    base = uint16(base);

    % -----------------------------
    % Debug info
    % -----------------------------
    info = struct();
    info.N = N;
    info.k_mono = k_mono;
    info.k_dir = k_dir;
    info.k_uniform = k_uniform;
    info.u = u;
    info.t = t;
    info.coeff_sum = c0 + c1 + c2 + c3;
    info.c0 = c0;
    info.c1 = c1;
    info.c2 = c2;
    info.c3 = c3;
    info.qmin = qmin;
    info.qmax = qmax;
    info.scale = scale;
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