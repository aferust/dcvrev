
import std.stdio;
import dcv.io.image : imread, imwrite;

import dcv.core;
import dcv.io.image;
import dcv.plot;
import dcv.imgproc;

import mir.ndslice;

import std.datetime.stopwatch;

int main(string[] args)
{
    Image img = imread("test_labels.png");

    Slice!(ubyte*, 2) gray = img.sliced.rgb2gray;
    auto hist = calcHistogram(gray.flattened);
    auto thr = getOtsuThresholdValue(hist);
    auto imbin = threshold!ubyte(gray, cast(ubyte)thr);

    
    auto labels = bwlabel(imbin);
    
    auto labelimg = label2rgb(labels); // a nice util to visualize the label matrix

    imshow(labelimg.asImage, "labelimg"); 
    
    waitKey();

    return 0;
}