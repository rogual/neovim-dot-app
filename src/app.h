#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSResponder <NSApplicationDelegate> {
  BOOL didFinishLaunching;
  NSString *initOpenFile;
}

- (void) newWindow;
- (void) newWindowWithArgs:(const std::vector<char *> &)args;

@end
