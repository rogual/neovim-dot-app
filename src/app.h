#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSResponder <NSApplicationDelegate> {
    BOOL didFinishLaunching;
    std::vector<char *> initOpenFiles;
    BOOL openFilesInNewWindow;
}

- (void) newWindow;
- (void) newWindowWithArgs:(const std::vector<char *> &)args;
- (void) setOpenFilesInNewWindow:(BOOL)openFilesInNewWindow;

@end
