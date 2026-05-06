maxmin = [770e-9, 935e-9];
a2range = [-1e-10, 1e-10];
ascan = double(raw_signals(75, :));

function output = bg_sub_f(input)
    output = input - 43;
end

function output = k_lin_f(nonlinear_y, linear_x, nonlinear_x)
    output = interp1(nonlinear_x, nonlinear_y, linear_x, 'cubic', 'extrap');
end

s1=bg_sub_f(ascan);
s2=k_lin_f(s1, tvec, kclk);

result = generate_dispersion_luts(s2, maxmin, ...
    'A2Range', a2range, ...
    'NumSteps', 301, ...
    'A3', 0, ...
    'FracBits', 17, ...
    'LutWidth', 18, ...
    'Metric', 'peak_to_energy', ...
    'DebugPlots', true);

disp(result.a2_best);
cos_lut=result.cos_lut;
sin_lut=result.sin_lut;