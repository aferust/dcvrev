module dcv.measure.contours;

import std.typecons: Tuple, tuple;
import std.container.dlist: DList;
import core.lifetime: move;

import mir.ndslice;
import mir.rc;

// based on https://github.com/scikit-image/scikit-image/blob/main/skimage/measure/_find_contours.py

struct Point {
    double x, y;
}

/** Find iso-valued contours in a 2D array for a given level value.

Params:
    image = Input binary image of ubyte (0 for background). Agnostic to SliceKind
*/
RCArray!Contour findContours(InputType)(auto ref InputType image, double level = defaultLevel, bool fullyConnected = true)
{
    if (level == -1.0)
        level = _defaultLevel(image);
    
    auto segments = _get_contour_segments(image.as!double, level, fullyConnected);
    auto contours = _assemble_contours(segments);

    return contours.move;
}

private enum defaultLevel = -1.0;

private double _defaultLevel(InputType)(auto ref InputType image)
{
    auto min_index = image.minIndex;
    auto max_index = image.maxIndex;
    return (image[min_index[0], min_index[1]] + image[max_index[0], max_index[1]] ) / 2.0;
}

pragma(inline, true)
private double _get_fraction(double from_value, double to_value, double level)
{
    if (to_value == from_value)
        return 0;
    return ((level - from_value) / (to_value - from_value));
}

auto _get_contour_segments(InputType)
(
    InputType array,
    double level,
    bool vertex_connect_high)
{

    import std.array;

    auto segments = appender!(Tuple!(Point, Point)[])(); segments.reserve(512);

    ubyte square_case = 0;
    Point top, bottom, left, right;
    double ul, ur, ll, lr;
    size_t r1, c1;

    foreach(r0; 0 .. array.shape[0] - 1){
        foreach(c0; 0 .. array.shape[1] - 1){
            r1 = r0 + 1;
            c1 = c0 + 1;

            ul = array[r0, c0];
            ur = array[r0, c1];
            ll = array[r1, c0];
            lr = array[r1, c1];

            square_case = 0;
            if (ul > level) square_case += 1;
            if (ur > level) square_case += 2;
            if (ll > level) square_case += 4;
            if (lr > level) square_case += 8;

            if ((square_case == 0) || (square_case == 15))
                // only do anything if there's a line passing through the
                // square. Cases 0 and 15 are entirely below/above the contour.
                continue;

            top = Point(r0, c0 + _get_fraction(ul, ur, level));
            bottom = Point(r1, c0 + _get_fraction(ll, lr, level));
            left = Point(r0 + _get_fraction(ul, ll, level), c0);
            right = Point(r0 + _get_fraction(ur, lr, level), c1);

            if (square_case == 1)
                // top to left
                segments.put(tuple(top, left));
            else if (square_case == 2)
                // right to top
                segments.put(tuple(right, top));
            else if (square_case == 3)
                // right to left
                segments.put(tuple(right, left));
            else if (square_case == 4)
                // left to bottom
                segments.put(tuple(left, bottom));
            else if (square_case == 5)
                // top to bottom
                segments.put(tuple(top, bottom));
            else if (square_case == 6){
                if (vertex_connect_high){
                    segments.put(tuple(left, top));
                    segments.put(tuple(right, bottom));
                }else{
                    segments.put(tuple(right, top));
                    segments.put(tuple(left, bottom));
                }
            }
            else if (square_case == 7)
                // right to bottom
                segments.put(tuple(right, bottom));
            else if (square_case == 8)
                // bottom to right
                segments.put(tuple(bottom, right));
            else if (square_case == 9){
                if (vertex_connect_high){
                    segments.put(tuple(top, right));
                    segments.put(tuple(bottom, left));
                }else{
                    segments.put(tuple(top, left));
                    segments.put(tuple(bottom, right));
                }
            }
            else if (square_case == 10)
                // bottom to top
                segments.put(tuple(bottom, top));
            else if (square_case == 11)
                // bottom to left
                segments.put(tuple(bottom, left));
            else if (square_case == 12)
                // lef to right
                segments.put(tuple(left, right));
            else if (square_case == 13)
                // top to right
                segments.put(tuple(top, right));
            else if (square_case == 14)
                // left to top
                segments.put(tuple(left, top));
        }
    }
    return segments[];
}

auto _assemble_contours(Tuple!(Point, Point)[] segments){ 
    import std.range;
    import std.algorithm.comparison : equal;

    size_t current_index = 0;
    
    alias DLP = DList!(Point);
    
    DLP[size_t] contours;
    
    Tuple!(DLP, size_t)[Point] starts;
    Tuple!(DLP, size_t)[Point] ends;

    foreach(tupelem; segments){
        Point from_point = tupelem[0];
        Point to_point = tupelem[1];

        // Ignore degenerate segments.
        // This happens when (and only when) one vertex of the square is
        // exactly the contour level, and the rest are above or below.
        // This degenerate vertex will be picked up later by neighboring
        // squares.
        if (from_point == to_point)
            continue;
        
        DLP tail;
        size_t tail_num;
        
        if (auto tuptail = to_point in starts){
            tail = (*tuptail)[0];
            tail_num = (*tuptail)[1];
            starts.remove(to_point);
        }

        DLP head;
        size_t head_num;
        
        if (auto tuphead = from_point in ends){
            head = (*tuphead)[0];
            head_num = (*tuphead)[1];
            ends.remove(from_point);
        }

        if ((!tail[].empty) && (!head[].empty)){
            // We need to connect these two contours.
            if (tail[].equal(head[])){
                // We need to closed a contour: add the end point
                head.insertBack(to_point);
            }    
            else{  // tail is not head
                // We need to join two distinct contours.
                // We want to keep the first contour segment created, so that
                // the final contours are ordered left->right, top->bottom.
                if (tail_num > head_num){
                    // tail was created second. Append tail to head.
                    head.insertBack(tail[]);
                    // Remove tail from the detected contours
                    
                    contours.remove(tail_num);
                    // Update starts and ends
                    starts[head[].front] = tuple(head, head_num);
                    ends[head[].back] = tuple(head, head_num);
                }else{  // tail_num <= head_num
                    // head was created second. Prepend head to tail.
                    tail.insertFront(head[]);
                    // Remove head from the detected contours
                    starts.remove(head[].front); // head[0] can be == to_point!
                    contours.remove(head_num);
                    // Update starts and ends
                    starts[tail[].front] = tuple(tail, tail_num);
                    ends[tail[].back] = tuple(tail, tail_num);
                }
            }
        }
        else if((tail[].empty) && (head[].empty)) {
            // We need to add a new contour
            DLP new_contour = DList!Point(from_point, to_point);

            if(auto eptr = current_index in contours){
                eptr.insertBack(new_contour[]);
            }else{
                contours[current_index] = new_contour;
            }
            starts[from_point] = tuple(new_contour, current_index);
            ends[to_point] = tuple(new_contour, current_index);
            current_index ++;
        }
        else if(head[].empty){  // tail is not None
            // tail first element is to_point: the new segment should be
            // prepended.
            tail.insertFront(from_point);
            // Update starts
            starts[from_point] = tuple(tail, tail_num);
        } else {
            // tail is None and head is not None:
            // head last element is from_point: the new segment should be
            // appended
            head.insertBack(to_point);
            // Update ends
            ends[to_point] = tuple(head, head_num);
        }
        
    }

    import std.algorithm.sorting : sort;
    import std.array : staticArray;

    auto cts = RCArray!Contour(contours.length);
    size_t i;

    foreach (k; contours.keys.sort) // TODO: parallelizm here?
    {
        auto _c = contours[k][].rcarray!Point;
        auto len = _c.length;
        Contour ctr = uninitRCslice!(double)(len, 2);
        
        ctr._iterator[0..len*2][] = (cast(double*)_c.ptr)[0..len*2];
        
        cts[i++] = ctr;
    }

    return cts.move;
}

alias Contour = Slice!(RCI!double, 2LU, Contiguous);

auto contours2image(RCArray!Contour contours, size_t rows, size_t cols)
{

    Slice!(RCI!ubyte, 2LU, Contiguous) cimg = uninitRCslice!ubyte(rows, cols);
    cimg[] = 0;

    contours[].each!((cntr){ // TODO: parallelizm here?
        foreach(p; cntr){
            cimg[cast(size_t)p[0], cast(size_t)p[1]] = 255;
        }
    });

    return cimg.move;
}