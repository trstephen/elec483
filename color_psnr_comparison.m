disp('Assume ${root}YCbCr.tiff and ${root}RGB.tiff exist and have correct color profiles');
im_base_name = input('Image root name: ', 's');

% TODO: Check if files exist

im_YCbCr_name = strcat(im_base_name, 'YCbCr.tiff');
im_YCbCr = Tiff(im_YCbCr_name, 'r');
[im_Y, im_Cb, im_Cr] = read(im_YCbCr);
close(im_YCbCr);

im_RGB_name = strcat(im_base_name, 'RGB.tiff');
im_RGB = imread(im_RGB_name);
im_R = im_RGB(:,:,1); im_G = im_RGB(:,:,2); im_B = im_RGB(:,:,3);

wm = input('Watermark Message: ','s');

bch_n = 255; bch_k = 199; word_size = 6;
max_wm_len = floor(bch_k / word_size);

wm_len = length(wm);
if wm_len > max_wm_len
    error('Error.\nMax watermark length is %d but your message is %d.', ...
        max_wm_len, wm_len);
end

% Feedback yessssss...
fprintf('\nEmbedding "%s" in %s.tiff variants\n\n', wm, im_base_name);
  
% Find the DCT of the image. We'll test different embedding placements!
im_Y_dct  = blockproc(double(im_Y),  [8 8], @(b) round(dct2(b.data)));
im_Cb_dct = blockproc(double(im_Cb), [8 8], @(b) round(dct2(b.data)));
im_Cr_dct = blockproc(double(im_Cr), [8 8], @(b) round(dct2(b.data)));
im_R_dct  = blockproc(double(im_R),  [8 8], @(b) round(dct2(b.data)));
im_G_dct  = blockproc(double(im_G),  [8 8], @(b) round(dct2(b.data)));
im_B_dct  = blockproc(double(im_B),  [8 8], @(b) round(dct2(b.data)));

% The watermark will be a string of characters and letters. Each character
% will be encoded as a digit 0 to 26 corresponding to its frequency in the
% english alphabet, as well as the numbers 0 to 9 in order, and space.
letter_freq = {' ', 'e', 't', 'a', 'o', 'i', 'n', 's', 'h', 'r', 'd', ...
    'l', 'c', 'u', 'm', 'w', 'f', 'g', 'y', 'p', 'b', 'v', 'k', 'j', ...
    'x', 'q', 'z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'};

% Create decimal values for each letter, where most frequent letters get 
% the smallest values.
offsets = (0:length(letter_freq)-1);

% Convert the decimal offsets to binary. Use base 6 since we have >32 values
binary_offsets = num2cell(dec2bin(offsets, 6), 2)';

% Map letters -> binary
letter_map = containers.Map(letter_freq, binary_offsets);

% Cast the phrase to lowercase to maximize map coverage
wm = lower(wm);

% Convert the watermark phrase to a binary sequence
wm_bin_seq = [];
for i = 1:length(wm)
    if letter_map.isKey(wm(i))
        % Append the binary value of the character to the sequence
        wm_bin_seq = [wm_bin_seq letter_map(wm(i))];
    else
        % Append a ' ' if the character isn't in our map
        wm_bin_seq = [wm_bin_seq letter_map(' ')];
    end
end

% Convert the sequence to a GF(2) polynomial (Galois Field, you dingus)
wm_bin_seq = str2num(reshape(wm_bin_seq, 1, [])')';

% Determine BCH correction code
% Have to pad up to valid (n,k) tuples for BCH codes
% See: https://www.mathworks.com/help/comm/ref/bchenc.html
wm_bin_seq = [wm_bin_seq zeros(1, bch_k - length(wm_bin_seq))];
wm_bch = bchenc(gf(wm_bin_seq, 1), bch_n, bch_k);


% Determine the set of coordinates that correspond to the top-left corner
% of each DCT block. The top left corner contains the largest DCT values
% and inserting the watermark into those spots minimizes the deterioration
% of image quality and increase of image size by maintaining the number of
% zero coefficients.
% YCbCr and RGB image are same size so we can reuse the points.
[Xs, Ys] = meshgrid((1:8:size(im_Y_dct,1)), (1:8:size(im_Y_dct,2)));
corners = [Xs(:) Ys(:)];

% Add the binary values to each block
for i = 1:length(wm_bch)
    if wm_bch(i) == 1
        offset = 2;
    else
        offset = 0;
    end

    coord = corners(i,:);
    x = coord(1,1); y = coord(1,2);
    im_Y_dct(x,y)  = im_Y_dct(x,y)  + offset;
    im_Cb_dct(x,y) = im_Cb_dct(x,y) + offset;
    im_Cr_dct(x,y) = im_Cr_dct(x,y) + offset;
    im_R_dct(x,y)  = im_R_dct(x,y)  + offset;
    im_G_dct(x,y)  = im_G_dct(x,y)  + offset;
    im_B_dct(x,y)  = im_B_dct(x,y)  + offset;
end

% Now using the watermark added DCT coefficients, construct and output the
% watermarked image as Watermarked.tiff
im_Y_idct  = blockproc(im_Y_dct,  [8 8], @(b) idct2(b.data));
im_Cb_idct = blockproc(im_Cb_dct, [8 8], @(b) idct2(b.data));
im_Cr_idct = blockproc(im_Cr_dct, [8 8], @(b) idct2(b.data));
im_R_idct  = blockproc(im_R_dct,  [8 8], @(b) idct2(b.data));
im_G_idct  = blockproc(im_G_dct,  [8 8], @(b) idct2(b.data));
im_B_idct  = blockproc(im_B_dct,  [8 8], @(b) idct2(b.data));

% Copy original source file to preserve all tiff metadata. It's a pain to write by hand..
im_Y_wm_name  = sprintf('%s%s_wm.tiff', im_base_name, 'Y');
im_Cb_wm_name = sprintf('%s%s_wm.tiff', im_base_name, 'Cb');
im_Cr_wm_name = sprintf('%s%s_wm.tiff', im_base_name, 'Cr');
copyfile(im_YCbCr_name, im_Y_wm_name)
copyfile(im_YCbCr_name, im_Cb_wm_name)
copyfile(im_YCbCr_name, im_Cr_wm_name)

y_out  = Tiff(im_Y_wm_name,  'r+');
cb_out = Tiff(im_Cb_wm_name, 'r+');
cr_out = Tiff(im_Cr_wm_name, 'r+');

write(y_out, uint8(im_Y_idct), im_Cb, im_Cr);
write(cb_out, im_Y, uint8(im_Cb_idct), im_Cr);
write(cr_out, im_Y, im_Cb, uint8(im_Cr_idct));

close(y_out);
close(cb_out);
close(cr_out);

% Writing RGB is much easier!
im_wm_R = im_RGB;
im_wm_R(:,:,1) = uint8(im_R_idct);
im_R_wm_name = sprintf('%s%s_wm.tiff', im_base_name, 'R');
imwrite(im_wm_R, im_R_wm_name);

im_wm_G = im_RGB;
im_wm_G(:,:,2) = uint8(im_G_idct);
im_G_wm_name = sprintf('%s%s_wm.tiff', im_base_name, 'G');
imwrite(im_wm_G,im_G_wm_name);

im_wm_B = im_RGB;
im_wm_B(:,:,3) = uint8(im_B_idct);
im_B_wm_name = sprintf('%s%s_wm.tiff', im_base_name, 'B');
imwrite(im_wm_B,im_B_wm_name);

% PSNR Comparisons!
fprintf('      source             wm image           psnr    ssim   \n');
fprintf('-----------------------------------------------------------\n');
printPSNR(im_YCbCr_name, im_Y_wm_name);
printPSNR(im_YCbCr_name, im_Cb_wm_name);
printPSNR(im_YCbCr_name, im_Cr_wm_name);
printPSNR(im_RGB_name, im_R_wm_name);
printPSNR(im_RGB_name, im_G_wm_name);
printPSNR(im_RGB_name, im_B_wm_name);

function printPSNR(src, wm)
    im_wm = imread(wm); im_src = imread(src);
    fprintf('%-20s %-20s %0.5f %0.5f\n',...
        src, wm, psnr(im_wm, im_src), ssim(im_wm, im_src));
end
