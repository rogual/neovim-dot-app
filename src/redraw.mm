#include <cassert>

#include <iostream>
#include <string>
#include <vector>

#include <msgpack.hpp>

#include "redraw-hash.gen.h"

#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import "view.h"
#import "graphics.h"
#import "menu.h"

static const bool debug = false;

using msgpack::object;

@implementation VimView (Redraw)

- (void) redraw:(const msgpack::object &)update_o
{
    [mTextAttrs setValue:mFont forKey:NSFontAttributeName];

    [NSGraphicsContext saveGraphicsState];

    [NSGraphicsContext setCurrentContext:[NSGraphicsContext
        graphicsContextWithGraphicsPort:(void *)mCanvasContext
        flipped:NO]];

    mMenuNeedsUpdate = false;

    try
    {
        assert([NSThread isMainThread]);

        if (debug) std::cout << "-- " << update_o.via.array.size << "\n";

        for(int i=0; i<update_o.via.array.size; i++) {


            const object &item_o = update_o.via.array.ptr[i];

            if (debug) std::cout << item_o << "\n";

            assert(item_o.via.array.size >= 1);

            const object &action_o = item_o.via.array.ptr[0];

            const RedrawAction *action = RedrawHash::in_word_set(
                action_o.via.str.ptr,
                action_o.via.str.size
            );

            if (!action) {
                std::cout << "?? " << item_o << "\n";
                continue;
            }

            [self doAction:action->code withItem:item_o];
        }
    }
    catch(std::exception &e) {
        assert(0);
        std::exit(-1);
    }

    [NSGraphicsContext restoreGraphicsState];

    if (mMenuNeedsUpdate) {
        [self updateMenu];
    }
}

- (void) doAction:(RedrawCode::Enum)code withItem:(const object &)item_o
{
    int item_sz = item_o.via.array.size;
    object *arglists = item_o.via.array.ptr + 1;

    if (code == RedrawCode::put) {
        /*
        This is the main redraw loop, which draws consecutive characters on one line.
        The background is drawn separately from the foreground and the text
        attributes are set in another event.
        These lines should render properly and be aligned:
        iiiiiiiiiiiiiiiiiiii|
        MMMMMMMMMMMMMMMMMMMM|
        サパラサパサパラサパ|
        */

        // Separate Front- and Backend colors
        NSColor *fg = [mTextAttrs objectForKey:NSForegroundColorAttributeName];
        NSColor *bg = [mTextAttrs objectForKey:NSBackgroundColorAttributeName];

        // Remove Background color from text attributes
        NSMutableDictionary *textAttrs = [[[NSMutableDictionary alloc] init] autorelease];
        [textAttrs setDictionary:mTextAttrs];
        [textAttrs removeObjectForKey:NSBackgroundColorAttributeName];

        // Reverse bg and fg color if necessary
        if (mReverseVideo) {
            [textAttrs setObject:bg forKey:NSForegroundColorAttributeName];
            bg = fg;
        }

        // Draw background separately [width = item_sz]
        NSRect bgrect = [self
            viewRectFromCellRect:CGRectMake(mCursorPos.x, mCursorPos.y, item_sz - 1, 1)];
        [bg set];
        NSRectFill(bgrect);

        CGContextSaveGState(mCanvasContext);

        // TODO: Remove when font height formula is corrected (updateCharSize)
        CGContextClipToRect(mCanvasContext, bgrect);

        // Init string (First part of unicode left-to-right force)
        NSString *nsrun = @"\u202d";

        int width = 0;
        for (int i = 1; i < item_sz; i++) {
            const object &arglist = item_o.via.array.ptr[i];

            assert(arglist.via.array.size == 1);
            const std::string char_s = arglist.via.array.ptr[0].convert();

            // Do nothing if last char was double width
            if (char_s.size() == 0) {
                // Force left-to-right rendering (Second part of unicode force)
                nsrun = [nsrun stringByAppendingString:@"\u202c"];

                NSPoint point = [self
                    viewPointFromCellPoint:CGPointMake(mCursorPos.x, mCursorPos.y)];
                [nsrun drawAtPoint:point withAttributes:textAttrs];

                // Width + 1 as it was a double width char
                mCursorPos.x += width + 1;
                nsrun = @"\u202d";
                width = 0;
                continue;
            }

            width++;
            nsrun = [nsrun stringByAppendingString:
              [NSString stringWithUTF8String:char_s.c_str()]];
        }

        // Force left-to-right rendering (Second part of unicode force)
        nsrun = [nsrun stringByAppendingString:@"\u202c"];

        NSPoint point = [self
            viewPointFromCellPoint:CGPointMake(mCursorPos.x, mCursorPos.y)];
        [nsrun drawAtPoint:point withAttributes:textAttrs];

        mCursorPos.x += width;

        CGContextRestoreGState(mCanvasContext);
        [self setNeedsDisplay:YES];
    }
    else for (int i = 0; i < item_sz - 1; i++) {
        const object &arglist = arglists[i];
        [self doAction:code withArgc:arglist.via.array.size argv:arglist.via.array.ptr];
    }

    if (mCursorOn)
        mCursorDisplayPos = mCursorPos;
}

- (void) doAction:(RedrawCode::Enum)code withArgc:(int)argc argv:(const object *)argv
{
    NSRect viewFrame = [self frame];

    switch(code)
    {
        case RedrawCode::update_fg:
        case RedrawCode::update_bg:
        {
            NSColor **dest = (code == RedrawCode::update_fg) ?
                &mForegroundColor : &mBackgroundColor;

            int rgb = argv[0].convert();

            [*dest release];

            if (rgb == -1)
                *dest = (code == RedrawCode::update_fg ? [NSColor blackColor] :
                                                         [NSColor whiteColor]);
            else
                *dest = NSColorFromRGB(rgb);

            [*dest retain];
            break;
        }

        case RedrawCode::cursor_on:
        {
            mCursorOn = true;
            mCursorDisplayPos = mCursorPos;
            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::cursor_off:
        {
            mCursorOn = false;
            break;
        }

        case RedrawCode::cursor_goto:
        {
            mCursorPos.y = argv[0].convert();
            mCursorPos.x = argv[1].convert();

            if (mCursorOn) {
                mCursorDisplayPos = mCursorPos;
                [self setNeedsDisplay:YES];
            }

            break;
        }

        case RedrawCode::update_menu:
        {
            mMenuNeedsUpdate = true;
            break;
        }

        case RedrawCode::clear:
        {
            mCursorPos.x = 0;
            mCursorPos.y = 0;

            if (mCursorOn)
                mCursorDisplayPos = mCursorPos;

            [mBackgroundColor set];
            NSRectFill(viewFrame);

            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::eol_clear:
        {
            NSRect rect;
            rect.origin.x = floor(mCursorPos.x * mCharSize.width);
            rect.origin.y = floor([self frame].size.height - (mCursorPos.y + 1) * mCharSize.height);
            rect.size.width = ceil([self frame].size.width - mCursorPos.x);
            rect.size.height = ceil(mCharSize.height);

            [mBackgroundColor set];
            NSRectFill(rect);

            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::highlight_set:
        {
            std::map<std::string, msgpack::object> attrs = argv[0].convert();

            NSColor *fgcolor        = mForegroundColor;
            NSColor *bgcolor        = mBackgroundColor;
            NSFont  *font           = mFont;
            bool     bold           = false;
            bool     italic         = false;
            bool     underline      = false;
            bool     undercurl      = false;
            int      underlineStyle = 0;

            mReverseVideo = false;

            for(auto iter = attrs.begin(); iter != attrs.end(); ++iter)
            {
                std::string attr    = iter->first;
                msgpack::object val = iter->second;

                if (attr == "foreground")
                    fgcolor = NSColorFromRGB(val.convert());

                else if (attr == "background")
                    bgcolor = NSColorFromRGB(val.convert());

                else if (attr == "bold")
                    bold = val.convert();

                else if (attr == "italic")
                    italic = val.convert();

                else if (attr == "underline")
                    underline = val.convert();

                else if (attr == "undercurl")
                    undercurl = val.convert();

                else if (attr == "reverse")
                    mReverseVideo = val.convert();

            }

            [mTextAttrs setValue:fgcolor forKey:NSForegroundColorAttributeName];
            [mTextAttrs setValue:bgcolor forKey:NSBackgroundColorAttributeName];

            if (bold && italic) font = mBoldItalicFont;
            else if (bold)      font = mBoldFont;
            else if (italic)    font = mItalicFont;

            [mTextAttrs setValue:font forKey:NSFontAttributeName];


            if (underline && undercurl) underlineStyle = NSUnderlineStyleDouble;
            else if (underline) underlineStyle = NSUnderlineStyleSingle;
            else if (undercurl) underlineStyle =
                NSUnderlineStyleSingle | NSUnderlinePatternDot;

            [mTextAttrs setValue:[NSNumber numberWithInteger:underlineStyle]
                          forKey:NSUnderlineStyleAttributeName];
            break;
        }

        case RedrawCode::set_scroll_region:
        {
            int y = mCellScrollRect.origin.y = argv[0].convert();
            int x = mCellScrollRect.origin.x = argv[2].convert();
            mCellScrollRect.size.height = argv[1].as<int>() - y + 1;
            mCellScrollRect.size.width = argv[3].as<int>() - x + 1;
            break;
        }

        /* Scroll by drawing our canvas context into itself,
           offset and clipped. */
        case RedrawCode::scroll:
        {
            int amt = argv[0].convert();

            NSRect dest = [self viewRectFromCellRect:mCellScrollRect];

            CGSize size = bitmapContextSizeInPoints(self, mCanvasContext);
            NSRect totalRect = {CGPointZero, size};

            totalRect.origin.y = floor(totalRect.origin.y + amt * mCharSize.height);

            CGContextSaveGState(mCanvasContext);
            CGContextClipToRect(mCanvasContext, dest);
            drawBitmapContext(mCanvasContext, mCanvasContext, totalRect);
            CGContextRestoreGState(mCanvasContext);

            // Clear the newly-visible lines
            [mBackgroundColor set];
            if (amt > 0) {
                dest.size.height = amt * mCharSize.height;
                NSRectFill(dest);
            }
            if (amt < 0) {
                int ny = (-amt) * mCharSize.height;
                dest.origin.y += dest.size.height - ny;
                dest.size.height = ny;
                NSRectFill(dest);
            }

            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::resize:
        {
            mXCells = argv[0].convert();
            mYCells = argv[1].convert();
            mCellScrollRect = CGRectMake(0, 0, mXCells, mYCells);

            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::mode_change:
        {
            std::string mode = argv[0].convert();
            mInsertMode = (mode == "insert");
            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::bell:
        {
            NSBeep();
            break;
        }

        // Ignore these for now
        case RedrawCode::mouse_on:
        case RedrawCode::mouse_off:
        case RedrawCode::busy_start:
        case RedrawCode::busy_stop:
            break;

        default:
        {
            assert(0);
            break;
        }
    }
}

@end
