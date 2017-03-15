% Watermark Decoder
% Based on step-by-step.mlx
% Takes an original image and a watermarked image as input
% Extracts the watermark phrase as output
%--------------------------------------------------------------------------

function wm_decoder

% Read the original image as input.
%cimage = input('Original Image: ','s');
%im_org = imread(cimage);
im_org=imread('lena.tiff');
im_wm=imread('Watermarked.tiff');

% Read the watermarked image as input.
%cimage = input('Watermarked Image: ','s');
%im_wm = imread(cimage);

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

% Create a reverse mapping of letters to values, based on the container
% map created in wm_encoder.m
letter_freq = {' ', 'e', 't', 'a', 'o', 'i', 'n', 's', 'h', 'r', 'd', ...
    'l', 'c', 'u', 'm', 'w', 'f', 'g', 'y', 'p', 'b', 'v', 'k', 'j', ...
    'x', 'q', 'z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'};

% Forward map.
letter_offsets = containers.Map(letter_freq, (0:length(letter_freq)-1));

% Reverse lookup map.
offset_letters = containers.Map(values(letter_offsets), ...
    keys(letter_offsets));

% Extract the watermark by running the offsets through the inverse map.
phrase = '';
for i = 1:length(wm_offsets)
    offset = wm_offsets(1,i);
    if offset_letters.isKey(offset)
        phrase = strcat(phrase, offset_letters(offset));
    end
end

% Print the extracted watermark to the console
disp(phrase);
