#import <Cocoa/Cocoa.h>

void drawBitmapContext(
    CGContextRef src,
    CGContextRef dest,
    CGRect rect
);

CGSize bitmapContextSizeInPoints(
    NSView *view,
    CGContextRef bitmapContext
);
