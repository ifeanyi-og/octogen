% Input variable: x
% Expected: 1024x1 int32

% Example:
% x = int32(randi([-1000,1000], 1024, 1));

x=sin_lut;

% Validate input
if ~isa(x, 'int32')
    error('Input variable x must be int32.');
end

if ~isequal(size(x), [1024, 1])
    error('Input variable x must be 1024x1.');
end

% Output filename
filename = 'sin_lut.bin';

% Open file for binary writing
fid = fopen(filename, 'wb');
if fid == -1
    error('Could not open file for writing: %s', filename);
end

% Write data as int32
count = fwrite(fid, x, 'int32');

% Close file
fclose(fid);

% Check that all values were written
if count ~= 1024
    error('Only wrote %d elements out of 1024.', count);
end

fprintf('Successfully wrote %d int32 values to %s\n', count, filename);