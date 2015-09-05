#import <Cocoa/Cocoa.h>
#import "view.h"

@interface VimWindow : NSWindow <NSWindowDelegate>

- (void)openFilename:(NSString *)file;
- (id)initWithArgs:(const std::vector<char *> &)args;

@end
