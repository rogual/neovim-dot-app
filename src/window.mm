#include "vim.h"

#import "window.h"
#import "redraw.h"

@implementation VimWindow
{
    Vim * vim;
    VimView * mMainView;
}

/* Override this so we can resize by whole cells, just like Terminal.app */
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    NSRect frameRect = {CGPointZero, frameSize};

    NSRect contentRect = [sender contentRectForFrameRect:frameRect];

    CGSize cellSize = [mMainView cellSizeInsideViewSize:contentRect.size];
    [mMainView requestResize:cellSize];

    contentRect.size = [mMainView viewSizeFromCellSize:cellSize];
    frameRect = [sender frameRectForContentRect:contentRect];

    return frameRect.size;
}

/* OS X doesn't send us a willResize event when leaving fullscreen mode, so: */
- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    [self windowWillResize:self toSize:[self frame].size];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    vim->vim_command("silent! doautoall <nomodeline> FocusGained");
    vim->vim_command("checktime");
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    vim->vim_command("silent! doautoall <nomodeline> FocusLost");
}


- (void)copyText { [mMainView copyText]; }
- (void)cutText { [mMainView cutText]; }
- (void)pasteText { [mMainView pasteText]; }

- (void)newTab { vim->vim_command("tabnew"); }
- (void)nextTab { vim->vim_command("tabnext"); }
- (void)prevTab { vim->vim_command("tabprev"); }
- (void)closeTab { vim->vim_command("tabclose"); }
- (void)saveBuffer { vim->vim_command("write"); }


- (id)init
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int width = [defaults integerForKey:@"width"];
    int height = [defaults integerForKey:@"height"];

    if (width <= 0 || height <= 0) {
        width = 80;
        height = 25;
    }

    NSString *vimPath = [[NSBundle mainBundle] pathForResource:@"nvim"
                                                        ofType:nil];

    vim = new Vim([vimPath UTF8String]);
    vim->ui_attach(width, height, true);

    mMainView = [[VimView alloc] initWithCellSize:CGSizeMake(width, height)
                                             vim:vim];

    int style = NSTitledWindowMask |
                NSClosableWindowMask |
                NSMiniaturizableWindowMask |
                NSResizableWindowMask;

    self = [super initWithContentRect:[mMainView frame]
                                    styleMask:style
                                    backing:NSBackingStoreBuffered
                                    defer:YES];
    if(!self) return nil;

    [self setContentView:mMainView];
    [self makeFirstResponder:mMainView];
    [self setDelegate:self];
    [self makeKeyAndOrderFront:NSApp];
    [self setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

    [NSThread detachNewThreadSelector:@selector(vimThread:)
                             toTarget:self
                           withObject:nil];

    return self;
}

- (void)dealloc
{
    delete vim; vim = nil;
    [super dealloc];
}

- (void)openFilename:(NSString *)file
{
        [mMainView openFile:file];
}

/* This gets called on the main thread when Vim gives us a UI notification */
- (void)notified:(const std::string &)note withData:(const msgpack::object &)update_o
{
    assert([NSThread isMainThread]);

    if (note == "redraw") {

        /* There must be a better way of finding out when the current buffer
           has changed? Until we figure one out, update title every redraw. */
        [self updateWindowTitle];
        [mMainView redraw:update_o];
    }
    else if (note == "neovim.app.nodata") {
        /* The vim client closed our pipe, so it must have exited. */
        [self close];
    }
    else {
        std::cout << "Unknown note " << note << "\n";
    }
}

/* Set the window's title and “represented file” icon. */
- (void)updateWindowTitle
{
    vim->vim_get_current_buffer().then([self](Buffer buf) {
        vim->buffer_get_name(buf).then([self](std::string bufname) {
            if (bufname.empty()) {
                [self setTitle:@"Untitled"];
                [self setRepresentedFilename:@""];
                return;
            }

            NSString *nsBufname =
                [NSString stringWithUTF8String:bufname.c_str()];

            if ([[NSFileManager defaultManager] fileExistsAtPath:nsBufname]) {
                [self setTitleWithRepresentedFilename:nsBufname];
            }
            else {
                [self setTitleWithRepresentedFilename:nsBufname];
                [self setRepresentedFilename:@""];
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
