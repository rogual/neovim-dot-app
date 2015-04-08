#import <Cocoa/Cocoa.h>

void drawBitmapContext(
    CGContextRef dest,
    CGContextRef src,
    CGRect rect
);

CGSize bitmapContextSizeInPoints(
    NSView *view,
    CGContextRef bitmapContext
);

inline NSColor *RGBA(float r, float g, float b, float a)
{
    return [NSColor colorWithSRGBRed:r / 255.0
                               green:g / 255.0
                                blue:b / 255.0
                               alpha:a / 255.0];
}

inline NSColor *NSColorFromRGB(unsigned rgbValue)
{
    return [NSColor
        colorWithSRGBRed:((float)((rgbValue & 0xFF0000) >> 16)) / 255.0
                   green:((float)((rgbValue & 0x00FF00) >>  8)) / 255.0
                    blue:((float)((rgbValue & 0x0000FF) >>  0)) / 255.0
                   alpha:1.0];
}
