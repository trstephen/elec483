% Watermark Decoder
% Based on step-by-step.mlx
% Takes an original image and a watermarked image as input
% Extracts the watermark phrase as output
%--------------------------------------------------------------------------

function wm_decoder
% Read the watermarked and original images
cimage = input('Watermarked image: ', 's');
im_wm  = imread(cimage);

cimage = input('Original Image: ','s');
im_org = imread(cimage);

% Find the DCT coefficients of both images.
im_org_dct = blockproc(double(im_org), [8 8], @(b) round(dct2(b.data)));
im_wm_dct = blockproc(double(im_wm), [8 8], @(b) round(dct2(b.data)));

% Determine the set of coordinates that correspond to the top-left corner
% of each DCT block, using the original image.
[Xs, Ys] = meshgrid((1:8:size(im_org_dct,1)), (1:8:size(im_org_dct,2)));
corners = [Xs(:) Ys(:)];

% Subtract the original image from the watermarked image to extract the
% added watermark coefficients.
diff = im_wm_dct - im_org_dct;

% Extract the watermark offsets from the corners of the DCT blocks.
wm_offsets = zeros(1, length(corners));
for i = 1:length(corners)
    coord = corners(i,:);
    x = coord(1,1); y = coord(1,2);
    wm_offsets(1,i) = diff(x,y);
end

% If error occured in IDCT it is biased to decreasing the value. Since we
% originally mapped '1' -> 2 and '0' -> 0 we want the unmapping to be
% -1,0 -> '0' and 1, 2 -> '1'
for i = 1:length(wm_offsets)
    if wm_offsets(i) > 0
        wm_offsets(i) = 1;
    else
        wm_offsets(i) = 0;
    end
end

% Set the parameters of the BCH code. These _must_ match wm_encoder.m!
bch_n = 255; bch_k = 199; word_size = 6;

% Truncate the corner values that aren't part of the BCH code
wm_offsets = wm_offsets(1:bch_n);

% Do the decode
wm_bch_dec = bchdec(gf(wm_offsets, 1), bch_n, bch_k);

% Remove the padding bits
max_wm_len = floor(bch_k / word_size);
wm_dec = wm_bch_dec(1:(max_wm_len * word_size));

% Group the elements in our decoded vector into 6bit binary words.
% Convert the words to their decimal value for use in the dec -> char map.
dec_offsets = zeros(1, max_wm_len);
for i = 1:max_wm_len
    first_bit = (i-1)*word_size + 1;
    last_bit = first_bit + (word_size-1);
    word = wm_dec(first_bit:last_bit);
    dec_offsets(i) = bin2dec(dec2bin(word.x)'); % vector of 0/1 -> binary char vector -> decimal
end

% Create a reverse mapping of letters to values, based on the container
% map created in wm_encoder.m
letter_freq = {' ', 'e', 't', 'a', 'o', 'i', 'n', 's', 'h', 'r', 'd', ...
    'l', 'c', 'u', 'm', 'w', 'f', 'g', 'y', 'p', 'b', 'v', 'k', 'j', ...
    'x', 'q', 'z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'};

% Reverse lookup map.
offset_letters = containers.Map((0:length(letter_freq)-1), letter_freq);

% Extract the watermark by running the offsets through the inverse map.
phrase = '';
for i = 1:length(dec_offsets)
    offset = dec_offsets(1,i);
    if offset_letters.isKey(offset)
        phrase = strcat(phrase, offset_letters(offset));
    end
end

% Print the extracted watermark to the console
disp(phrase);
