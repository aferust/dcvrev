
import std.stdio;
import std.typecons : tuple, Tuple;

import dcv.core;
import dcv.io.image;
import dcv.plot;
import dcv.imgproc;
import dcv.measure;

import mir.ndslice;
import mir.rc;


// Draw convexhull of randomly-generated points

int main(string[] args)
{
    import std.random;
    
    enum nPoints = 20;

    immutable size_t imWidth = 800;
    immutable size_t imHeight = 800;
    immutable size_t margin = 80;

    immutable ubyte[3] green = [0, 255, 0];
    immutable ubyte[3] red = [255, 0, 0];
    immutable ubyte[3] blue = [0, 0, 255];

    struct Circle {size_t x, y, r;}

    // create an empty image
    Slice!(RCI!ubyte, 3LU, Contiguous) img = uninitRCslice!ubyte(imHeight, imWidth, 3);
    
    for(;;){
        img[] = 0;

        // Generate random points
        Slice!(RCI!size_t, 2LU, Contiguous) points = uninitRCslice!size_t(nPoints, 2);

        auto gen = Random(unpredictableSeed);
        
        foreach (i; 0..nPoints)
        {
            size_t x = uniform!"[]"(margin, imWidth - margin, gen);
            size_t y = uniform!"[]"(margin, imWidth - margin, gen);
            points[i, 0] = x;
            points[i, 1] = y;

            // plot the points
            plotCircle(img, Circle(cast(size_t)x, cast(size_t)y, 5), green);
        }
        
        // compute point indices of the convex hull
        auto chull_indices = convexHull(points);
        
        // scatter points of the convex hull on an empty image
        foreach(index; chull_indices)
            plotCircle(img, Circle(points[index, 0], points[index, 1], 5), red);

        // draw hull lines
        foreach (i; 0 .. chull_indices.length -1){
            auto p1 = Point(points[chull_indices[i], 0], points[chull_indices[i], 1]);
            auto p2 = Point(points[chull_indices[i+1], 0], points[chull_indices[i+1], 1]);
            plotLine(img, tuple(p1, p2), blue);
        }
        auto p1 = Point(points[chull_indices[0], 0], points[chull_indices[0], 1]);
        auto p2 = Point(points[chull_indices[$-1], 0], points[chull_indices[$-1], 1]);
        plotLine(img, tuple(p1, p2), blue);

        // show image
        imshow(img, "img");
        
        int key = waitKey();
        if(key == cast(int)'q' || key == cast(int)'Q' ) // 0 = 'ESC'
            break;
    }

    return 0;
}

struct Point {size_t x, y;}

void plotLine(ImType, Color)(ImType img, Tuple!(Point, Point) line, Color color)
{
    // need some fix for vertical lines
    
    int height = cast(int)img.length!0;
    int width = cast(int)img.length!1;
    
    double x1 = cast(double)line[0].x;
    double x2 = cast(double)line[1].x;
    double y1 = cast(double)line[0].y;
    double y2 = cast(double)line[1].y;

    double dx = x1 - x2;
    double dy = y1 - y2;
    auto m = dy/dx;
    auto b = y1 - m * x1;

    if (m == double.infinity)
    {
        auto x = b;
        if (x >= 0 && x < width)
            foreach (y; 0 .. height)
            {
                img[cast(int)y, cast(int)x, 0 .. 3] = color;
            }
    }
    else
    {
        foreach (x; 0 .. 1000)
        {
            auto y = m * x + b;
            if (x >= 0 && x < width && y >= 0 && y < height)
            {
                img[cast(int)y, cast(int)x, 0 .. 3] = color;
            }
        }
    }
}

void plotCircle(ImType, Circle, Color)(ImType img, Circle circle, Color color)
{
    import std.math;

    int height = cast(int)img.length!0;
    int width = cast(int)img.length!1;
    
    // quick and dirty circle plot
    foreach (t; 0 .. 360)
    {
        int x = cast(int)(circle.x + circle.r * cos(t * PI / 180));
        int y = cast(int)(circle.y + circle.r * sin(t * PI / 180));
        if (x >= 0 && x < width && y >= 0 && y < height)
            img[y, x, 0 .. 3] = color;
    }
}