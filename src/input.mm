#include <sstream>
#include "vim.h"

#import <Cocoa/Cocoa.h>

#import "view.h"
#import "redraw.h"
#import "input.h"
#import "keys.h"

@implementation VimView (Input)

- (bool)keyIsNotControlChar:(char) c{
    return 32 <= c && c <= 126; // see ascii table
}

- (void) sendEventToVim:(NSEvent *) event{
      BOOL useOptAsMeta = [self hasOptAsMetaForModifier:[event modifierFlags]];
      std::stringstream raw;
      translateKeyEvent(raw, event, useOptAsMeta);
      std::string raws = raw.str();

      if (raws.size())
          [self vimInput:raws];

      return;
}

- (void) sendEventToIME:(NSEvent *) event{
      NSTextInputContext *con = [NSTextInputContext currentInputContext];
      [con handleEvent: event];
      return;
}

- (void)keyDown:(NSEvent *)event
{
    NSTextInputContext *con = [NSTextInputContext currentInputContext];
    [NSCursor setHiddenUntilMouseMoves:YES];
    BOOL useOptAsMeta = [self hasOptAsMetaForModifier:[event modifierFlags]];

    char c=0;
    if([[event characters] length]){
      c = [[event characters] characterAtIndex:0];
    }

    // if non-insert mode, ignore IME and send all to vim.
    //if(!mInsertMode){
    //  [self sendEventToVim:event];
    //  return;
    //}

    // if insert mode and input is an ordinal character, send event to input context to trigger IME
    if (c && [self keyIsNotControlChar:c]){
      [self sendEventToIME:event];
      return;
    }

    // if input is a control character,  send it to IME only if IME is working
    if ([self hasMarkedText]) {
        [self sendEventToIME:event];
        return;
    } else {
        [self sendEventToVim:event];
        return;
    }

}

- (BOOL)hasOptAsMetaForModifier:(int)modifiers
{
    if (!mOptAsMeta)
        return NO;

    if (mOptAsMeta == META_EITHER)
        return (modifiers & mOptAsMeta) == mOptAsMeta;

    return modifiers == mOptAsMeta;
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    NSEventType type = [event type];
    unsigned flags = [event modifierFlags];

    /* <C-Tab> & <C-S-Tab> do not trigger keyDown events.
       Catch the key event here and pass it to keyDown. */
    if (NSKeyDown == type && NSControlKeyMask & flags && 48 == [event keyCode]) {
        [self keyDown:event];
        return YES;
    }

    return NO;
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
    else if (x < 0) type = "ScrollWheelRight";
    else if (x > 0) type = "ScrollWheelLeft";
    else assert(0);

    addModifiedName(ss, event, type);

    ss << "<" << cellLoc.x << "," << cellLoc.y << ">";
    [self vimInput:ss.str()];
}

/* Send an input string to Vim. */
- (void)vimInput:(const std::string &)input
{
    if (mInsertMode)
        [[self window] setDocumentEdited:YES];

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

- (BOOL)hasMarkedText { return mMarkedText.length? YES : NO; }
- (NSRange)markedRange { NSLog(@"MR"); return {NSNotFound, 0}; }
- (NSRange)selectedRange { NSLog(@"SR"); return {NSNotFound, 0}; }

- (void)setMarkedText:(id)string
        selectedRange:(NSRange)x
        replacementRange:(NSRange)y
{
    if (!mMarkedText)
        mMarkedText = [@"" retain];

    if ([string isKindOfClass:[NSAttributedString class]])
        string = [string string];

    [mMarkedText autorelease];
    mMarkedText = [string copy];
    [mMarkedText retain];

    /* Draw the fake character on the screen as if
       nvim would've told it to do so */
    typedef std::tuple<std::string, std::vector<std::string>> putmsg_t;
    typedef std::tuple<std::string, std::vector<int>> cursormsg_t;

    putmsg_t putdata("put", {[string UTF8String]});
    cursormsg_t cursordata("cursor_goto",
            {(int)mCursorDisplayPos.y, (int)mCursorDisplayPos.x});

    msgpack::sbuffer sbuf;
    msgpack::packer<msgpack::sbuffer> pk(sbuf);
    pk.pack_array(2);
    pk.pack(putdata);
    pk.pack(cursordata);

    msgpack::unpacked msg;
    msgpack::unpack(msg, sbuf.data(), sbuf.size());
    msgpack::object obj = msg.get();

    [self redraw:obj];
}

- (void)unmarkText
{
    [mMarkedText release];
    mMarkedText = nil;
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

    [self unmarkText];
    [self insertText:string];
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
  double x = mCursorDisplayPos.x * mCharSize.width;
  double y = [self frame].size.height - mCursorDisplayPos.y * mCharSize.height - 10;
  return {{x, y}, {x, y}};
}

- (void)doCommandBySelector:(SEL)selector
{
}

@end
