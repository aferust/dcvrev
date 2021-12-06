/**
Module for labelling connected regions of a binary image slice.
Copyright: Copyright Ferhat Kurtulmuş 2021.
Authors: Ferhat Kurtulmuş
License: $(LINK3 http://www.boost.org/LICENSE_1_0.txt, Boost Software License - Version 1.0).
*/
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

private struct LabelizerV1 
{

    Slice!(ubyte*, 2LU, SliceKind.contiguous) img;
    Slice!(ulong*, 2LU, SliceKind.contiguous) label;

    size_t row_count;
    size_t col_count;

    static immutable byte[4] dx4 = [1, 0, -1,  0];
    static immutable byte[4] dy4 = [0, 1,  0, -1];

    static immutable byte[8] dx8 = [1, -1, 1, 0, -1,  1,  0, -1];
    static immutable byte[8] dy8 = [0,  0, 1, 1,  1, -1, -1, -1];

    private void dfs(alias Conn)(ulong i, ulong j, ulong current_label)
    {
        import std.container : SList;
        import std.range;

        SList!ulong stack;

        stack.insertFront(i);
        stack.insertFront(j);
        
        while(!stack.empty){

            ulong arg_j = stack[].front; stack.removeFront();
            ulong arg_i = stack[].front; stack.removeFront();

            if (arg_i< 0 || arg_i == row_count) return; // out of bounds
            if (arg_j < 0 || arg_j == col_count) return; // out of bounds
            if (label[arg_i][arg_j] || !img[arg_i][arg_j]) continue; // already labeled or not marked with a number in input

            label[arg_i][arg_j] = current_label;
            
            import std.format;

            foreach(direction; 0..Conn){
                mixin("auto ni = arg_i + " ~ format("dx%d[direction];", Conn));
                mixin("auto nj = arg_j + " ~ format("dy%d[direction];", Conn));

                if (label[ni][nj] || !img[ni][nj]) continue;
                stack.insertFront(ni);
                stack.insertFront(nj);
            }
        }

        stack.clear();
    }

    auto labelize(alias Conn, SliceKind kind)(Slice!(ubyte*, 2LU, kind) img)
    {
        /* The algorithm is based on:
        * https://stackoverflow.com/questions/14465297/connected-component-labelling
        */
        this.img = img;
        
        row_count = img.shape[0];
        col_count = img.shape[1];
        
        label = makeUninitSlice!ulong(GCAllocator.instance, img.shape[0..2]);
        
        ulong component = 0;
        foreach (i; 0..row_count) 
            foreach (j; 0..col_count)
                if (!label[i][j] && img[i][j])
                    dfs!(Conn)(i, j, ++component);
        
        return label;     
    }
}

// WARNING !!! Output labels are not sequential with this method
private struct LabelizerV2
{
    Slice!(ubyte*, 2LU, SliceKind.contiguous) input;
    
    size_t w, h;
    ulong[] component;

    auto labelize(alias Conn, SliceKind kind)(ref Slice!(ubyte*, 2LU, kind) input)
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
                conn!(Conn)(x, y);
        
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

    void conn(alias Conn)(ulong x, ulong y) @nogc nothrow
    {
        static if(Conn == 4){
            unionCoords(x, y, x+1, y);
            unionCoords(x, y, x, y+1);
        }else
        static if(Conn == 8){
            unionCoords(x, y, x+1, y);
            unionCoords(x, y, x, y+1);
            unionCoords(x, y, x+1, y+1);
        }
    }
}
/**
Label connected components in 2-D binary image

Params:
    input = Input slice of 2-D binary image (Slice!(ubyte*, 2LU, SliceKind.contiguous)) .
*/
Slice!(ulong*, 2LU, SliceKind.contiguous)
bwlabel(alias Conn = 8, alias Method = 1, SliceKind kind)(Slice!(ubyte*, 2LU, kind) input)
in
{
    assert(Conn == 4 && Conn == 8, "Connection rule must be either of 4 or 8");
    assert(Method == 1 && Conn == 2, "Method must be either of 1 or 2");
}
do
{
    static if(Method == 1){
        LabelizerV1 lblzr;
    }else
    static if(Method == 2){
        LabelizerV2 lblzr;
    }
    
    return lblzr.labelize!(Conn)(input);
}
