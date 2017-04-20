% Watermark Encoder
% Based on step-by-step.mlx
% Takes a source image and a watermarking phrase as input
% Creates an invisibly DCT watermarked image as output
%--------------------------------------------------------------------------

function wm_encoder

% Read an image as input.
cimage = input('Image to Watermark: ','s');
im = imread(cimage);

% Read a string as watermark.
wm = input('Watermark Message: ','s');

% Validate length of message. We'll be using a BCH code with
% n = 255, k = 199 that can correct 7 errors (2.7451% error rate).
% Need make sure the message is < 199 mod 6 == 33 characters since
% we'll be mapping characters to 6 bit binary sequences.
bch_n = 255; bch_k = 199; word_size = 6;
max_wm_len = floor(bch_k / word_size);

wm_len = length(wm);
if wm_len > max_wm_len
    error('Error.\nMax watermark length is %d but your message is %d.', ...
        max_wm_len, wm_len);
end

% Isolate the layer that will hold the watermark. If grayscale, this is the entire image.
% If RGB, this will be R. (imread will always read image as RGB, even if source is YCbCr.)
im_wm_layer = im(:,:,1);
  
% Find the DCT of the image.
im_dct = blockproc(double(im_wm_layer), [8 8], @(b) round(dct2(b.data)));


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
binary_offsets = num2cell(dec2bin(offsets, word_size), 2)';

% Map letters -> binary
letter_map = containers.Map(letter_freq, binary_offsets);

% Convert the user inserted watermark phrase into lower case, then use the
% map to convert it to a set of minimal offsets.
wm = lower(wm);

% Convert the watermark phrase to a binary sequence
% TODO: Preallocate space to satisfy warning.
%       This is a bit tricky because I have to block-assign values
%       to wm_bin_seq, which I don't think is possible??
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

% We have a 6x(num chars) matrix that needs to be converted into a 1x(6 x num chars) vector
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
[Xs, Ys] = meshgrid((1:8:size(im_dct,1)), (1:8:size(im_dct,2)));
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
    im_dct(x,y) = im_dct(x,y) + offset;
end

% Now using the watermark added DCT coefficients, construct and output the
% watermarked image as Watermarked.tiff
im_idct = blockproc(im_dct, [8 8], @(b) idct2(b.data));

% Write the watermarked layer back into the original image.
im(:,:,1) = im_idct;
imwrite(uint8(im),'Watermarked.tiff');
disp('Watermarked.tiff was created')
