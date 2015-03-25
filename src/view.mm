#include <string>
#include "vim.h"

#import <Cocoa/Cocoa.h>
#import "view.h"

@implementation VimView

/* Translate NSEvent modifier flags to Vim's prefix notation and write them
   to the given ostream */
static void addModifiers(std::ostream &os, NSEvent *event)
{
    int mods = [event modifierFlags];
         if (mods & NSShiftKeyMask) os << "S-";
    else if (mods & NSControlKeyMask) os << "C-";
    else if (mods & NSCommandKeyMask) os << "D-";
}

- (id)initWithFrame:(NSRect)frame vim:(Vim *)vim
{
    if (self = [super initWithFrame:frame]) {
        mVim = vim;
        mCanvas = [[NSImage alloc] initWithSize:CGSizeMake(1920, 1080)];
        mBackgroundColor = [[NSColor whiteColor] retain];
        mForegroundColor = [[NSColor blackColor] retain];
        mWaitAck = 0;

        mFont = [NSFont fontWithName:@"Menlo" size:11.0];
        [mFont retain];

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
}

- (void)changeFont:(id)sender
{
    mFont = [sender convertFont:mFont];
    [mTextAttrs setValue:mFont forKey:NSFontAttributeName];
    [self updateCharSize];

    NSWindow *win = [self window];
    NSRect frame = [win frame];
    frame = [win contentRectForFrameRect:frame];
    CGSize cellSize = {(float)mXCells, (float)mYCells};
    frame.size = [self viewSizeFromCellSize:cellSize];
    frame = [win frameRectForContentRect:frame];
    [win setFrame:frame display:NO];

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
        NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
        NSString* string = [pasteboard stringForType:NSPasteboardTypeString];
        string = [string stringByReplacingOccurrencesOfString:@"<"
                                                   withString:@"<lt>"];
        [self vimInput:[string UTF8String]];
    }
    else {
        mVim->vim_command("normal! \"+p");
    }
}

- (void)drawRect:(NSRect)rect
{
    [mBackgroundColor setFill];
    NSRectFill(rect);

    [mCanvas drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:1.0];

    [self drawCursor];
}

/* Draw a shitty cursor. TODO: Either:
    1) Figure out how to make Cocoa invert the display at the cursor pos
    2) Start keeping a screen character buffer */
- (void)drawCursor
{
    NSRect cellRect;

    float x = mCursorDisplayPos.x;
    float y = mCursorDisplayPos.y;

    if (mInsertMode)
        cellRect = CGRectMake(x, y, .2, 1);
    else
        cellRect = CGRectMake(x, y+1, 1, .3);

    NSRect viewRect = [self viewRectFromCellRect:cellRect];
    [mForegroundColor set];
    NSRectFill(viewRect);
}


/* -- Input -- */

/* When the user presses a key, put it in the keyqueue, and schedule 
   sendKeys */
- (void)keyDown:(NSEvent *)event
{
    [event retain];
    mKeyQueue.push_back(event);
    [self performSelector:@selector(sendKeys) withObject:nil afterDelay:0];
}

- (void)mouseEvent:(NSEvent *)event drag:(BOOL)drag type:(const char *)type
{
    NSPoint cellLoc = [self cellContainingEvent:event];

    /* Only send drag events when we cross cell boundaries */
    if (drag) {
        static NSPoint lastCellLoc = CGPointMake(-1, -1);
        if (CGPointEqualToPoint(lastCellLoc, cellLoc))
            return;
        lastCellLoc = cellLoc;
    }

    int mods = [event modifierFlags];

    /* Add modifier flags and mouse position */
    std::stringstream ss;
    ss << "<";
    addModifiers(ss, event);
    ss << type << "><" << cellLoc.x << "," << cellLoc.y << ">";

    [self vimInput:ss.str()];
}

- (void)mouseDown:    (NSEvent *)event { [self mouseEvent:event drag:NO type:"LeftMouse"]; }
- (void)mouseDragged: (NSEvent *)event { [self mouseEvent:event drag:YES type:"LeftDrag"]; }
- (void)mouseUp:      (NSEvent *)event { [self mouseEvent:event drag:NO type:"LeftRelease"]; }

- (void)rightMouseDown:    (NSEvent *)event { [self mouseEvent:event drag:NO type:"RightMouse"]; }
- (void)rightMouseDragged: (NSEvent *)event { [self mouseEvent:event drag:YES type:"RightDrag"]; }
- (void)rightMouseUp:      (NSEvent *)event { [self mouseEvent:event drag:NO type:"RightRelease"]; }

- (void)otherMouseDown:    (NSEvent *)event { [self mouseEvent:event drag:NO type:"MiddleMouse"]; }
- (void)otherMouseDragged: (NSEvent *)event { [self mouseEvent:event drag:YES type:"MiddleDrag"]; }
- (void)otherMouseUp:      (NSEvent *)event { [self mouseEvent:event drag:NO type:"MiddleRelease"]; }

- (void)scrollWheel:(NSEvent *)event
{
    CGFloat x = [event deltaX], y = [event deltaY];

    if (!x && !y)
        return;

    NSPoint cellLoc = [self cellContainingEvent:event];

    std::stringstream ss;
    ss << "<";
    addModifiers(ss, event);

         if (y > 0) ss << "ScrollWheelUp";
    else if (y < 0) ss << "ScrollWheelDown";
    else if (x > 0) ss << "ScrollWheelRight";
    else if (x < 0) ss << "ScrollWheelLeft";
    else assert(0);

    ss << "><" << cellLoc.x << "," << cellLoc.y << ">";
    [self vimInput:ss.str()];
}


/* If the user hasn't hit any new keys, send all the keypresses in the keyqueue
   to Vim */
- (void)sendKeys
{
    if (mWaitAck)
        return;

    if (mKeyQueue.empty())
        return;

    NSMutableArray *array = [[NSMutableArray alloc] init];

    std::string raw;
    for (NSEvent *event: mKeyQueue) {
        int flags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;

        if ([[event characters] isEqualToString:@"<"]) {
            raw += "<lt>";
        }
        else if ([self shouldPassThrough:event]) {
            raw += [[event characters] UTF8String];
        }
        else {
            [array addObject:event];
        }
        [event release];
    }

    [self interpretKeyEvents:array];
    [array release];

    if (raw.size())
        [self vimInput:raw];

    mKeyQueue.clear();
}

/* Send an input string to Vim. */
- (void)vimInput:(const std::string &)input
{
    mWaitAck += 1;
    mVim->vim_input(input).then([self]() {
        mWaitAck -= 1;
        if (mWaitAck == 0)
            [self sendKeys];
    });
}

/* true if the key event should go directly to Vim; false if it
   should go to OS X */
- (bool)shouldPassThrough:(NSEvent *)event
{
    int flags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;

    if (flags == NSControlKeyMask)
        return true;

    if ([[event characters] isEqualToString:@"\x1b"])
        return true;

    return false;
}

- (void)insertText:(id)string
{
    std::string input = [(NSString *)string UTF8String];
    [self vimInput:input];
}

- (void)deleteBackward:(id)sender { [self vimInput:"\x08"]; }
- (void)deleteForward: (id)sender { [self vimInput:"<Del>"]; }
- (void)insertNewline: (id)sender { [self vimInput:"\x0d"]; }
- (void)insertTab:     (id)sender { [self vimInput:"\t"]; }
- (void)insertBacktab: (id)sender { [self vimInput:"\x15"]; }



/* -- Resizing -- */

- (void)viewDidEndLiveResize
{
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

- (NSPoint)cellContainingEvent:(NSEvent *)event
{
    NSPoint winLoc = [event locationInWindow];
    NSPoint viewLoc = [self convertPoint:winLoc fromView:nil];
    NSPoint cellLoc = [self cellContaining:viewLoc];
    return cellLoc;
}

@end
