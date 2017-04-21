ELEC 483
====

Add a nifty digital watermark to an image by massaging the DCT coefficients. Adding a watermark results in almost no image quality degradation.

Be sneaky and use it to pass messages!

#### Usage
1. _Encoding_: Call `wm_encoder` in MATLAB. Give it an image and phrase (up to 33 characters) when prompted.
1. _Decoding_: Call `wm_decoder`. Give it the watermarked _and original_ image. Maybe v2 will be able to do a blind extraction and decode.

You can read the [report](./report/report.pdf) for a lengthy explanation of how it works.
