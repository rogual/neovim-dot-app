#include <sstream>
#include "vim.h"

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "view.h"
#import "input.h"


/* Translate NSEvent modifier flags to Vim's prefix notation and write them
   to the given ostream */
static void addModifiers(std::ostream &os, NSEvent *event)
{
    int mods = [event modifierFlags];
         if (mods & NSShiftKeyMask) os << "S-";
    else if (mods & NSControlKeyMask) os << "C-";
    else if (mods & NSCommandKeyMask) os << "D-";
}

static void addModifiedName(std::ostream &os, NSEvent *event, const char *name)
{
    os << "<";
    addModifiers(os, event);
    os << name;
    os <<
        ">";
}

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
   to Vim */
- (void)sendKeys
{
    if (mWaitAck)
        return;

    if (mKeyQueue.empty())
        return;

    NSMutableArray *array = [[NSMutableArray alloc] init];

    std::stringstream raw;
    for (NSEvent *event: mKeyQueue) {
        int flags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;

        unsigned short keyCode = [event keyCode];

             if (keyCode == kVK_LeftArrow) addModifiedName(raw, event, "Left");
        else if (keyCode == kVK_RightArrow) addModifiedName(raw, event, "Right");
        else if (keyCode == kVK_UpArrow) addModifiedName(raw, event, "Up");
        else if (keyCode == kVK_DownArrow) addModifiedName(raw, event, "Down");
        else if ([[event characters] isEqualToString:@"<"]) {
            raw << "<lt>";
        }
        else if ([self shouldPassThrough:event]) {
            raw << [[event characters] UTF8String];
        }
        else {
            [array addObject:event];
        }
        [event release];
    }

    [self interpretKeyEvents:array];
    [array release];

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

- (NSPoint)cellContainingEvent:(NSEvent *)event
{
    NSPoint winLoc = [event locationInWindow];
    NSPoint viewLoc = [self convertPoint:winLoc fromView:nil];
    NSPoint cellLoc = [self cellContaining:viewLoc];
    return cellLoc;
}

@end
