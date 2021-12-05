module dcv.imgproc.label;

import std.typecons: tuple, Tuple;
import std.experimental.allocator.gc_allocator;
import std.array : Appender;

import mir.ndslice;
import mir.ndslice.allocation;

/+
private alias Point = Tuple!(ulong, "x", ulong, "y");

struct XYList {
    Appender!(ulong[]) xs;
    Appender!(ulong[]) ys;
}
+/
private struct Labelizer 
{
    
    Slice!(ubyte*, 2LU, SliceKind.contiguous) input;
    
    size_t w, h;
    ulong[] component;

    auto labelize(alias adjacency = conn8)(ref Slice!(ubyte*, 2LU, SliceKind.contiguous) input)
    {   
        // gives coordinates of connected components
        /+XYList[] coords;+/
        this.input = input;
        w = input.shape[0];
        h = input.shape[1];

        auto label = makeUninitSlice!ulong(GCAllocator.instance, input.shape[0..2]);
        
        import core.stdc.stdlib;
        component = cast(ulong[])malloc(w*h * ulong.sizeof)[0..w*h * ulong.sizeof];
        scope(exit) free(cast(void*)component.ptr);
        
        foreach (i; 0..w*h)
            component[i] = i;
        foreach (x; 0..w)
            foreach (y; 0..h)
                adjacency(x, y);
        
        /+XYList[ulong] pmap;+/
        
        foreach (x; 0..w)
        {
            foreach (y; 0..h)
            {
                if (input[x][y] == 0)
                {
                    continue;
                }
                ulong c = x*h + y;
                while (component[c] != c) c = component[c];
                /+
                if(c !in pmap)
                {
                    XYList tmp;
                    tmp.xs.reserve(10);
                    tmp.ys.reserve(10);
                    tmp.xs ~= x;
                    tmp.ys ~= y;
                    pmap[c] = tmp;
                }else{
                    pmap[c].xs ~= x;
                    pmap[c].ys ~= y;
                }
                +/
                label[x][y] = c;
            }
        }
        
        return label;
    }

    private:

    void doUnion(ulong a, ulong b) @nogc nothrow
    {
        while (component[a] != a)
            a = component[a];
        while (component[b] != b)
            b = component[b];
        component[b] = a;
    }

    void unionCoords(ulong x, ulong y, ulong x2, ulong y2) @nogc nothrow
    {
        if (y2 < h && x2 < w && input[x][y] && input[x2][y2])
            doUnion(x*h + y, x2*h + y2);
    }

    void conn8(ulong x, ulong y) @nogc nothrow
    {
        unionCoords(x, y, x+1, y);
        unionCoords(x, y, x, y+1);
        unionCoords(x, y, x+1, y+1);
    }

    void conn4(ulong x, ulong y) @nogc nothrow
    {
        unionCoords(x, y, x+1, y);
        unionCoords(x, y, x, y+1);
    }
}

Slice!(ulong*, 2LU, SliceKind.contiguous)
bwlabel(Slice!(ubyte*, 2LU, SliceKind.contiguous) img){
    Labelizer lblzr;
    return lblzr.labelize(img);
}
