#include <time.h>
#include <iostream>
#import "graphics.h"


/* Draw a CGBitmapContext into a CGContext, without:
    - Copying memory
    - Converting colours
    - Swapping bytes
    - Any other performance landmines
*/
void drawBitmapContext(
    CGContextRef dest,
    CGContextRef src,
    CGRect rect)
{
    size_t numBytes =
        CGBitmapContextGetBytesPerRow(src) *
        CGBitmapContextGetHeight(src);

    CGDataProviderRef provider = CGDataProviderCreateWithData(
        0,
        CGBitmapContextGetData(src),
        numBytes,
        0
    );
    assert (provider);

    CGImageRef image = CGImageCreate(
        CGBitmapContextGetWidth(src),
        CGBitmapContextGetHeight(src),
        CGBitmapContextGetBitsPerComponent(src),
        CGBitmapContextGetBitsPerPixel(src),
        CGBitmapContextGetBytesPerRow(src),
        CGBitmapContextGetColorSpace(src),
        CGBitmapContextGetBitmapInfo(src),
        provider,
        0, // decode
        NO, // shouldInterpolate
        kCGRenderingIntentDefault
    );
    assert (image);

    CGContextDrawImage(dest, rect, image);

    CFRelease(image);
    CFRelease(provider);
}


CGSize bitmapContextSizeInPoints(NSView *view, CGContextRef bitmapContext)
{
    CGSize sizeInPixels = {
        (float)CGBitmapContextGetWidth(bitmapContext),
        (float)CGBitmapContextGetHeight(bitmapContext),
    };

    CGSize sizeInPoints = [view convertSizeFromBacking:sizeInPixels];

    return sizeInPoints;
}
