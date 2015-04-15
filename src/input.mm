#include <sstream>
#include "vim.h"

#import <Cocoa/Cocoa.h>

#import "view.h"
#import "input.h"
#import "keys.h"


@implementation VimView (Input)

- (void)keyDown:(NSEvent *)event
{
    NSTextInputContext *con = [NSTextInputContext currentInputContext];

    mImeUsedEvent = false;
    NSLog(@"KD");
    if (mInsertMode && [con handleEvent:event] && mImeUsedEvent) {
        NSLog(@"letting cocoa keep it");
    }
    else {
        NSLog(@"Sending to vim");
        std::stringstream raw;
        translateKeyEvent(raw, event);

        std::string raws = raw.str();
        if (raws.size())
            [self vimInput:raws];
    }
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


/* -- NSTextInputClient methods -- */

- (BOOL)hasMarkedText { NSLog(@"HMT"); return false; }
- (NSRange)markedRange { NSLog(@"MR"); return {NSNotFound, 0}; }
- (NSRange)selectedRange { NSLog(@"SR"); return {NSNotFound, 0}; }

- (void)setMarkedText:(id)string
        selectedRange:(NSRange)x
        replacementRange:(NSRange)y
{
    if (!mImeMarkedText)
        mImeMarkedText = [@"" retain];

    if ([string isKindOfClass:[NSAttributedString class]])
        string = [string string];

    [mImeMarkedText autorelease];
    //mImeMarkedText = [mImeMarkedText stringByAppendingString:string];
    mImeMarkedText = string;
    [mImeMarkedText retain];
    mVim->vim_command("redraw!");

    mImeMarkedTextCellPos = mCursorDisplayPos;

    NSLog(@"setMarkedText %@", string);
    mImeUsedEvent = true;
}

- (void)unmarkText
{
    [mImeMarkedText release];
    mImeMarkedText = nil;
    mVim->vim_command("redraw!");
}

- (NSArray *)validAttributesForMarkedText
{
    return @[];
}

- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)aRange
                                                actualRange:(NSRangePointer)actualRange
{
    return nil;
}

- (void)insertText:(id)string
  replacementRange:(NSRange)replacementRange
{
    if ([string isKindOfClass:[NSAttributedString class]])
        string = [string string];

    NSLog(@"insertText:%@ r:%@", string, NSStringFromRange(replacementRange));
    [self unmarkText];
    [self insertText:string];
    mImeUsedEvent = true;
}

- (void)insertText:(NSString *)string
{
    string = [string stringByReplacingOccurrencesOfString:@"<"
                                               withString:@"<lt>"];

    [self vimInput:[string UTF8String]];
}


- (NSUInteger)characterIndexForPoint:(NSPoint)aPoint
{
    return NSNotFound;
}

- (NSRect)firstRectForCharacterRange:(NSRange)aRange
                         actualRange:(NSRangePointer)actualRange
{
    return {{0,0},{0,0}};
}

- (void)doCommandBySelector:(SEL)selector
{
}

@end
