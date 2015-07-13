#include <sstream>
#include "vim.h"

#import <Cocoa/Cocoa.h>

#import "view.h"
#import "input.h"
#import "keys.h"


@implementation VimView (Input)

- (void)keyDown:(NSEvent *)event
{
    std::stringstream raw;
    translateKeyEvent(raw, event);

    std::string raws = raw.str();
    if (raws.size())
        [self vimInput:raws];
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
    CGFloat x = [event scrollingDeltaX], y = [event scrollingDeltaY];

    if ([event hasPreciseScrollingDeltas]) {
        x /= mCharSize.width;
        y /= mCharSize.height;
    }

    x *= 2;
    y *= 2;

    scrollAccumulator.x += x;
    scrollAccumulator.y += y;

    NSPoint cellLoc = [self cellContainingEvent:event];

    if (scrollAccumulator.y < -1) {
        int lines = -scrollAccumulator.y;
        scrollAccumulator.y += lines;

        std::stringstream ss;
        for (int i=0; i<lines; i++) {
            ss << "<C-E>";
        }
        [self vimInput:ss.str()];
    }

    if (scrollAccumulator.y > 1) {
        int lines = scrollAccumulator.y;
        scrollAccumulator.y -= lines;

        std::stringstream ss;
        for (int i=0; i<lines; i++) {
            ss << "<C-Y>";
        }
        [self vimInput:ss.str()];
    }

    //while (scrollAccumulator.x <= -1) {
        //scrollAccumulator.x += 1;
        //[self sendScrollEvent:"ScrollWheelLeft" forEvent:event at:cellLoc];
    //}

    //while (scrollAccumulator.x >= 1) {
        //scrollAccumulator.x -= 1;
        //[self sendScrollEvent:"ScrollWheelRight" forEvent:event at:cellLoc];
    //}

    //while (scrollAccumulator.y <= -1) {
        //scrollAccumulator.y += 1;
        //[self sendScrollEvent:"ScrollWheelDown" forEvent:event at:cellLoc];
    //}

    //while (scrollAccumulator.y >= 1) {
        //scrollAccumulator.y -= 1;
        //[self sendScrollEvent:"ScrollWheelUp" forEvent:event at:cellLoc];
    //}
}

- (void)sendScrollEvent:(const char *)type
              forEvent:(NSEvent *)event
                    at:(NSPoint)cellLoc
{

    std::stringstream ss;
    addModifiedName(ss, event, type);

    ss << "<" << cellLoc.x << "," << cellLoc.y << ">";
    [self vimInput:ss.str()];
}

/* Send an input string to Vim. */
- (void)vimInput:(const std::string &)input
{
    mVim->vim_input(input);
}

- (NSPoint)cellContainingEvent:(NSEvent *)event
{
    NSPoint winLoc = [event locationInWindow];
    NSPoint viewLoc = [self convertPoint:winLoc fromView:nil];
    NSPoint cellLoc = [self cellContaining:viewLoc];
    return cellLoc;
}

@end
