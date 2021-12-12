module dcv.measure.convexhull;

/* https://rosettacode.org/wiki/Convex_hull 
   https://www.gnu.org/licenses/fdl-1.2.html
*/
import std.math;

import mir.ndslice.sorting: sort;
import mir.ndslice;
import mir.rc;
import mir.appender;

struct Coord {
    size_t x, y;

    int opCmp(Coord rhs) @nogc nothrow {
        if (x < rhs.x) return -1;
        if (rhs.x < x) return 1;
        return 0;
    }
}

auto convexHull(C)(C contour) @nogc nothrow
{
    //assert( n >= 3, "Convex hull not possible");

    const n = contour.shape[0];

    auto _p = RCArray!Coord(n);
    
    foreach(i; 0..n)
        _p[i] = Coord(cast(size_t)contour[i, 0].round, cast(size_t)contour[i, 1].round);
    
    auto p = sort(_p[]);

    auto h = scopedBuffer!Coord;
 
    // lower hull
    foreach (pt; p) {
        while (h.length >= 2 && !ccw(h.data[$-2], h.data[$-1], pt)) {
            h.popBackN(1);
        }
        h.put(pt);
    }
 
    // upper hull
    const t = h.length + 1;
    foreach_reverse (i; 0..(p.length - 1)) {
        auto pt = p[i];
        while (h.length >= t && !ccw(h.data[$-2], h.data[$-1], pt)) {
            h.popBackN(1);
        }
        h.put(pt);
    }
 
    h.popBackN(1);
    
    Slice!(RCI!size_t, 2LU, Contiguous) hull = uninitRCslice!(size_t)(h.length, 2);
    
    hull._iterator[0..h.length*2][] = (cast(size_t*)h.data[].rcarray.ptr)[0..h.length*2];

    return hull;
}
 
/* ccw returns true if the three points make a counter-clockwise turn */
pragma(inline, true)
private auto ccw(Coord a, Coord b, Coord c) @nogc nothrow {
    return ((b.x - a.x) * (c.y - a.y)) > ((b.y - a.y) * (c.x - a.x));
}