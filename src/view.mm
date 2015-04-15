#include <string>
#include "vim.h"

#import <Cocoa/Cocoa.h>

#import "view.h"
#import "input.h"
#import "graphics.h"
#import "vimutils.h"

@implementation VimView

- (id)initWithFrame:(NSRect)frame vim:(Vim *)vim
{
    if (self = [super initWithFrame:frame]) {
        mVim = vim;

        /* TODO: support arbitrarily large windows */
        CGSize sizeInPixels = CGSizeMake(2*1920, 2*1080);

        mBackgroundColor = [[NSColor whiteColor] retain];
        mForegroundColor = [[NSColor blackColor] retain];

        /* Pick a color space, and store it as a property so we can set the
           window's color space to be the same one, improving draw speed. */
        mColorSpace = CGColorSpaceCreateWithName(
            kCGColorSpaceSRGB
        );

        /* A CGBitmapContext is basically a mutable buffer of bytes in a given
           image format, that can be drawn into. It sort of conflates the ideas
           of an image and a context. */
        mCanvasContext = CGBitmapContextCreate(
            0, // ask CG to allocate a buffer for us
            sizeInPixels.width,
            sizeInPixels.height,
            8, // bitsPerComponent
            0, // bytesPerRow (use default)
            mColorSpace,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host
        );
        assert (mCanvasContext);

        CGContextSaveGState(mCanvasContext);
        [self updateScale];

        /* Load font from saved settings */
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSFont *font = [NSFont fontWithName:[defaults stringForKey:@"fontName"]
                                       size:[defaults floatForKey:@"fontSize"]];
        [font retain];
        [self setFont:font];

        mTextAttrs = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
            mForegroundColor, NSForegroundColorAttributeName,
            mBackgroundColor, NSBackgroundColorAttributeName,
            mFont, NSFontAttributeName,
            nil
        ] retain];

        [[NSFontManager sharedFontManager] setSelectedFont:mFont isMultiple:NO];
        [[NSFontManager sharedFontManager] setDelegate:self];

        [self updateCharSize];

        mCursorPos = mCursorDisplayPos = CGPointZero;
        mCursorOn = true;

        [self registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
    }

    return self;
}

- (id)initWithCellSize:(CGSize)cellSize vim:(Vim *)vim
{
    NSRect frame = CGRectMake(0, 0, 100, 100);

    if (self = [self initWithFrame:frame vim:vim]) {
        frame.size = [self viewSizeFromCellSize:cellSize];
        [self setFrame:frame];
    }
    return self;
}

- (void)updateScale
{
    /* CGContext measures everything in pixels. If we want to auto-scale the
       stuff we draw into it to take Retina displays into account (which we
       do!) then we need to set a scaling factor ourselves: */
    float scale = [[self window] backingScaleFactor];
    CGContextRestoreGState(mCanvasContext);
    CGContextSaveGState(mCanvasContext);
    CGContextScaleCTM(mCanvasContext, scale, scale);
}

- (void)viewDidChangeBackingProperties
{
    [self updateScale];
    mVim->vim_command("redraw!");
}

/* Ask the font panel not to show colors, effects, etc. It'll still show color
   options in the cogwheel menu anyway because apple. */
- (NSUInteger)validModesForFontPanel:(NSFontPanel *)fontPanel
{
    return NSFontPanelFaceModeMask |
           NSFontPanelSizeModeMask |
           NSFontPanelCollectionModeMask;
}

- (void)updateCharSize
{
    mCharSize = [@" " sizeWithAttributes:mTextAttrs];
    mCharSize.height = ceil(
        [mFont ascender] - [mFont descender] + [mFont leading]
    );
}

- (void)setFont:(NSFont *)font
{
    [mBoldFont release];
    [mItalicFont release];
    [mBoldItalicFont release];

    mFont = font;

    NSFontManager *man = [NSFontManager sharedFontManager];

    mBoldFont = [man convertFont:font toHaveTrait:NSBoldFontMask];
    mItalicFont = [man convertFont:font toHaveTrait:NSItalicFontMask];
    mBoldItalicFont = [man convertFont:font
                           toHaveTrait:NSBoldFontMask | NSItalicFontMask];

    [mBoldFont retain];
    [mItalicFont retain];
    [mBoldItalicFont retain];
}

- (void)changeFont:(id)sender
{
    [self setFont:[sender convertFont:mFont]];

    // Update user defaults with new font
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:mFont.fontName forKey:@"fontName"];
    [defaults setFloat:mFont.pointSize forKey:@"fontSize"];

    [mTextAttrs setValue:mFont forKey:NSFontAttributeName];
    [self updateCharSize];

    /* If we're in fullscreen mode, figure out how many chars fit on the screen
       at the new font size. If we're not, try and resize the window first. */
    NSRect frame;
    if ([[self window] styleMask] & NSFullScreenWindowMask) {
        frame = [[[self window] screen] frame];
    }
    else {
        NSWindow *win = [self window];
        frame = [win frame];
        frame = [win contentRectForFrameRect:frame];
        CGSize cellSize = {(float)mXCells, (float)mYCells};
        frame.size = [self viewSizeFromCellSize:cellSize];
        frame = [win frameRectForContentRect:frame];
        [win setFrame:frame display:NO];
        frame = [self frame];
    }

    // Tell Vim to resize if necessary
    CGSize newCellSize = [self cellSizeInsideViewSize:frame.size];
    [self requestResize:newCellSize];

    mVim->vim_command("redraw!");
}

- (void)cutText
{
    if (!mInsertMode) {
        mVim->vim_command("normal! \"+d");
    }
}

- (void)copyText
{
    if (!mInsertMode) {
        mVim->vim_command("normal! \"+y");
    }
}

- (void)pasteText
{
    if (mInsertMode) {
        with_option(mVim, "paste", [self]() {
            [self pasteTextRaw];
        });
    }
    else if ([self probablyCommandMode]) {
        [self pasteTextRaw];
    }
    else {
        mVim->vim_command("normal! \"+p");
    }
}

- (void)pasteTextRaw
{
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    NSString* string =
        [pasteboard stringForType:NSPasteboardTypeString];

    string = [string stringByReplacingOccurrencesOfString:@"<"
                                                withString:@"<lt>"];
    string = [string stringByReplacingOccurrencesOfString:@"\n"
                                                withString:@"<CR>"];
    [self vimInput:[string UTF8String]];
}

- (void)selectAll
{
    mVim->vim_command("normal! ggVG");
}

- (void)openFile:(NSString *)nsFilename
{
    std::string filename;
    std::stringstream ss;

    filename = [nsFilename UTF8String];

    ss << "e ";

    /* We don't want Vim to try and interpret any part of the filename, and
       there's no documentation of what needs escaping, so escape every byte
       of it. */
    for (char ch : filename) {
        ss << '\\' << ch;
    }

    mVim->vim_command(ss.str());
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSFilenamesPboardType] )
    {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSFilenamesPboardType] )
    {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([[pboard types] containsObject:NSURLPboardType]) {
        NSArray *urls = [pboard readObjectsForClasses:@[[NSURL class]] options:nil];
        for (NSURL *url in urls) {
            const char *path = [[url filePathURL] fileSystemRepresentation];
            [self openFile: [NSString stringWithUTF8String:path]];
        }
    }
    return YES;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender 
{
}


/*  When drawing, it's important that our canvas image is in the same color
    space as the destination, otherwise drawing will be very slow. */
- (void)viewDidMoveToWindow
{
    NSColorSpace *nsColorSpace =
        [[[NSColorSpace alloc] initWithCGColorSpace:mColorSpace] autorelease];

    [[self window] setColorSpace:nsColorSpace];
}

- (void)drawRect:(NSRect)rect
{
    CGSize sizeInPoints = bitmapContextSizeInPoints(self, mCanvasContext);

    NSGraphicsContext *gc = [NSGraphicsContext currentContext];
    CGContextRef cg = (CGContextRef)[gc graphicsPort];

    NSRect totalRect;
    totalRect.origin = CGPointZero;
    totalRect.size = sizeInPoints;

    drawBitmapContext(cg, mCanvasContext, totalRect);

    [self drawCursor];
}

- (void)drawCursor
{
    NSRect cellRect;

    float x = mCursorDisplayPos.x;
    float y = mCursorDisplayPos.y;

    /* Difference, which can invert, is only present in the 10.10 SDK, so
       use the ugly cursor if the person compiling doesn't have that SDK.
       This is all going away anyway once we get a character buffer. */
    #ifdef __MAC_10_10

        if (mInsertMode || y + 1 == mYCells)
            cellRect = CGRectMake(x, y, .2, 1);
        else
            cellRect = CGRectMake(x, y, 1, 1);

        NSRect viewRect = [self viewRectFromCellRect:cellRect];
        [[NSColor whiteColor] set];
        NSRectFillUsingOperation(viewRect, NSCompositeDifference);

    #else

        if (mInsertMode || [self probablyCommandMode])
            cellRect = CGRectMake(x, y, .2, 1);
        else
            cellRect = CGRectMake(x, y+1, 1, .3);

        NSRect viewRect = [self viewRectFromCellRect:cellRect];
        [mForegroundColor set];
        NSRectFill(viewRect);

    #endif
}

/* Returns TRUE if we are probably in command mode. If the cursor is in the
   bottom row then we are deemed to probably be in command mode. */
- (BOOL)probablyCommandMode
{
    return mCursorDisplayPos.y + 1 == mYCells;
}


/* -- Resizing -- */

- (void)viewDidEndLiveResize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger: mXCells forKey:@"width"];
    [defaults setInteger: mYCells forKey:@"height"];
    [self display];
}

- (void)requestResize:(CGSize)cellSize
{
    int xCells = (int)cellSize.width;
    int yCells = (int)cellSize.height;

    if (xCells == mXCells && yCells == mYCells)
        return;

    if (mVim)
        mVim->ui_try_resize((int)cellSize.width, (int)cellSize.height);
}


/* -- Coordinate conversions -- */

- (NSRect)viewRectFromCellRect:(NSRect)cellRect
{
    CGFloat sy1 = cellRect.origin.y + cellRect.size.height;

    NSRect viewRect;
    viewRect.origin.x = cellRect.origin.x * mCharSize.width;
    viewRect.origin.y = [self frame].size.height - sy1 * mCharSize.height;
    viewRect.size = [self viewSizeFromCellSize:cellRect.size];
    return viewRect;
}

- (CGSize)viewSizeFromCellSize:(CGSize)cellSize
{
    return CGSizeMake(
        cellSize.width * mCharSize.width,
        cellSize.height * mCharSize.height
    );
}

- (CGSize)cellSizeInsideViewSize:(CGSize)viewSize
{
    CGSize cellSize;
    cellSize.width = int(viewSize.width / mCharSize.width);
    cellSize.height = int(viewSize.height / mCharSize.height);
    return cellSize;
}

- (NSPoint)cellContaining:(NSPoint)viewPoint
{
    CGFloat y = [self frame].size.height - viewPoint.y;
    NSPoint cellPoint;
    cellPoint.x = int(viewPoint.x / mCharSize.width);
    cellPoint.y = int(y / mCharSize.height);
    return cellPoint;
}

@end
