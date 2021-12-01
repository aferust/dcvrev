import std.stdio;
import std.math;

import dcv.io.image : imread, imwrite;
import dcv.core;
import dcv.io.image;
import dcv.plot;
import dcv.imgproc;
import dcv.tracking;

import mir.ndslice;

// requires dcv:core

int main(string[] args)
{
    Image img = imread("lena.png"); // read an image from filesystem.

    Slice!(float*, 3) imslice = img
        .sliced // slice image data
        .as!float // convert it to float
        .slice; // make a copy.
    
    auto gray = imslice.rgb2gray; // convert rgb image to grayscale
    
    auto gaussianKernel = gaussian!float(2, 5, 5); // create gaussian convolution kernel (sigma, kernel width and height)
    auto sobelXKernel = sobel!real(GradientDirection.DIR_X); // sobel operator for horizontal (X) gradients
    auto laplacianKernel = laplacian!double; // laplacian kernel, similar to matlabs fspecial('laplacian', alpha)
    auto logKernel = laplacianOfGaussian(1.0, 5, 5); // laplacian of gaussian, similar to matlabs fspecial('log', alpha, width, height)

    // perform convolution for each kernel
    auto blur = imslice.conv(gaussianKernel);
    auto xgrads = gray.conv(sobelXKernel);
    auto laplaceEdges = gray.conv(laplacianKernel);
    auto logEdges = gray.conv(logKernel);


    // calculate canny edges
    auto cannyEdges = gray.canny!ubyte(75);

    // perform bilateral blurring
    auto bilBlur = imslice.bilateralFilter!float(10.0f, 5.0f, 9);

    // Add salt and pepper noise at input image green channel
    auto noisyImage = imslice.slice;
    auto saltNPepperNoise = noisyImage[0 .. $, 0 .. $, 1].saltNPepper(0.15f);
    // ... and perform median blurring on noisy image
    auto medBlur = noisyImage.medianFilter(5);

    // scale values from 0 to 255 to preview gradient direction and magnitude
    xgrads.ranged(0, 255);
    // Take absolute values and range them from 0 to 255, to preview edges
    laplaceEdges = laplaceEdges.map!(a => fabs(a)).slice.ranged(0.0f, 255.0f);
    logEdges = logEdges.map!(a => fabs(a)).slice.ranged(0.0f, 255.0f);

    // Show images on screen
    img.imshow("Original");
    bilBlur.imshow("Bilateral Blurring");
    noisyImage.imshow("Salt and Pepper noise at green channel for Median");
    medBlur.imshow("Median Blurring");
    blur.imshow("Gaussian Blurring");
    xgrads.imshow("Sobel X");
    laplaceEdges.imshow("Laplace");
    logEdges.imshow("Laplacian of Gaussian");
    cannyEdges.imshow("Canny Edges");

    waitKey();

    return 0;
}

auto saltNPepper(T, SliceKind kind)(Slice!(T*, 2LU, kind) input, float saturation)
{
    import std.range : lockstep;
    import std.random : uniform;

    int err;
    ulong pixelCount = input.length!0*input.length!1;
    ulong noisyPixelCount = cast(typeof(pixelCount))(pixelCount * saturation);

    auto noisyPixels = slice!size_t(noisyPixelCount);
    foreach(ref e; noisyPixels)
    {
        e = uniform(0, pixelCount);
    }

    auto imdata = input.reshape([pixelCount], err);

    assert(err == 0);

    foreach(salt, pepper; lockstep(noisyPixels[0 .. $ / 2], noisyPixels[$ / 2 .. $]))
    {
        imdata[salt] = cast(T)255;
        imdata[pepper] = cast(T)0;
    }
    return input;
}