write_bg_mat(mybg);

function write_bg_mat(mybg, filename)
%WRITE_BG_MAT Save background vector to a .mat file
%
%   write_bg_mat(mybg)
%   write_bg_mat(mybg, filename)
%
%   Saves variable as 'bg' inside the .mat file

    if nargin < 2
        filename = 'bg_1024.mat';
    end

    % Ensure column vector (optional but consistent with your pipeline)
    bg = int32(mybg(:));

    save(filename, 'bg');

    fprintf('Saved background to %s (length = %d)\n', filename, numel(bg));
end