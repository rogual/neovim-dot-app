#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSResponder <NSApplicationDelegate> {
    BOOL didFinishLaunching;
    std::vector<char *> initOpenFiles;
}

- (void) newWindow;
- (void) newWindowWithArgs:(const std::vector<char *> &)args;

@end
