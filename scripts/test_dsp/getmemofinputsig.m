clc, clear
load("signals_s1_to_s6.mat")

% input_sig = a_scan(:);
% fid = fopen('input_sig.mem', 'w');
% for i = 1:length(input_sig)
%     fprintf(fid, '%08X\n', typecast(int32(input_sig(i)), 'uint32'));
% end
% fclose(fid);

%%

outputsdir = strcat(pwd, "\..\..\vivado\octogen.sim\sim_1\behav\xsim");

fid = fopen(fullfile(outputsdir, "pre_input.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
p = typecast(uint32(hex2dec(tmp{1})), 'int32');

fid = fopen(fullfile(outputsdir, "post_input.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
q = typecast(uint32(hex2dec(tmp{1})), 'int32');

comp_in = [int32(a_scan(:)).'; p.'; q.'];

figure(1)
yyaxis left
plot(abs(comp_in(1, :)))
yyaxis right
plot(abs(comp_in(3, :)))
title("input sig")

%% bg_sub
fid = fopen(fullfile(outputsdir, "pre_bg_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
p = typecast(uint32(hex2dec(tmp{1})), 'int32');

fid = fopen(fullfile(outputsdir, "post_bg_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
q = typecast(uint32(hex2dec(tmp{1})), 'int32');

comp_bg = [int32(s1(:)).'; p.'; q.'];

figure(2)
yyaxis left
plot(abs(comp_bg(1, :)))
yyaxis right
plot(abs(comp_bg(3, :)))
title("bg")

%% kl

fid = fopen(fullfile(outputsdir, "pre_klin_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
p = typecast(uint32(hex2dec(tmp{1})), 'int32');

fid = fopen(fullfile(outputsdir, "post_klin_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
q = typecast(uint32(hex2dec(tmp{1})), 'int32');

comp_kl = [int32(s2(:)).'; p.'; q.'];

figure(3)
yyaxis left
plot(abs(comp_kl(1, :)))
yyaxis right
plot(abs(comp_kl(3, :)))
title("Klin")


%% disp

fid = fopen(fullfile(outputsdir, "pre_disp_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
p_raw = typecast(uint32(hex2dec(tmp{1})), 'int32');

fid = fopen(fullfile(outputsdir, "post_disp_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
q_raw = typecast(uint32(hex2dec(tmp{1})), 'int32');

% Assume interleaved format: real, imag, real, imag, ...
p_re = p_raw(1:2:end);
p_im = p_raw(2:2:end);

q_re = q_raw(1:2:end);
q_im = q_raw(2:2:end);

% Reconstruct complex vectors
p = complex(double(p_re), double(p_im));
q = complex(double(q_re), double(q_im));

% If s3 is already complex and length matches:
comp_dp = [s3(:).'; p.'; q.'];

figure(4)
yyaxis left
plot(abs(comp_dp(1, :)))
yyaxis right
plot(abs(comp_dp(3, :)))
title("Disp Comp")


%% right FFT

fid = fopen(fullfile(outputsdir, "pre_topsel_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
p_raw = typecast(uint32(hex2dec(tmp{1})), 'int32');

fid = fopen(fullfile(outputsdir, "post_topsel_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
q_raw = typecast(uint32(hex2dec(tmp{1})), 'int32');

% Assume interleaved format: real, imag, real, imag, ...
p_re = p_raw(1:2:end);
p_im = p_raw(2:2:end);

q_re = q_raw(1:2:end);
q_im = q_raw(2:2:end);

% Reconstruct complex vectors
p = complex(double(p_re), double(p_im));
q = complex(double(q_re), double(q_im));

% If s3 is already complex and length matches:
comp_rf = [s4(:).'; p.'; q.'];


figure(5)
yyaxis left
plot(log(abs(comp_rf(1, :))))
yyaxis right
plot(log(abs(comp_rf(3, :))))

% figure()
% yyaxis left
% plot(abs(comp_rf(1, :)))
% hold on
% yyaxis right
% plot(abs(comp_rf(3, :)))
% hold off

%% log scale and bit map

fid = fopen(fullfile(outputsdir, "pre_final_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
p = typecast(uint32(hex2dec(tmp{1})), 'int32');

fid = fopen(fullfile(outputsdir, "post_final_out.txt"), 'r');
tmp = textscan(fid, '%s');
fclose(fid);
q = typecast(uint32(hex2dec(tmp{1})), 'int32');

comp_end = [int32(s6(:)).'; p.'; q.'];

figure(6)
yyaxis left
plot(abs(comp_end(1, :)), "b")
yyaxis right
plot(abs(comp_end(3, :)), "r")
title("final")

%% greyscale map
  % pre_input.txt      post_input.txt
  % pre_bg_out.txt     post_bg_out.txt
  % pre_klin_out.txt   post_klin_out.txt
  % pre_disp_out.txt   post_disp_out.txt
  % pre_fft_out.txt    post_fft_out.txt
  % pre_topsel_out.txt post_topsel_out.txt
  % pre_mag_out.txt    post_mag_out.txt
  % pre_final_out.txt  post_final_out.txt

%%
% 
% clc, clear
% 
% fileID = fopen('slice_001.bin', 'r');
% data = fread(fileID, 'int32');
% fclose(fileID);
% 
% %real_data = load("slice_001.bin");
% rows = data.reshape(768, 512);