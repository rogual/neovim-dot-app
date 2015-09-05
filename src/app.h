#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSResponder <NSApplicationDelegate> {}

- (void) newWindow;
- (void) newWindowWithArgs:(const std::vector<char *> &)args;

@end
