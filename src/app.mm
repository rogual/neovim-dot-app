#include "vim.h"

#import "app.h"
#import "view.h"
#import "redraw.h"

Vim *vim = 0;
VimView *mainView = 0;
NSWindow *window = 0;

std::string bufname;

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

@end

@implementation AppDelegate

- (void)newTab { vim->vim_command("tabnew"); }
- (void)nextTab { vim->vim_command("tabnext"); }
- (void)prevTab { vim->vim_command("tabprev"); }
- (void)closeTab { vim->vim_command("tabclose"); }

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [self initMenu];

    NSRect frame = NSMakeRect(0, 0, 7 * 80, 17 * 25);

    int style = NSTitledWindowMask |
                NSClosableWindowMask |
                NSMiniaturizableWindowMask |
                NSResizableWindowMask;


    window = [[[NSWindow alloc] initWithContentRect: frame
                                         styleMask: style
                                         backing: NSBackingStoreBuffered
                                         defer: YES] retain];

    NSString *vimPath = [[NSBundle mainBundle] pathForResource:@"nvim"
                                                        ofType:nil];

    vim = new Vim([vimPath UTF8String]);
    vim->ui_attach(80, 25, true);

    mainView = [[VimView alloc] initWithFrame:frame vim:vim];

    [window setContentView:mainView];
    [window makeFirstResponder:mainView];
    [window setDelegate:[[WindowDelegate alloc] init]];
    [window setTitle:@"NeoVim"];
    [window makeKeyAndOrderFront:NSApp];
    [mainView setFrameSize:frame.size];

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

        // Update the buffer name -- is there a more specific event for this? For now
        // let's do it on redraw.
        vim->vim_get_current_buffer().then([](Buffer buf) {
            vim->buffer_get_name(buf).then([](std::string new_bufname) {
                if (new_bufname.size() && new_bufname != bufname) {
                    bufname = new_bufname;
                    [window setTitleWithRepresentedFilename:[NSString stringWithUTF8String:bufname.c_str()]];
                }
            });
        });

        [mainView redraw:update_o];


    }
    else {
        std::cout << "Unknown note " << note << "\n";
    }
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
