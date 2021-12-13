
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
    Image img = imread("../data/test_labels.png");

    Slice!(ubyte*, 2) gray = img.sliced.rgb2gray;
    auto hist = calcHistogram(gray.flattened);
    
    auto thr = getOtsuThresholdValue(hist);
    
    auto imbin = threshold!ubyte(gray, cast(ubyte)thr);
    
    auto labels = bwlabel(imbin);

    auto cntrs = findContours(imbin);
    
    foreach(contour; cntrs){
        auto moments = calculateMoments(contour, imbin);
        writeln("Orientation: ", ellipseFit(moments).angle);
        writeln("convexHull: ", convexHull(contour));
        writeln("Area: ", moments.m00); // or contour.contourArea
        writeln("Perimeter: ", contour.arcLength);
    }
    
    auto labelimg = label2rgb(labels); // a nice util to visualize the label matrix
    auto cimg = contours2image(cntrs, imbin.shape[0], imbin.shape[1]);

    imshow(cimg, "cimg");
    imshow(labelimg, "labelimg");
    
    waitKey();
    
    return 0;
}