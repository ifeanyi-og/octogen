function write_bg_coe(bg, outFile)
%WRITE_BG_COE Write a Vivado .coe file for 32-bit signed background data.
%
%   write_bg_coe(bg)
%   write_bg_coe(bg, outFile)
%
%   Inputs:
%     bg      - background vector, expected length 1024
%     outFile - optional filename, default 'bg_1024.coe'
%
%   Behavior:
%     - Writes the .coe into <repo_root>/mem_init/
%     - Stores signed int32 values as 32-bit 2's complement hex words
%     - Uses radix 16 for Vivado Block Memory Generator initialization

    thisFile   = mfilename('fullpath');
    scriptsDir = fileparts(thisFile);
    repoRoot   = fileparts(scriptsDir);
    memInitDir = fullfile(repoRoot, 'mem_init');

    if ~exist(memInitDir, 'dir')
        mkdir(memInitDir);
    end

    if nargin < 2
        outFile = 'bg_1024.coe';
    end
    outFile = fullfile(memInitDir, outFile);

    DEPTH     = 1024;
    ASCAN_LEN = 1024;

    bg = bg(:);  % force column vector

    if numel(bg) ~= ASCAN_LEN
        error('Expected bg length %d, got %d.', ASCAN_LEN, numel(bg));
    end

    % Cast explicitly to signed 32-bit integers.
    % Any scaling/rounding should be done before calling this function.
    bg_i32 = int32(bg);

    % Since DEPTH == ASCAN_LEN, no padding is needed.
    mem_i32 = bg_i32;

    % Reinterpret signed int32 bit patterns as uint32, then convert to hex.
    mem_u32 = typecast(mem_i32, 'uint32');
    hexStr  = upper(dec2hex(mem_u32, 8));  % 8 hex chars per 32-bit word

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
%bg = int32(0:495);
%bg=ones(512, 1);
bg=zeros(1024,1);
%bg=131071 * ones(512,1);
write_bg_coe(bg, 'klin_c3_rom.coe');