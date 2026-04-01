function result = generate_dispersion_luts(ascan, maxmin, varargin)
%CALIBRATE_DISPERSION_FROM_ASCAN
% Tune quadratic OCT dispersion compensation from a single A-scan.
%
% This function uses a physically grounded phase model:
%   phi(k) = a2*(k-k0).^2 + a3*(k-k0).^3
%
% and finds the best a2 by maximizing a sharpness metric on the FFT result.
%
% INPUTS
%   ascan   : 1D real-valued A-scan vector (preferably k-linearized already)
%   maxmin  : [lambda_min, lambda_max] in meters, e.g. [800e-9, 900e-9]
%
% NAME-VALUE OPTIONS
%   'A2Range'        : [min max] search range for a2
%                      default = [-1e-10, 1e-10]
%   'NumSteps'       : number of a2 sweep points
%                      default = 201
%   'A3'             : cubic coefficient a3
%                      default = 0
%   'FracBits'       : LUT fractional bits
%                      default = 17  (Q1.17 for 18-bit signed LUTs)
%   'LutWidth'       : LUT width in bits
%                      default = 18
%   'Metric'         : 'peak', 'peak_to_energy', or 'peak_to_sidelobe'
%                      default = 'peak_to_energy'
%   'PeakGuard'      : guard bins around the peak for sidelobe metric
%                      default = 8
%   'UseWindow'      : apply Hann window before FFT scoring
%                      default = true
%   'RemoveDC'       : subtract mean before scoring
%                      default = true
%   'DebugPlots'     : show plots
%                      default = false
%
% OUTPUT
%   result : struct with fields:
%       .a2_best
%       .a3
%       .a2_values
%       .metric_values
%       .best_metric
%       .phi
%       .cos_float
%       .sin_float
%       .cos_lut
%       .sin_lut
%       .k
%       .k0
%       .fft_best
%       .mag_best
%
% HARDWARE CONVENTION
%   FPGA applies:
%       Re = x*cos(phi)
%       Im = -x*sin(phi)
%   which corresponds to multiplying by exp(-1j*phi).
%
% EXAMPLE
%   ascan = double(my_ascan_1024);
%   maxmin = [800e-9, 900e-9];
%   result = calibrate_dispersion_from_ascan(ascan, maxmin, ...
%       'A2Range', [-1e-10, 1e-10], ...
%       'NumSteps', 301, ...
%       'A3', 0, ...
%       'Metric', 'peak_to_energy', ...
%       'DebugPlots', true);

    p = inputParser;
    p.addRequired('ascan', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
    p.addRequired('maxmin', @(x) isnumeric(x) && numel(x) == 2);

    p.addParameter('A2Range', [-1e-10, 1e-10], @(x) isnumeric(x) && numel(x) == 2);
    p.addParameter('NumSteps', 201, @(x) isnumeric(x) && isscalar(x) && x >= 3);
    p.addParameter('A3', 0, @(x) isnumeric(x) && isscalar(x));
    p.addParameter('FracBits', 17, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    p.addParameter('LutWidth', 18, @(x) isnumeric(x) && isscalar(x) && x >= 2);
    p.addParameter('Metric', 'peak_to_energy', @(x) ischar(x) || isstring(x));
    p.addParameter('PeakGuard', 8, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    p.addParameter('UseWindow', true, @(x) islogical(x) && isscalar(x));
    p.addParameter('RemoveDC', true, @(x) islogical(x) && isscalar(x));
    p.addParameter('DebugPlots', false, @(x) islogical(x) && isscalar(x));
    p.parse(ascan, maxmin, varargin{:});
    cfg = p.Results;

    x = double(ascan(:));
    N = numel(x);

    lambda_min = maxmin(1);
    lambda_max = maxmin(2);

    a2_values = linspace(cfg.A2Range(1), cfg.A2Range(2), cfg.NumSteps);
    a3 = cfg.A3;

    % ------------------------------------------------------------
    % Build physical k-axis from wavelength range
    % ------------------------------------------------------------
    lambda = linspace(lambda_min, lambda_max, N).';
    k = 2*pi ./ lambda;
    k0 = mean(k);

    % ------------------------------------------------------------
    % Preprocess input for calibration metric
    % ------------------------------------------------------------
    x_proc = x;
    if cfg.RemoveDC
        x_proc = x_proc - mean(x_proc);
    end
    if cfg.UseWindow
        x_proc = x_proc .* hann(N);
    end

    metric_values = zeros(size(a2_values));
    fft_store = cell(size(a2_values));

    % ------------------------------------------------------------
    % Sweep a2
    % ------------------------------------------------------------
    for ii = 1:numel(a2_values)
        a2 = a2_values(ii);

        phi = a2*(k-k0).^2 + a3*(k-k0).^3;

        % Apply compensation matching FPGA convention: exp(-j*phi)
        y = x_proc .* exp(-1j * phi);

        Y = fft(y);
        mag = abs(Y);

        metric_values(ii) = local_metric(mag, cfg.Metric, cfg.PeakGuard);
        fft_store{ii} = Y;
    end

    [best_metric, best_idx] = max(metric_values);
    a2_best = a2_values(best_idx);

    % ------------------------------------------------------------
    % Build final LUTs using best a2
    % ------------------------------------------------------------
    phi_best = a2_best*(k-k0).^2 + a3*(k-k0).^3;
    cos_float = cos(phi_best);
    sin_float = sin(phi_best);

    [cos_lut, sin_lut] = quantize_luts(cos_float, sin_float, cfg.LutWidth, cfg.FracBits);

    fft_best = fft_store{best_idx};
    mag_best = abs(fft_best);

    result = struct();
    result.a2_best = a2_best;
    result.a3 = a3;
    result.a2_values = a2_values;
    result.metric_values = metric_values;
    result.best_metric = best_metric;
    result.phi = phi_best;
    result.cos_float = cos_float;
    result.sin_float = sin_float;
    result.cos_lut = cos_lut;
    result.sin_lut = sin_lut;
    result.k = k;
    result.k0 = k0;
    result.lambda = lambda;
    result.fft_best = fft_best;
    result.mag_best = mag_best;

    if cfg.DebugPlots
        figure;
        plot(a2_values, metric_values, 'LineWidth', 1.5);
        grid on;
        xlabel('a_2');
        ylabel('Sharpness metric');
        title('Dispersion calibration sweep');

        figure;
        plot(phi_best, 'LineWidth', 1.2);
        grid on;
        xlabel('Sample index');
        ylabel('\phi (rad)');
        title('Best phase profile');

        figure;
        plot(double(cos_lut), 'LineWidth', 1.2); hold on;
        plot(double(sin_lut), 'LineWidth', 1.2);
        grid on;
        xlabel('Sample index');
        ylabel('Quantized value');
        legend('cos LUT', 'sin LUT');
        title('Quantized Q1.17 LUTs');

        figure;
        plot(mag_best, 'LineWidth', 1.2);
        grid on;
        xlabel('FFT bin');
        ylabel('|FFT|');
        title(sprintf('Best-compensated FFT magnitude, a2 = %.4e', a2_best));
    end
end

function score = local_metric(mag, metric_name, peak_guard)
%LOCAL_METRIC Compute sharpness metric from FFT magnitude.

    metric_name = lower(string(metric_name));
    mag = mag(:);

    % Ignore DC bin for robustness
    if numel(mag) > 4
        search_mag = mag(2:floor(end/2));
        offset = 1;
    else
        search_mag = mag;
        offset = 0;
    end

    [peak_val, rel_idx] = max(search_mag);
    peak_idx = rel_idx + offset;

    switch metric_name
        case "peak"
            score = peak_val;

        case "peak_to_energy"
            score = peak_val / (sum(search_mag) + eps);

        case "peak_to_sidelobe"
            mask = true(size(search_mag));
            local_peak = rel_idx;
            lo = max(1, local_peak - peak_guard);
            hi = min(numel(search_mag), local_peak + peak_guard);
            mask(lo:hi) = false;

            sidelobe_mean = mean(search_mag(mask));
            if isempty(sidelobe_mean) || isnan(sidelobe_mean) || sidelobe_mean == 0
                sidelobe_mean = eps;
            end
            score = peak_val / sidelobe_mean;

        otherwise
            error('Unsupported metric "%s". Use peak, peak_to_energy, or peak_to_sidelobe.', metric_name);
    end
end

function [cos_lut, sin_lut] = quantize_luts(cos_float, sin_float, lut_width, frac_bits)
%QUANTIZE_LUTS Quantize floating-point cos/sin LUTs to signed fixed-point.

    scale = 2^frac_bits;
    max_val = 2^(lut_width-1) - 1;
    min_val = -2^(lut_width-1);

    cos_q = round(cos_float * scale);
    sin_q = round(sin_float * scale);

    cos_q = min(max(cos_q, min_val), max_val);
    sin_q = min(max(sin_q, min_val), max_val);

    cos_lut = int32(cos_q);
    sin_lut = int32(sin_q);
end