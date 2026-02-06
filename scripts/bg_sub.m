function write_bg_coe(bg, outFile)
%WRITE_BG_COE  Write a Vivado .coe init file for 32-bit signed BRAM.
%   bg: vector of length 496 (or fewer; will be padded)
%   outFile: e.g. 'bg_496.coe'
%
% The BRAM is assumed depth 512, width 32, radix 16.
% Signed values are stored as 2's complement 32-bit words.

    thisFile = mfilename('fullpath');
    scriptsDir = fileparts(thisFile);
    repoRoot = fileparts(scriptsDir);
    memInitDir = fullfile(repoRoot, 'mem_init');
    if ~exist(memInitDir, 'dir')
        mkdir(memInitDir);
    end
    outFile = fullfile(memInitDir, 'bg_496.coe');

    DEPTH = 512;
    ASCAN_LEN = 496;

    if nargin < 2
        outFile = 'bg_496.coe';
    end

    bg = bg(:); % column

    if numel(bg) ~= ASCAN_LEN
        error('Expected bg length %d, got %d.', ASCAN_LEN, numel(bg));
    end

    % Quantize/cast to int32 explicitly (make sure you're doing your scaling before here)
    bg_i32 = int32(bg);

    % Pad to depth 512
    pad = int32(zeros(DEPTH - ASCAN_LEN, 1));
    mem_i32 = [bg_i32; pad];

    % Convert to raw 32-bit patterns (uint32) then hex
    mem_u32 = typecast(mem_i32, 'uint32');   % preserves bit patterns for negatives
    hexStr  = upper(dec2hex(mem_u32, 8));    % 8 hex digits per 32-bit word

    fid = fopen(outFile, 'w');
    if fid < 0
        error('Could not open %s for writing.', outFile);
    end

    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');

    for i = 1:DEPTH
        if i < DEPTH
            fprintf(fid, '%s,\n', hexStr(i,:));
        else
            fprintf(fid, '%s;\n', hexStr(i,:));
        end
    end

    fclose(fid);
    fprintf('Wrote %s (%d words)\n', outFile, DEPTH);
end

% rng("default");
% bg=100*randn(496, 1);
bg = int32(0:495);
write_bg_coe(bg, 'bg_496.coe');