% Watermark Encoder
% Based on step-by-step.mlx
% Takes a source image and a watermarking phrase as input
% Creates an invisibly DCT watermarked image as output
%--------------------------------------------------------------------------

function wm_encoder

clearvars;

% Read an image as input.
cimage = input('Image to Watermark: ','s');
im = imread(cimage);

% Read a string as watermark.
wm = input('Watermark Message (letters and numbers only): ','s');

% Define the standard quantization matrix for compression.
QP = [16  11  10  16  24  40  51  61;
      12  12  14  19  26  58  60  55;
      14  13  16  24  40  57  69  56;
      14  17  22  29  51  87  80  62;
      18  22  37  56  68 109 103  77;
      24  35  55  64  81 104 113  92;
      49  64  78  87 103 121 120 101;
      72  92  95  98 112 100 103  99];
  
% Find the DCT of the image.
im_dct = blockproc(double(im), [8 8], @(b) round(dct2(b.data)));
 
% Scale the quantization matrix by a scale factor,then scale the dct values
% with it.
scale_f = 0.5;
QP_scale = QP .* scale_f;
quant_dct= @(block_struct) round(block_struct.data ./ QP_scale)...
    .* QP_scale;
im_quant = blockproc(im_dct, [8 8], quant_dct);

% The watermark will be a string of characters and letters. Each character
% will be encoded as a digit 0 to 26 corresponding to its frequency in the
% english alphabet, as well as the numbers 0 to 9 in order, and space.
letter_freq = {' ', 'e', 't', 'a', 'o', 'i', 'n', 's', 'h', 'r', 'd', ...
    'l', 'c', 'u', 'm', 'w', 'f', 'g', 'y', 'p', 'b', 'v', 'k', 'j', ...
    'x', 'q', 'z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'};

% Use a Matlab map container to map all the letter with a corresponding
% numerical value (26 letters, 10 numbers, 1 space).
letter_offsets = containers.Map(letter_freq, (0:length(letter_freq)-1));

% Convert the user inserted watermark phrase into lower case, then use the
% map to convert it to a set of minimal offsets.
wm = lower(wm);

offsets = zeros(size(wm));
for i = 1:length(wm)
    if letter_offsets.isKey(wm(i))
        offsets(i) = letter_offsets(wm(i));
    else
        offsets(i) = 0;
    end
end

% Determine the set of coordinates that correspond to the top-left corner
% of each DCT block. The top left corner contains the largest DCT values
% and inserting the watermark into those spots minimizes the deterioration
% of image quality and increase of image size by maintaining the number of
% zero coefficients.
[Xs, Ys] = meshgrid((1:8:size(im_quant,1)), (1:8:size(im_quant,2)));
corners = [Xs(:) Ys(:)];

% Add the encoded values to each block.
for i = 1:length(offsets)
    coord = corners(i,:);
    x = coord(1,1); y = coord(1,2);
    im_quant(x,y) = im_quant(x,y) + offsets(1,i);
end

% Now using the watermark added DCT coefficients, construct and output the
% watermarked image as Watermarked.tiff
im_idct = blockproc(im_quant, [8 8], @(b) idct2(b.data));
imwrite(uint8(im_idct),'Watermarked.tiff');
disp('Watermarked.tiff was created')
