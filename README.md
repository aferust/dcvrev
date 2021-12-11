# dcv revision/revival

* An effort to make dcv work with the recent versions of LDC, mir libraries and stuff
* I consider this as a temporary git repo which will be deleted after a big PR to the original DCV repo (if the maintainers accept).

## Done so far:

* Slice types were updated as to be Slice!(T*, N, SliceKind). Slice!(Iterator, N, SliceKind) allows refcounted images.
* Many other updates to comply with recent mir and Phobos libraries.
 uninitialized slice factory was changed to makeUninitSlice!T(GCAllocator.instance, someShape);
* bindbc libraries (bindbc-glfw and bindbc-opengl) replaced internal bindings for plotting.
* FFmpeg 4.4.1 binding was created from scratch.
* dub packaging system was changed to use dcv modules as separate dependecies such as dcv:core, dcv:video, dcv:ffmpeg441
* I only tested things on Windows.

## newly-implemented functionality:
* Otsu's method for threshold calculation
* dcv.measure.label for labelling connected regions
* dcv.measure.contours

## Need help for

* updating the comments in the code which (I believe) create the docs.
* testing. Examples of the original repo should be a good start.
* updating unittests.
* solving any issue encountered during tests.
* fixing multiview module. Start here: unrevised/multiview/stereo/matching.d line 242