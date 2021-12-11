
import std.stdio;
import dcv.io.image : imread, imwrite;

import dcv.core;
import dcv.io.image;
import dcv.plot;
import dcv.imgproc;
import dcv.measure;

import mir.ndslice;

int main(string[] args)
{
    Image img = imread("test_labels.png");

    Slice!(ubyte*, 2) gray = img.sliced.rgb2gray;
    auto hist = calcHistogram(gray.flattened);
    auto thr = getOtsuThresholdValue(hist);
    auto imbin = threshold!ubyte(gray, cast(ubyte)thr);
    
    auto cntrs = findContours(imbin);

    auto cimg = contours2image(cntrs, imbin.shape[0], imbin.shape[1]);

    imshow(cimg, "cimg");
    
    waitKey();
    
    return 0;
}

