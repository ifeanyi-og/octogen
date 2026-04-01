function [cos_lut, sin_lut] = generate_identity_dispersion_luts(N)
    if nargin < 1
        N = 1024;
    end

    LUT_W = 18;
    FRAC_BITS = 17;

    cos_lut = int32(repmat(2^FRAC_BITS - 1, N, 1)); % 131071 for Q1.17
    sin_lut = int32(zeros(N,1));
end