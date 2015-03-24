#include "vim.h"

#import "app.h"
#import "view.h"
#import "redraw.h"

Vim *vim = 0;
VimView *mainView = 0;
NSWindow *window = 0;

@interface WindowDelegate : NSObject <NSWindowDelegate> {} @end
@implementation WindowDelegate

/* Override this so we can resize by whole cells, just like Terminal.app */
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    NSRect frameRect = {CGPointZero, frameSize};

    NSRect contentRect = [sender contentRectForFrameRect:frameRect];

    CGSize cellSize = [mainView cellSizeInsideViewSize:contentRect.size];
    [mainView requestResize:cellSize];

    contentRect.size = [mainView viewSizeFromCellSize:cellSize];
    frameRect = [sender frameRectForContentRect:contentRect];

    return frameRect.size;
}

/* OS X doesn't send us a willResize event when leaving fullscreen mode, so: */
- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    [self windowWillResize:window toSize:[window frame].size];
}

@end

@implementation AppDelegate

- (void)newTab { vim->vim_command("tabnew"); }
- (void)nextTab { vim->vim_command("tabnext"); }
- (void)prevTab { vim->vim_command("tabprev"); }
- (void)closeTab { vim->vim_command("tabclose"); }

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [self initMenu];

    int width = 80;
    int height = 25;

    NSString *vimDir = [[NSBundle mainBundle] resourcePath];
    NSString *vimPath = [[NSBundle mainBundle] pathForResource:@"nvim"
                                                        ofType:nil];


    setenv("VIM", [vimDir UTF8String], 1);
    vim = new Vim([vimPath UTF8String]);
    vim->ui_attach(width, height, true);

    mainView = [[VimView alloc] initWithCellSize:CGSizeMake(width, height)
                                             vim:vim];

    int style = NSTitledWindowMask |
                NSClosableWindowMask |
                NSMiniaturizableWindowMask |
                NSResizableWindowMask;

    window = [[[NSWindow alloc] initWithContentRect:[mainView frame]
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                              defer:YES] retain];

    [window setContentView:mainView];
    [window makeFirstResponder:mainView];
    [window setDelegate:[[WindowDelegate alloc] init]];
    [window makeKeyAndOrderFront:NSApp];
    [window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

    [NSThread detachNewThreadSelector:@selector(vimThread:)
                             toTarget:self
                           withObject:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification 
{
}

/* This gets called on the main thread when Vim gives us a UI notification */
- (void)notified:(const std::string &)note withData:(const msgpack::object &)update_o
{
    assert([NSThread isMainThread]);

    if (note == "redraw") {

        /* There must be a better way of finding out when the current buffer
           has changed? Until we figure one out, update title every redraw. */
        [self updateWindowTitle];
        [mainView redraw:update_o];
    }
    else {
        std::cout << "Unknown note " << note << "\n";
    }
}

/* Set the window's title and “represented file” icon. */
- (void)updateWindowTitle
{
    vim->vim_get_current_buffer().then([](Buffer buf) {
        vim->buffer_get_name(buf).then([](std::string bufname) {
            if (bufname.empty()) {
                [window setTitle:@"Untitled"];
                [window setRepresentedFilename:@""];
                return;
            }

            NSString *nsBufname =
                [NSString stringWithUTF8String:bufname.c_str()];

            if ([[NSFileManager defaultManager] fileExistsAtPath:nsBufname]) {
                [window setTitleWithRepresentedFilename:nsBufname];
            }
            else {
                [window setTitleWithRepresentedFilename:nsBufname];
                [window setRepresentedFilename:@""];
            }
        });
    });
}


/* A selector to this method is posted to the main runloop in order to handle
   an event from Vim on the main thread. */
- (void)handleEvent:(id)idEvent
{
    assert([NSThread isMainThread]);

    Event *event = (Event *)[(NSValue *)idEvent pointerValue];
    RPC *rpc = event->rpc;

    if (rpc) {
        if (rpc->callback)
            rpc->callback(rpc->get_value(), rpc->get_error());

        delete rpc;
    }

    if (!event->note.empty()) {
        [self notified:event->note withData:event->note_arg];
    }
}


/* Vim thread. Waits for events from Vim, and schedules them to be handled on 
   the main thread. */
- (void)vimThread:(id)unused
{
    assert(![NSThread isMainThread]);

    for (;;) {
        Event event = vim->wait();

        /* waitUntilDone needs to be YES here since we're accessing that
           event from the other thread. */
        [self performSelectorOnMainThread:@selector(handleEvent:)
                               withObject:[NSValue valueWithPointer:&event]
                            waitUntilDone:YES];
    }
}

@end
