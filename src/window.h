#import <Cocoa/Cocoa.h>
#import "view.h"

@interface VimWindow : NSWindow <NSWindowDelegate>

- (void)openFilename:(NSString *)file;
- (id)initWithArgs:(std::vector<char *> *)args;

@end
