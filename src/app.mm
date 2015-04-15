#include "vim.h"

#import "app.h"
#import "view.h"
#import "redraw.h"
#import "font.h"

extern int g_argc;
extern char **g_argv;

static Vim *vim = 0;
static VimView *mainView = 0;
static NSWindow *window = 0;

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

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    vim->vim_command("silent! doautoall <nomodeline> FocusGained");
    vim->vim_command("checktime");
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    vim->vim_command("silent! doautoall <nomodeline> FocusLost");
}

@end

@implementation AppDelegate

- (void)copyText { [mainView copyText]; }
- (void)cutText { [mainView cutText]; }
- (void)pasteText { [mainView pasteText]; }

- (void)newTab { vim->vim_command("tabnew"); }
- (void)nextTab { vim->vim_command("tabnext"); }
- (void)prevTab { vim->vim_command("tabprev"); }
- (void)closeTab { vim->vim_command("tabclose"); }
- (void)saveBuffer { vim->vim_command("write"); }

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
    return YES;
}

- (NSDictionary *)environmentFromLoginShell:(NSString *)shellPath
{
    if (!shellPath.length) {
        return nil;
    }

    NSArray *args = @[@"-l", @"-c", @"\"env\""];
    NSTask *task = [NSTask new];
    task.launchPath = shellPath;
    task.arguments = args;
    task.standardOutput = [NSPipe new];
    task.standardError = [NSPipe new];
    [task launch];
    [task waitUntilExit];

    if (task.terminationStatus != EXIT_SUCCESS) {
        NSData *stderrData = ((NSPipe *)task.standardError).fileHandleForReading.readDataToEndOfFile;
        NSString *stderror = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
        NSLog(@"%@ %@ failed: %@", task.launchPath, [task.arguments componentsJoinedByString:@" "], stderror);
        return nil;
    }

    NSData *stdoutData = ((NSPipe *)task.standardOutput).fileHandleForReading.readDataToEndOfFile;
    NSString *envString = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
    NSArray *envVars = [envString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableDictionary *env = [NSMutableDictionary new];

    for (NSString *s in envVars) {
        NSArray *keyvalue = [s componentsSeparatedByString:@"="];

        if (keyvalue.count < 2) {
            continue;
        }

        NSString *key = keyvalue[0];
        NSString *value = keyvalue[1];

        env[key] = value;
    }

    return env;
}

/* Attempt to get the environment dictionary for the user's chosen shell, using
   the $SHELL environment variable.

   If that fails, try again using /bin/bash, which should always be available
   on OSX. */
- (void)loadLoginShellEnvironmentVariables
{
    NSString *shellPath = [[NSProcessInfo processInfo] environment][@"SHELL"];
    NSDictionary *env = [self environmentFromLoginShell:shellPath];
    if (!env) {
        shellPath = @"/bin/bash";
        env = [self environmentFromLoginShell:shellPath];
    }

    if (!env) {
        NSLog(@"Couldn't get environment from $SHELL or /bin/bash, defaulting to existing environment.");
    } else {
        [env enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            setenv(key.UTF8String, value.UTF8String, 1);
        }];
    }
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    [NSFontManager setFontManagerFactory:[VimFontManager class]];
    [self initMenu];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"width": @80,
                                 @"height": @25,
                                 @"fontName": @"Menlo",
                                 @"fontSize": @11.0}];

    int width = [defaults integerForKey:@"width"];
    int height = [defaults integerForKey:@"height"];

    if (width <= 0 || height <= 0) {
        width = 80;
        height = 25;
    }

    NSString *vimDir = [[NSBundle mainBundle] resourcePath];
    NSString *vimPath = [[NSBundle mainBundle] pathForResource:@"nvim"
                                                        ofType:nil];

    [self loadLoginShellEnvironmentVariables];

    /* Set both VIM and NVIM for now. TODO: Remove VIM when
       https://github.com/neovim/neovim/pull/1927 is merged */
    setenv("VIM", [vimDir UTF8String], 1);
    setenv("NVIM", [vimDir UTF8String], 1);

    /* Since Vim is also a terminal emulator these days, it'll be useful to
       have the right locale set. Force UTF-8 too since that's what we'll
       be sending. */
    NSLocale *locale = [NSLocale currentLocale];
    NSString *lang = [locale objectForKey:NSLocaleLanguageCode];
    NSString *country = [locale objectForKey:NSLocaleCountryCode];
    std::stringstream ss;
    ss << [lang UTF8String];
    if ([country length])
        ss << "_" << [country UTF8String];
    ss << ".UTF-8";
    setenv("LC_ALL", ss.str().c_str(), 1);
    setenv("LANG", ss.str().c_str(), 1);

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

    // Open files given on command-line
    for (int i=1; i<g_argc; i++) {
        [mainView openFile:[NSString stringWithUTF8String:g_argv[i]]];
    }
}

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
    [mainView openFile:filename];
    return YES;
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
