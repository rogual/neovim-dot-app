#include <string.h>

#include "vim.h"

#import "app.h"
#import "window.h"
#import "view.h"
#import "redraw.h"
#import "font.h"

extern char **g_argv;
extern int g_argc;

static VimWindow *activeWindow = 0;

void ignore_sigpipe(void)
{
    struct sigaction act;
    int r;
    memset(&act, 0, sizeof(act));
    act.sa_handler = SIG_IGN;
    act.sa_flags = SA_RESTART;
    r = sigaction(SIGPIPE, &act, NULL);
    if (r) {
        std::cerr << "Failed to ignore SIGPIPE\n";
        exit(-1);
    }
}

@implementation AppDelegate

- (NSDictionary *)environmentFromLoginShell:(NSString *)shellPath
{
    if (!shellPath.length) {
        return nil;
    }

    NSArray *args = @[@"-i", shellPath, @"-l", @"-c", @"\"env\""];
    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/bin/env";
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

- (void)newWindow
{
    activeWindow = [[[VimWindow alloc] init] retain];
}

- (void)newWindowWithArgs:(const std::vector<char *> &)args
{
    activeWindow = [[[VimWindow alloc] initWithArgs:args] retain];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if ([activeWindow isVisible]) {
        [activeWindow promptBeforeClosingWindow];
        return NSTerminateCancel;
    }

    return NSTerminateNow;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
    return YES;
}

/* Makes sure that there is a "Fixed Width" collection.
   If there isn't it creates a collection called "Fixed Width"
   adds all monospace fonts to it */
- (void)ensureFixedWidthCollection
{
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFontCollection *collection =
        [NSFontCollection fontCollectionWithName:@"com.apple.AllFonts"];

    NSMutableArray *descriptors = [[NSMutableArray alloc] init];
    for (NSFontDescriptor *desc in [collection matchingDescriptors])
    {
        NSString *name = [desc objectForKey:NSFontNameAttribute];
        if ([desc symbolicTraits] & NSFontMonoSpaceTrait){
            [descriptors addObject:desc];
        }
    }

    collection = [NSFontCollection fontCollectionWithDescriptors:descriptors];

    /* Add collection only to this process */
    [NSFontCollection showFontCollection:collection
        withName:@"Neovim Monospaced"
        visibility:NSFontCollectionVisibilityProcess
        error:NULL];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    didFinishLaunching = NO;

    [NSFontManager setFontManagerFactory:[VimFontManager class]];
    [self ensureFixedWidthCollection];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"width": @80,
                                 @"height": @25,
                                 @"fontName": @"Menlo",
                                 @"fontSize": @11.0}];

    [self loadLoginShellEnvironmentVariables];

    /* Closing vim subprocesses can result in a SIGPIPE, terminating
       the program. So, we ignore it. */
    ignore_sigpipe();

    NSString *vimDir = [[NSBundle mainBundle] resourcePath];
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
    setenv("NVIM_TUI_ENABLE_TRUE_COLOR", "1", 1);

    /* Set working dir */
    const char *cwd = 0;

    /* Parent PID = 1 then Neovim.app was ran by launchd. In these cases
       working directory is set to "/". Change to the user's home directory. */
    if (getppid() == 1)
        cwd = getenv("HOME");

    /* Set CWD if given on command line */
    for (int i=0; i<g_argc-1; i++) {
      if (!strcmp("--cwd", g_argv[i])) {
        cwd = g_argv[i + 1];
        break;
      }
    }

    if (cwd)
        chdir(cwd);
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    /* Pass args on to Neovim. OSX will helpfully add a -psn_XXX arg
       which Neovim would choke on, so strip it out. */
    std::vector<char *> args;

    if (initOpenFile != NULL) {
      args.push_back(const_cast<char *>([initOpenFile UTF8String]));
    }

    for (int i = 1; i < g_argc ; i++) {
        if (!strncmp("-psn_", g_argv[i], 5))
          continue;

        if (!strcmp("--cwd", g_argv[i])) {
          i += 1;
          continue;
        }

        args.push_back(g_argv[i]);
    }
    [self newWindowWithArgs:args];

    didFinishLaunching = YES;
}

/* OSX calls this when the user opens a file with us through Finder. But, that
   alone would be too easy, so it ALSO parses our command line arguments for
   us, decides what it thinks is a filename, and calls this for those too.
   Hence the initOpenFile and didFinishLaunching dance. */
- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
    if (didFinishLaunching) {
        std::vector<char *> args;
        args.push_back(const_cast<char *>([filename UTF8String]));
        activeWindow = [[[VimWindow alloc] initWithArgs:args] retain];
    }
    else {
        initOpenFile = filename;
        [initOpenFile retain];
    }
    return YES;
}

@end
