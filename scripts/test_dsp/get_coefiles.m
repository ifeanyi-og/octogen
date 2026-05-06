% mem_to_coe('bg_1024.mem')
% mem_to_coe('cos_lut.mem')
% mem_to_coe('sin_lut.mem')
% mem_to_coe('klin_base.mem')
% mem_to_coe('klin_c0.mem')
% mem_to_coe('klin_c1.mem')
% mem_to_coe('klin_c2.mem')
% mem_to_coe('klin_c3.mem')

mem_to_coe('input_sig.mem')
function mem_to_coe(inFile)
%MEM_TO_COE Convert a .mem file (hex or decimal) to Vivado .coe format
%
%   mem_to_coe('file.mem')
%
% Behavior:
%   - Reads file from current directory
%   - Supports hex (default) or decimal values
%   - Outputs .coe file in current directory
%   - Preserves raw 32-bit patterns

    if nargin < 1
        error('Provide input filename, e.g., mem_to_coe(''data.mem'')');
    end

    if ~isfile(inFile)
        error('File not found: %s', inFile);
    end

    % Read all lines as strings
    fid = fopen(inFile, 'r');
    raw = textscan(fid, '%s');
    fclose(fid);

    raw = raw{1};
    raw = strtrim(raw);

    % Remove empty lines
    raw = raw(~cellfun('isempty', raw));

    % Detect format (hex vs decimal)
    isHex = any(contains(lower(raw{1}), 'x')) || ...
            all(all(ismember(raw{1}, '0123456789abcdefABCDEF')));

    N = numel(raw);

    if isHex
        % Remove optional 0x prefix
        raw = regexprep(raw, '^0x', '', 'ignorecase');

        % Convert hex → uint32
        vals_u32 = uint32(hex2dec(raw));

    else
        % Decimal → int32 → reinterpret
        vals_i32 = int32(str2double(raw));
        vals_u32 = typecast(vals_i32, 'uint32');
    end

    % Convert to 8-char hex
    hexStr = upper(dec2hex(vals_u32, 8));

    % Output filename
    [~, name, ~] = fileparts(inFile);
    outFile = [name, '.coe'];

    fid = fopen(outFile, 'w');
    if fid < 0
        error('Could not open %s for writing.', outFile);
    end

    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');

    for i = 1:N
        if i < N
            fprintf(fid, '%s,\n', hexStr(i,:));
        else
            fprintf(fid, '%s;\n', hexStr(i,:));
        end
    end

    fclose(fid);

    fprintf('Converted %s → %s (%d words)\n', inFile, outFile, N);
end