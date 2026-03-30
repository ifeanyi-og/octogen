% gen_log_rom_coe.m
% Generates .coe files for FPGA log compression block
% ROM contents:
%   base[s]  = log2(1 + s/N)
%   slope[s] = log2(1 + (s+1)/N) - log2(1 + s/N)
%
% Fixed-point format:
%   unsigned Q0.LUT_W
%
% Current recommended settings:
%   SEG_BITS = 6  -> 64 segments
%   LUT_W    = 18

clear; clc;

%% Parameters
SEG_BITS = 6;
LUT_W    = 18;

N = 2^SEG_BITS;
SCALE = 2^LUT_W;

base_vals  = zeros(1, N);
slope_vals = zeros(1, N);



%% Compute floating-point values
for s = 0:N-1
    m0 = 1 + s / N;
    m1 = 1 + (s + 1) / N;

    base_f  = log2(m0);
    slope_f = log2(m1) - log2(m0);

    % Quantize to unsigned Q0.LUT_W
    base_q  = round(base_f  * SCALE);
    slope_q = round(slope_f * SCALE);

    % Saturate just in case
    base_q  = min(max(base_q,  0), SCALE - 1);
    slope_q = min(max(slope_q, 0), SCALE - 1);

    base_vals(s+1)  = base_q;
    slope_vals(s+1) = slope_q;
end

%% Write COE files

write_coe('log_base_rom.coe',  base_vals);
write_coe('log_slope_rom.coe', slope_vals);

%% Local function
function write_coe(filename, data)
    thisFile = mfilename('fullpath');
    scriptsDir = fileparts(thisFile);
    repoRoot = fileparts(scriptsDir);
    memInitDir = fullfile(repoRoot, 'mem_init');
    if ~exist(memInitDir, 'dir')
        mkdir(memInitDir);
    end
    outFile = fullfile(memInitDir, filename);
    fid = fopen(outFile, 'w');
    if fid == -1
        error('Could not open file: %s', filename);
    end

    fprintf(fid, 'memory_initialization_radix=10;\n');
    fprintf(fid, 'memory_initialization_vector=\n');

    for k = 1:length(data)
        if k < length(data)
            fprintf(fid, '%d,\n', data(k));
        else
            fprintf(fid, '%d;\n', data(k));
        end
    end

    fclose(fid);
end