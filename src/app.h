#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSResponder <NSApplicationDelegate> {}

- (void) newWindow;
- (void) newWindowWithArgs:(std::vector<char *> *)args;

@end
