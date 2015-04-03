#include <sstream>
#include "vim.h"

#import <Cocoa/Cocoa.h>

#import "view.h"
#import "input.h"
#import "keys.h"


@implementation VimView (Input)

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
    addModifiedName(ss, event, type);

    ss << "<" << cellLoc.x << "," << cellLoc.y << ">";

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

    const char *type;
         if (y > 0) type = "ScrollWheelUp";
    else if (y < 0) type = "ScrollWheelDown";
    else if (x > 0) type = "ScrollWheelRight";
    else if (x < 0) type = "ScrollWheelLeft";
    else assert(0);

    addModifiedName(ss, event, type);

    ss << "<" << cellLoc.x << "," << cellLoc.y << ">";
    [self vimInput:ss.str()];
}


/* If the user hasn't hit any new keys, send all the keypresses in the keyqueue
   to Vim. */
- (void)sendKeys
{
    if (mWaitAck)
        return;

    if (mKeyQueue.empty())
        return;

    std::stringstream raw;
    for (NSEvent *event: mKeyQueue) {
        translateKeyEvent(raw, event);
        [event release];
    }

    std::string raws = raw.str();
    if (raws.size())
        [self vimInput:raws];

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

- (NSPoint)cellContainingEvent:(NSEvent *)event
{
    NSPoint winLoc = [event locationInWindow];
    NSPoint viewLoc = [self convertPoint:winLoc fromView:nil];
    NSPoint cellLoc = [self cellContaining:viewLoc];
    return cellLoc;
}

@end
