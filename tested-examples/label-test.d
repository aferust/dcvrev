
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

    auto sw = StopWatch(AutoStart.no);
    sw.start();
    auto labels = bwlabel(imbin);
    sw.stop(); long msecs = sw.peek.total!"msecs";
    writefln("%f", msecs);
    
    // need a label2image function to visualize the results
    // because ubyte is not enough for the number of regions larger than 256
    // and small labels like 1,2,3 is not visible
    auto lim = labels.as!ubyte.slice.asImage(ImageFormat.IF_MONO); 

    imwrite("labels_out.png", lim.width, lim.height, lim.format, lim.depth, lim.data!ubyte);

    imshow(imbin, "otsu");
    imshow(lim, "labels"); // todo: label2image
    
    waitKey();

    return 0;
}