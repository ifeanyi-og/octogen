%% tune_log_compress_map_from_raw_real1024.m
% Tune FPGA log-compression floor/gain constants against a target B-scan
% using the actual FPGA-style input:
%
%   raw_signals : 768 x 1024 double   (real-valued A-scans)
%
% Assumptions:
%   - target B-scan image is already in workspace as: bscan
%   - raw FPGA input is already in workspace as: raw_signals
%   - calibration variables are already in workspace:
%         tvec, kclk
%   - if maxmin / a_coeffs / mybg are not present, defaults are used
%
% Pipeline modeled here:
%   raw_signals
%     -> background subtraction
%     -> k-linearization
%     -> dispersion compensation
%     -> FFT
%     -> magnitude-squared
%     -> crop display half
%     -> FPGA-style log/floor/gain mapping
%
% Output:
%   - best floor/gain in real-valued form
%   - suggested HDL constants MAP_FLOOR_Q and MAP_GAIN_Q
%   - plots for visual comparison

clearvars -except bscan raw_signals tvec kclk maxmin a_coeffs mybg
clc;

%%
depth_mean = mean(mag2_bscan_full, 1);
figure;
plot(depth_mean);
title('Mean mag^2 vs FFT bin after DC removal + Hann window');

%% ------------------------------------------------------------------------
% User settings
% -------------------------------------------------------------------------
floor_vals = 0:0.25:6.0;
gain_vals  = 2:1:12;

LUT_W         = 18;
MAP_GAIN_FRAC = 8;

% Which FFT half should be displayed?
% For real 1024-point input, FFT output is mirrored.
% Common choices:
%   'first'  -> bins 1:512
%   'second' -> bins 513:1024
display_half = 'second';   % change if your display convention uses the other half

% Optional smoothing for visual evaluation only
do_smoothing = false;
smooth_sigma = 0.2;

%% ------------------------------------------------------------------------
% Validate inputs
% -------------------------------------------------------------------------
assert(exist('bscan', 'var') == 1, ...
    'Expected target image "bscan" in workspace.');
assert(exist('raw_signals', 'var') == 1, ...
    'Expected raw input matrix "raw_signals" in workspace.');
assert(exist('tvec', 'var') == 1, ...
    'Expected "tvec" in workspace.');
assert(exist('kclk', 'var') == 1, ...
    'Expected "kclk" in workspace.');

if exist('maxmin', 'var') ~= 1
    maxmin = [800e-9, 900e-9];
end

if exist('a_coeffs', 'var') ~= 1
    a_coeffs = [0, -4e-11, 0];
end

if exist('mybg', 'var') ~= 1
    warning('mybg not found in workspace. Falling back to scalar-mean subtraction.');
end

target = double(bscan);
target = ensure_numeric_2d(target);

raw_signals = double(raw_signals);
assert(ndims(raw_signals) == 2, 'raw_signals must be 2D.');
assert(size(raw_signals,2) == 1024, 'Expected raw_signals to have 1024 columns.');

% Normalize target into 0..255
target = normalize_to_255(target);

%% ------------------------------------------------------------------------
% Build mag^2 B-scan from raw_signals
% -------------------------------------------------------------------------
fprintf('Building mag^2 B-scan from real 1024-point raw_signals...\n');

mag2_bscan_full = build_mag2_bscan_from_raw_real1024(raw_signals, tvec, kclk, maxmin, a_coeffs, exist('mybg','var') == 1, mybg);

% Crop the FFT half that you actually intend to display
mag2_bscan = crop_fft_half(mag2_bscan_full, display_half);

% Make target match cropped width if needed
if size(target,2) ~= size(mag2_bscan,2)
    if size(target,2) == size(mag2_bscan_full,2)
        target = crop_fft_half(target, display_half);
    else
        error(['Target bscan width does not match either the full FFT width or ' ...
               'the cropped display-half width.']);
    end
end

assert(all(size(target) == size(mag2_bscan)), ...
    'Target image and tuned mag2_bscan must have the same size after cropping.');

fprintf('Done. mag2_bscan size used for tuning = %d x %d\n', size(mag2_bscan,1), size(mag2_bscan,2));

%% ------------------------------------------------------------------------
% Inspect pre-log image
% -------------------------------------------------------------------------
figure('Name', 'Pre-log FPGA input', 'Color', 'w');
imagesc(log10(mag2_bscan.' + 1e-12));
colormap(gray);
title('Pre-log FPGA input: log10(abs(FFT)^2)');

%% ------------------------------------------------------------------------
% Sweep floor/gain
% -------------------------------------------------------------------------
fprintf('Sweeping floor/gain...\n');

best_score   = inf;
best_floor   = NaN;
best_gain    = NaN;
best_img     = [];
best_metrics = struct();

results = zeros(length(floor_vals), length(gain_vals));

for fi = 1:length(floor_vals)
    floor_log2 = floor_vals(fi);

    for gi = 1:length(gain_vals)
        gain = gain_vals(gi);

        img8 = emulate_fpga_log_compress_map(mag2_bscan, floor_log2, gain);

        if do_smoothing
            img_eval = imgaussfilt(double(img8), smooth_sigma);
        else
            img_eval = double(img8);
        end

        err_mse = mean((img_eval(:) - target(:)).^2);

        [h1, ~] = imhist(uint8(round(target)));
        [h2, ~] = imhist(uint8(round(img_eval)));
        h1 = double(h1) / sum(h1);
        h2 = double(h2) / sum(h2);
        err_hist = sum(abs(h1 - h2));

        % Weighted score
        score = err_mse + 50 * err_hist;

        results(fi, gi) = score;

        if score < best_score
            best_score = score;
            best_floor = floor_log2;
            best_gain  = gain;
            best_img   = img8;

            best_metrics.err_mse  = err_mse;
            best_metrics.err_hist = err_hist;
        end
    end
end

fprintf('Best floor_log2 = %.2f\n', best_floor);
fprintf('Best gain       = %.2f\n', best_gain);
fprintf('Best score      = %.4f\n', best_score);
fprintf('Best MSE        = %.4f\n', best_metrics.err_mse);
fprintf('Best hist err   = %.4f\n', best_metrics.err_hist);

%% ------------------------------------------------------------------------
% Convert to HDL constants
% -------------------------------------------------------------------------
MAP_FLOOR_Q = round(best_floor * 2^LUT_W);
MAP_GAIN_Q  = round(best_gain  * 2^MAP_GAIN_FRAC);

fprintf('\nSuggested HDL constants:\n');
fprintf('  MAP_FLOOR_Q   = %d\n', MAP_FLOOR_Q);
fprintf('  MAP_GAIN_Q    = %d\n', MAP_GAIN_Q);
fprintf('  MAP_GAIN_FRAC = %d\n', MAP_GAIN_FRAC);
fprintf('  LUT_W         = %d\n', LUT_W);

%% ------------------------------------------------------------------------
% Show results
% -------------------------------------------------------------------------
figure('Name','log_compress_map tuning','Color','w');

subplot(2,3,1);
imshow(uint8(round(target)), []);
title('Target B-scan');

subplot(2,3,2);
imshow(best_img, []);
title(sprintf('Best FPGA-style fit\nfloor=%.2f, gain=%.2f', best_floor, best_gain));

subplot(2,3,3);
imshow(abs(double(best_img) - target), []);
title('Absolute error');

subplot(2,3,4);
histogram(target(:), 256);
title('Target histogram');

subplot(2,3,5);
histogram(double(best_img(:)), 256);
title('Best-fit histogram');

subplot(2,3,6);
imagesc(gain_vals, floor_vals, results);
axis xy;
colorbar;
xlabel('gain');
ylabel('floor log2');
title('Sweep score');

sgtitle('log\_compress\_map tuning');

%% ------------------------------------------------------------------------
% Nearby candidate panel
% -------------------------------------------------------------------------
nearby = [
    best_floor,             best_gain;
    max(best_floor-0.5,0),  best_gain;
    best_floor+0.5,         best_gain;
    best_floor,             max(best_gain-2,0);
    best_floor,             best_gain+2;
    max(best_floor-0.5,0),  max(best_gain-2,0)
];

figure('Name','Nearby Candidates','Color','w');
for k = 1:size(nearby,1)
    fl = nearby(k,1);
    gn = nearby(k,2);

    img8 = emulate_fpga_log_compress_map(mag2_bscan, fl, gn);

    subplot(2,3,k);
    imshow(img8, []);
    title(sprintf('floor=%.2f, gain=%.2f', fl, gn));
end

%% ------------------------------------------------------------------------
% Save result
% -------------------------------------------------------------------------
tuning_result.best_floor_log2 = best_floor;
tuning_result.best_gain       = best_gain;
tuning_result.MAP_FLOOR_Q     = MAP_FLOOR_Q;
tuning_result.MAP_GAIN_Q      = MAP_GAIN_Q;
tuning_result.MAP_GAIN_FRAC   = MAP_GAIN_FRAC;
tuning_result.LUT_W           = LUT_W;
tuning_result.best_score      = best_score;
tuning_result.best_metrics    = best_metrics;
tuning_result.display_half    = display_half;

save('log_compress_map_tuning_result_real1024.mat', 'tuning_result');

fprintf('\nSaved tuning_result to log_compress_map_tuning_result_real1024.mat\n');

%% ========================================================================
% Local helper functions
% ========================================================================

function x = ensure_numeric_2d(x)
    x = double(x);
    assert(ndims(x) == 2, 'Expected a 2D matrix.');
end

function x255 = normalize_to_255(x)
    xmin = min(x(:));
    xmax = max(x(:));

    if xmax == xmin
        x255 = zeros(size(x));
    else
        x255 = 255 * (x - xmin) / (xmax - xmin);
    end
end

function y = crop_fft_half(x, which_half)
    n = size(x,2);
    assert(mod(n,2) == 0, 'Expected even FFT width.');

    switch lower(which_half)
        case 'first'
            y = x(:, 1:n/2);
        case 'second'
            y = x(:, n/2+1:end);
        otherwise
            error('display_half must be either ''first'' or ''second''.');
    end
end

function mag2_bscan = build_mag2_bscan_from_raw_real1024(raw_signals, tvec, kclk, maxmin, a_coeffs, use_bg_vector, mybg)
    [num_ascans, signal_length] = size(raw_signals);
    mag2_bscan = zeros(num_ascans, signal_length);

    for ii = 1:num_ascans
        raw = raw_signals(ii, :);

        if use_bg_vector
            s1 = bg_sub_f(raw);
        else
            s1 = raw - mean(raw);
        end

        s2 = k_lin_f(s1, tvec, kclk);
        s3 = disp_c_f(s2, maxmin, a_coeffs);
        s3=s3-mean(s3);
        s4 = fft_f(s3);

        mag2_bscan(ii, :) = abs(s4).^2;
    end
end

function output = bg_sub_f(input)
    output = input - mybg;
end

function output = disp_c_f(input, maxmin, a_coeffs)
    N = length(input);
    lambda = linspace(maxmin(1), maxmin(2), N);
    k = 2*pi ./ lambda;
    k0 = mean(k);
    phi = a_coeffs(2) * (k-k0).^2 + a_coeffs(3) * (k-k0).^3;
    output = input .* exp(-1i * phi);
end

function output = k_lin_f(nonlinear_y, linear_x, nonlinear_x)
    output = interp1(nonlinear_x, nonlinear_y, linear_x, 'cubic', 'extrap');
end

function output = fft_f(input)
    w = hann(length(input)).';
    output = fft(input .* w);
end

function img8 = emulate_fpga_log_compress_map(mag2_bscan, floor_log2, gain)
    mag2_bscan = double(mag2_bscan);

    log2_img = zeros(size(mag2_bscan));
    nz = mag2_bscan > 0;
    log2_img(nz) = log2(mag2_bscan(nz));

    mapped = (log2_img - floor_log2) * gain;
    mapped(mapped < 0)   = 0;
    mapped(mapped > 255) = 255;

    img8 = uint8(round(mapped));
end