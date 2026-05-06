% ============================================================
% Generate identity dispersion LUTs and save to .mat files
% ============================================================

% Parameters
N = 1024;  % length of A-scan / LUT

% Generate LUTs
[cos_lut, sin_lut] = generate_identity_dispersion_luts(N);

% Save to .mat files
save('cos_lut.mat', 'cos_lut');
save('sin_lut.mat', 'sin_lut');

disp('Identity LUTs saved to cos_lut.mat and sin_lut.mat');