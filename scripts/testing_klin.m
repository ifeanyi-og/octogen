% Inputs:
%   x_raw  : reverse-engineered raw A-scan
%   kclk   : assumed nonuniform sampled k-clock
%   tables from gen_klin_tables_fpga
x_raw=bscan(100, :);
[base, c0_q, c1_q, c2_q, c3_q, info] = gen_klin_tables_fpga(x_raw, kclk);

% Convert quantized coeffs back to float for testing
scale = 2^16;
c0 = double(c0_q)/scale;
c1 = double(c1_q)/scale;
c2 = double(c2_q)/scale;
c3 = double(c3_q)/scale;

% Hardware-style application
N = numel(x_raw);
y_tab = zeros(N,1);
for m = 1:N
    b = double(base(m));   % 0-based
    i0 = max(min(b-1, N-1), 0) + 1;
    i1 = max(min(b  , N-1), 0) + 1;
    i2 = max(min(b+1, N-1), 0) + 1;
    i3 = max(min(b+2, N-1), 0) + 1;

    y_tab(m) = c0(m)*x_raw(i0) + c1(m)*x_raw(i1) + ...
               c2(m)*x_raw(i2) + c3(m)*x_raw(i3);
end

% Direct interpolation reference
k = kclk(:);
if k(end) < k(1)
    k_ref = flipud(k);
    x_ref = flipud(x_raw(:));
else
    k_ref = k;
    x_ref = x_raw(:);
end
k_uniform = linspace(k_ref(1), k_ref(end), N).';
y_ref = interp1(k_ref, x_ref, k_uniform, 'pchip', 'extrap');

% Error metrics
rmse = sqrt(mean((y_tab - y_ref).^2));
mx   = max(abs(y_tab - y_ref));

fprintf('RMSE = %.6g\n', rmse);
fprintf('Max abs error = %.6g\n', mx);

% Sanity plots
figure; plot(double(base)); title('Base index');
figure; plot([c0 c1 c2 c3]); title('Quantized coeffs (dequantized)');
figure; plot(c0+c1+c2+c3); title('Coeff sum');

figure;
plot(y_ref, 'DisplayName', 'Reference'); hold on;
plot(y_tab, '--', 'DisplayName', 'Table-based');
legend; title('Interpolation comparison');

%% fft comp
fft_raw   = abs(fft(x_raw));
fft_klin  = abs(fft(y_tab));

figure;
plot(fft_raw, 'DisplayName','Raw'); hold on;
plot(fft_klin, 'DisplayName','K-linearized');
legend;
title('FFT comparison');
