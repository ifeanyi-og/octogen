%load in a sample b-scan first and pull a random a scan from raw_signals
ascan=raw_signals(100, :);
ascan=ascan-mybg;

[base, c0, c1, c2, c3] = gen_klin_tables_fpga(ascan, kclk);

write_klin_tables_mat(base, c0, c1, c2, c3);

function write_klin_tables_mat(base, c0, c1, c2, c3, outDir)
%WRITE_KLIN_TABLES_MAT
% Save k-linearization tables into separate .mat files as int32 vectors.
%
% Inputs:
%   base, c0, c1, c2, c3 : vectors from gen_klin_tables_fpga
%   outDir               : output directory (optional)
%
% Output files:
%   klin_base.mat   -> variable: klin_base
%   klin_c0.mat     -> variable: klin_c0
%   klin_c1.mat     -> variable: klin_c1
%   klin_c2.mat     -> variable: klin_c2
%   klin_c3.mat     -> variable: klin_c3

    if nargin < 6 || isempty(outDir)
        thisFile = mfilename('fullpath');
        scriptsDir = fileparts(thisFile);
        repoRoot = fileparts(scriptsDir);
        outDir = fullfile(repoRoot, 'mem_init');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % Force column vectors and int32 type
    klin_base = int32(base(:));
    klin_c0   = int32(c0(:));
    klin_c1   = int32(c1(:));
    klin_c2   = int32(c2(:));
    klin_c3   = int32(c3(:));

    save(fullfile(outDir, 'klin_base.mat'), 'klin_base');
    save(fullfile(outDir, 'klin_c0.mat'),   'klin_c0');
    save(fullfile(outDir, 'klin_c1.mat'),   'klin_c1');
    save(fullfile(outDir, 'klin_c2.mat'),   'klin_c2');
    save(fullfile(outDir, 'klin_c3.mat'),   'klin_c3');

    fprintf('Wrote:\n');
    fprintf('  %s\n', fullfile(outDir, 'klin_base.mat'));
    fprintf('  %s\n', fullfile(outDir, 'klin_c0.mat'));
    fprintf('  %s\n', fullfile(outDir, 'klin_c1.mat'));
    fprintf('  %s\n', fullfile(outDir, 'klin_c2.mat'));
    fprintf('  %s\n', fullfile(outDir, 'klin_c3.mat'));
end