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
    std::vector<NSEvent *>mKeyQueue;
    int mWaitAck;
    NSSize mCharSize;
    CGRect mCellScrollRect;
    NSPoint mCursorPos;
    NSPoint mCursorDisplayPos;

    NSFont *mFont;
    NSFont *mBoldFont;
    NSFont *mItalicFont;
    NSFont *mBoldItalicFont;
}

- (BOOL)insertOrProbablyCommandMode;

- (void)cutText;
- (void)copyText;
- (void)pasteText;

- (void)openFile:(NSString *)filename;

- (void)requestResize:(CGSize)cellSize;

- (id)initWithCellSize:(CGSize)cellSize vim:(Vim *)vim;

- (NSPoint)cellContaining:(NSPoint)viewPoint;
- (NSRect)viewRectFromCellRect:(NSRect)cellRect;
- (CGSize)viewSizeFromCellSize:(CGSize)cellSize;
- (CGSize)cellSizeInsideViewSize:(CGSize)viewSize;

@end
