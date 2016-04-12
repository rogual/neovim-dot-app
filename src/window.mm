#include "vim.h"

#import "window.h"
#import "redraw.h"
#import "menu.h"
#import "app.h"

@implementation VimWindow
{
    Vim *mVim;
    VimView *mMainView;
    NSThread *mVimThread;
}

typedef NS_ENUM(NSInteger, CloseAction) {
    CloseActionSave,
    CloseActionDontSave,
    CloseActionSaveAll,
    CloseActionDiscardAll,
    CloseActionCancel
};


/* Override this so we can resize by whole cells, just like Terminal.app */
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    NSRect frameRect = {CGPointZero, frameSize};

    NSRect contentRect = [sender contentRectForFrameRect:frameRect];

    CGSize cellSize = [mMainView cellSizeInsideViewSize:contentRect.size];
    [mMainView requestResize:cellSize];

    contentRect.size = [mMainView viewSizeFromCellSize:cellSize];
    frameRect = [sender frameRectForContentRect:contentRect];

    // update the view resize and save
    [mMainView viewDidEndLiveResize];

    return frameRect.size;
}

- (BOOL)windowShouldClose:(id)sender
{
    [self promptBeforeClosingWindow];
    return NO;
}

- (void)promptBeforeClosingWindow
{
    mVim->vim_command_output("call MacGetDirtyBuffers()")
        .then([self](std::string dirtyBufs){
            /* A list of modified/dirty buffers are returned with the buffer
               number and name. All seperated by newlines */
            if (dirtyBufs.length() <= 1)
                /* All good. Nothing to save */
                [self close];

            /* A newline is at the beginning of the string */
            dirtyBufs.erase(dirtyBufs.begin());

            std::stringstream saveCmd;
            std::stringstream ss(dirtyBufs);

            BOOL shouldClose  = YES;
            BOOL isSaveAll    = NO;
            int numBuffers = std::count(dirtyBufs.begin(), dirtyBufs.end(), '\n') / 2;
            for (int x = numBuffers; x > 0; x--) {
                NSModalResponse resp;
                BOOL saveThis = NO;
                std::string bufnr, filename;

                std::getline(ss, bufnr, '\n');
                std::getline(ss, filename, '\n');

                if (!isSaveAll) {
                    resp = [self alertSaveFileBeforeClose:filename saveMultiple:(x == 1) ? NO : YES];
                    if (resp == CloseActionSave)
                        saveThis = YES;
                    else if(resp == CloseActionDontSave)
                        continue;
                    else if(resp == CloseActionSaveAll)
                        isSaveAll = YES;
                    else if(resp == CloseActionDiscardAll)
                        break;
                    else {
                        shouldClose = NO;
                        break;
                    }
                }

                if (isSaveAll || saveThis) {
                    std::string newFilename = "";
                    saveCmd << "b" << bufnr;
                    if (filename == "") {
                        /* If the buffer has no name,  prompt for it to be saved.
                           If the action is canceled, the loop is ended and the
                           unnamed buffer is not saved. All other buffers that
                           have been set to save prior to this point will be saved. */
                        NSURL *file = [mMainView showFileSaveDialog];
                        if (file == nil) {
                            shouldClose = NO;
                            break;
                        }
                        newFilename = [self escapeVimCharsInString:[[file path] UTF8String]];
                    }
                    saveCmd << " | w! " << newFilename << " | ";
                }
            }

            if (shouldClose)
                saveCmd << "qa!";

            /* Perform the saves. and Exit if specified. Don't exit if there is an error */
            mVim->vim_command(saveCmd.str())
                .then([self](msgpack::object error){
                    if (error.is_nil())
                        return;

                    std::string errmsg = error.via.array.ptr[1].convert();
                    errmsg = errmsg.substr(errmsg.find(":")+1);
                    mVim->vim_report_error(errmsg);
                });
        });
}

- (CloseAction)alertSaveFileBeforeClose:(std::string)fileName saveMultiple:(bool)isMulti
{
    NSString *msgText = @"";
    int response=-1;

    if (isMulti)
        msgText = [msgText stringByAppendingString:@"There are several documents with unsaved changes. "];

    if (fileName == "")
        fileName = "Untitled";

    msgText = [msgText stringByAppendingFormat:@"Do you want to save the changes you made in the document \"%s\"?",
            fileName.c_str()];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msgText];
    [alert setInformativeText:@"Your changes will be lost if you don't save them."];

    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Don't Save"];
    if (isMulti)
    {
        [alert addButtonWithTitle:@"Save All"];
        [alert addButtonWithTitle:@"Discard All"];
    }
    [alert addButtonWithTitle:@"Cancel"];

    switch([alert runModal])
    {
        case NSAlertFirstButtonReturn:
            return CloseActionSave;
        case NSAlertSecondButtonReturn:
            return CloseActionDontSave;
        case NSAlertThirdButtonReturn:
            return (isMulti) ? CloseActionSaveAll : CloseActionCancel;
        case NSAlertThirdButtonReturn+1:
            return CloseActionDiscardAll;
        case NSAlertThirdButtonReturn+2:
            return CloseActionCancel;
    }
    return CloseActionCancel;
}

/* OS X doesn't send us a willResize event when leaving fullscreen mode, so: */
- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    [self windowWillResize:self toSize:[self frame].size];
}

- (void)windowDidChangeBackingProperties:(NSNotification *)notification
{
    [self windowWillResize:self toSize:[self frame].size];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    mVim->vim_command("silent! doautoall <nomodeline> FocusGained");
    mVim->vim_command("checktime");
    [mMainView showMenu];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    mVim->vim_command("silent! doautoall <nomodeline> FocusLost");
}

- (void)copyText { [mMainView copyText]; }
- (void)cutText { [mMainView cutText]; }
- (void)pasteText { [mMainView pasteText]; }

- (void)newTab { mVim->vim_command("tabnew"); }
- (void)nextTab { mVim->vim_command("tabnext"); }
- (void)prevTab { mVim->vim_command("tabprev"); }
- (void)saveBuffer { mVim->vim_command("write"); }
- (void)closeTabOrWindow
{
    mVim->vim_get_tabpages().then([self](msgpack::object o) {
            if (o.via.array.size > 1)
                mVim->vim_command("tabclose");
            else
                [self promptBeforeClosingWindow];
        });
}

- (id)init
{
    std::vector<char *> no_args;
    return [self initWithArgs:no_args];
}

- (id)initWithArgs:(const std::vector<char *> &)args
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int left = [defaults integerForKey:@"left"];
    int bottom = [defaults integerForKey:@"bottom"];
    int width = [defaults integerForKey:@"width"];
    int height = [defaults integerForKey:@"height"];

    if (width <= 0 || height <= 0) {
        width = 80;
        height = 25;
    }

    NSString *vimPath = [[NSBundle mainBundle] pathForResource:@"nvim"
                                                        ofType:nil];

    mVim = new Vim([vimPath UTF8String], args);
    mVim->ui_attach(width, height, true);

    /* Reload .nvimrc after connecting to get any settings requiring
       gui_running to be re-evaluated as true.
       This should be removed after an implementation similar to
       https://github.com/neovim/python-client/issues/106
       is done. */
    mVim->vim_command("so $MYVIMRC");

    /* As a courtesy, warn if any T- mappings are set */
    mVim->vim_command_output("silent map").then([self](std::string mappings) {
        if (mappings.find("T-") != std::string::npos) {
            mVim->vim_report_error(
              "<T-...> is now <D-...>. Please update your mappings.\n"
              "For details: https://github.com/rogual/neovim-dot-app/issues/214"
            );
        }
    });

    mMainView = [[VimView alloc] initWithCellSize:CGSizeMake(width, height)
                                              vim:mVim];

    int style = NSTitledWindowMask |
                NSClosableWindowMask |
                NSMiniaturizableWindowMask |
                NSResizableWindowMask;


    NSRect frame = [mMainView frame];
    frame.origin.x = left;
    frame.origin.y = bottom;

    self = [super initWithContentRect:frame
                                    styleMask:style
                                    backing:NSBackingStoreBuffered
                                    defer:YES];
    if(!self) return nil;

    [self setContentView:mMainView];
    [self makeFirstResponder:mMainView];
    [self setDelegate:self];
    [self makeKeyAndOrderFront:NSApp];
    [self setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

    mVimThread = [[NSThread alloc] initWithTarget:self selector:@selector(vimThread:) object:nil];
    [mVimThread start];

    return self;
}

- (void)dealloc
{
    delete mVim;
    mVim = 0;
    [super dealloc];
}

- (void)openFilename:(NSString *)file
{
    [mMainView openFile:file];
}

- (void) saveFileDoSaveAs:(BOOL)isSaveAs
{
    NSURL *file = [mMainView showFileSaveDialog];
    if (file != nil)
    {
        std::stringstream cmd;
        if (isSaveAs)
            cmd << "sav! ";
        else
            cmd << "w! ";

        cmd << [self escapeVimCharsInString:[[file path] UTF8String]];
        mVim->vim_command(cmd.str()).then([self](msgpack::object err){
                if (err.is_nil()) return;
                std::string errmsg = err.via.array.ptr[1].convert();
                errmsg = errmsg.substr(errmsg.find(":")+1);
                mVim->vim_report_error(errmsg);
            });
    }

}

/* This gets called on the main thread when Vim gives us a UI notification */
- (void)notified:(const std::string &)note withData:(const msgpack::object &)update_o
{
    assert([NSThread isMainThread]);

    if (note == "redraw") {
        [mMainView redraw:update_o];
    }
    else if (note == "neovim.app.updateTitle") {
        [self updateWindowTitle];
    }
    else if (note == "neovim.app.nodata") {
        /* The vim client closed our pipe, so it must have exited. */
        [mVimThread cancel];
        [self close];
    }
    else if (note == "neovim.app.menu") {
        [mMainView customizeMenu:update_o];
    }
    else if (note == "neovim.app.window") {
        AppDelegate *app = (AppDelegate *)[NSApp delegate];
        [app newWindow];
    }
    else if (note == "neovim.app.openFile") {
        NSArray *files = [mMainView showFileOpenDialog];
        if (files != nil) {
            std::vector<char *> args;

            /* open in tabs if more than one file was selected */
            if ([files count] > 1)
                args.push_back(const_cast<char *>("-p"));

            for (NSURL *url in files)
                args.push_back(const_cast<char *>([[url path] UTF8String]));

            AppDelegate *app = (AppDelegate *)[NSApp delegate];
            [app newWindowWithArgs:args];
        }
    }
    else if (note == "neovim.app.saveFile") {
        [self saveFileDoSaveAs:NO];
    }
    else if (note == "neovim.app.saveAsFile") {
        [self saveFileDoSaveAs:YES];
    }
    else if (note == "neovim.app.larger") {
        [mMainView increaseFontSize];
    }
    else if (note == "neovim.app.smaller") {
        [mMainView decreaseFontSize];
    }
    else if (note == "neovim.app.showfonts") {
        [mMainView showFontSelector];
    }
    else if (note == "neovim.app.fullscreen") {
        [self toggleFullScreen:nil];
    }
    else if (note == "neovim.app.setfont") {
        std::vector<msgpack::object> args = update_o.convert();

        try {
            if (args.size() != 2) {
                throw "setfont expects 2 arguments (name, size)";
            }

            std::string name = args[0].convert();
            int size = args[1].convert();

            NSString *nsName = [NSString stringWithUTF8String:name.c_str()];
            NSFont *font = [NSFont fontWithName:nsName size:size];

            if (!font) {
                throw std::string() + "Font '" + name + "' not installed";
            }

            if (([[font fontDescriptor] symbolicTraits] & NSFontMonoSpaceTrait) == 0) {
                throw std::string() + "Font '" + name + "' does not appear to "
                    "be fixed-width";
            }

            [mMainView setFontProgramatically:font];
        }
        catch (std::string msg) {
            mVim->vim_report_error(msg);
        }
    }
    else if (note ==  "neovim.app.bufchanged") {
        int isModified = update_o.via.array.ptr[0].convert();
        [self setDocumentEdited:isModified?YES:NO];
    }
    else if (note ==  "neovim.app.closeTabOrWindow") {
        [self closeTabOrWindow];
    }
    else {
        std::cout << "Unknown note " << note << "\n";
    }
}


/* Escapes characters that vim uses in command mode.  */
- (std::string) escapeVimCharsInString:(std::string) str
{
    std::stringstream escapedStr;
    for (auto c : str)
    {
        if (strchr("\" `#%*[{}]\\|", c))
            escapedStr << "\\";
        escapedStr << c;
    }
    return escapedStr.str();
}

/* Set the window's title and “represented file” icon. */
- (void)updateWindowTitle
{
    mVim->vim_get_current_buffer().then([self](Buffer buf) {
        mVim->buffer_get_name(buf).then([self](std::string bufname) {
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
        if ([[NSThread currentThread] isCancelled])
            [NSThread exit];

        Event event = mVim->wait();
        /* waitUntilDone needs to be YES here since we're accessing that
           event from the other thread. */
        [self performSelectorOnMainThread:@selector(handleEvent:)
                               withObject:[NSValue valueWithPointer:&event]
                            waitUntilDone:YES];

    }
}

@end
