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
}

- (void) doAction:(RedrawCode::Enum)code withItem:(const object &)item_o
{
    int item_sz = item_o.via.array.size;
    object *arglists = item_o.via.array.ptr + 1;
    int narglists = item_sz - 1;


    if (code == RedrawCode::put) {

        static std::vector<std::string> runs;
        runs.clear();

        static std::vector<int> lens;
        lens.clear();

        static std::string run;
        run.clear();

        int len = 0;
        for (int i=1; i<item_sz; i++) {
            const object &arglist = item_o.via.array.ptr[i];

            assert(arglist.via.array.size == 1);
            const object &char_o = arglist.via.array.ptr[0];
            std::string char_s = char_o.convert();
            len += 1;
            if (char_s.size() == 0) {
                runs.push_back(run);
                lens.push_back(len);
                run.clear();
                len = 0;
            }
            else {
                run += char_s;
            }
        }

        if (len) {
            runs.push_back(run);
            lens.push_back(len);
        }

        for (int i=0; i<runs.size(); i++) {
            const std::string &run = runs[i];
            int sz = lens[i];

            NSString *nsrun = [NSString stringWithUTF8String:run.c_str()];

            NSRect cellRect = CGRectMake(mCursorPos.x, mCursorPos.y, sz, 1);
            NSRect rect = [self viewRectFromCellRect:cellRect];

            /* Maybe there is some combination of options for either drawAtPoint,
            drawInRect, or drawWithRect, that makes Cocoa draw some text in a
            fucking rectangle, but I couldn't figure it out. The background is
            always too tall or too short. Solution:

            - Draw our own background for fonts like Monaco that come up short
            - Use a clipping rect for fonts like Droid Sans that draw way too
                high */

            NSColor *bg = [mTextAttrs objectForKey:NSBackgroundColorAttributeName];
            [bg set];
            NSRectFill(rect);

            CGPoint origin = rect.origin;
            float r = rect.origin.x + rect.size.width;
            rect.origin.x = floor(rect.origin.x);
            rect.size.width = ceil(r - rect.origin.x);

            CGContextSaveGState(mCanvasContext);
            CGContextClipToRect(mCanvasContext, rect);
            [nsrun drawAtPoint:origin withAttributes:mTextAttrs];
            CGContextRestoreGState(mCanvasContext);

            mCursorPos.x += sz;
        }

        [self setNeedsDisplay:YES];
    }
    else for (int i=0; i<narglists; i++) {
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
            rect.origin.x = mCursorPos.x * mCharSize.width;
            rect.origin.y = viewFrame.size.height - (mCursorPos.y + 1) * mCharSize.height;
            rect.size.width = viewFrame.size.width - mCursorPos.x;
            rect.size.height = mCharSize.height;
            [mBackgroundColor set];
            NSRectFill( rect ) ;

            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::highlight_set:
        {
            std::map<std::string, msgpack::object> attrs = argv[0].convert();

            NSColor *color;
            try {
                unsigned fg = attrs.at("foreground").convert();
                color = NSColorFromRGB(fg);
            }
            catch(...) { color = mForegroundColor; }
            [mTextAttrs setValue:color forKey:NSForegroundColorAttributeName];

            try {
                unsigned bg = attrs.at("background").convert();
                color = NSColorFromRGB(bg);
            }
            catch(...) { color = mBackgroundColor; }
            [mTextAttrs setValue:color forKey:NSBackgroundColorAttributeName];

            bool bold;
            try {
                bold = attrs.at("bold").convert();
            }
            catch(...) { bold = false; }

            bool italic;
            try {
                italic = attrs.at("italic").convert();
            }
            catch(...) { italic = false; }

            NSFont *font;

            if (bold && italic) font = mBoldItalicFont;
            else if (bold)      font = mBoldFont;
            else if (italic)    font = mItalicFont;
            else                font = mFont;

            [mTextAttrs setValue:font forKey:NSFontAttributeName];

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

            totalRect.origin.y += amt * mCharSize.height;

            CGContextSaveGState(mCanvasContext);
            CGContextClipToRect(mCanvasContext, dest);
            drawBitmapContext(mCanvasContext, mCanvasContext, totalRect);
            CGContextRestoreGState(mCanvasContext);

            /* Clear the newly-visible lines */
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

        case RedrawCode::normal_mode:
        {
            mInsertMode = false;
            [self setNeedsDisplay:YES];
            break;
        }

        case RedrawCode::insert_mode:
        {
            mInsertMode = true;
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
