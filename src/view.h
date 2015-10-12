#include <map>
#include <vector>

class Vim;

@class NSImage;

@interface VimView : NSView<NSDraggingDestination> {
    Vim *mVim;

    CGContextRef mCanvasContext;
    CGColorSpaceRef mColorSpace;

    int mXCells;
    int mYCells;
    bool mInsertMode;
    bool mCursorOn;
    NSColor *mBackgroundColor;
    NSColor *mForegroundColor;
    NSMutableDictionary *mTextAttrs;
    bool mReverseVideo;
    NSSize mCharSize;
    CGRect mCellScrollRect;
    NSPoint mCursorPos;
    NSPoint mCursorDisplayPos;

    NSFont *mFont;
    NSFont *mBoldFont;
    NSFont *mItalicFont;
    NSFont *mBoldItalicFont;

    NSMenu *mMenuBar;
    NSMenuItem *mPopupMenu;
    NSMenu *mFontMenu;
    bool mMenuNeedsUpdate;

    NSString *mMarkedText;
}

- (void)cutText;
- (void)copyText;
- (void)pasteText;

- (void)setFont:(NSFont *)font;
- (void)setFontProgramatically:(NSFont *)font;

- (void)openFile:(NSString *)filename;

- (void)requestResize:(CGSize)cellSize;

- (id)initWithCellSize:(CGSize)cellSize vim:(Vim *)vim;

- (NSPoint)cellContaining:(NSPoint)viewPoint;
- (NSRect)viewRectFromCellRect:(NSRect)cellRect;
- (NSPoint)viewPointFromCellPoint:(NSPoint)cellPoint;
- (CGSize)viewSizeFromCellSize:(CGSize)cellSize;
- (CGSize)cellSizeInsideViewSize:(CGSize)viewSize;
- (NSRect)resizeWindow;

- (BOOL)probablyCommandMode;

@end
