#include "vim.h"

#import "app.h"
#import "window.h"
#import "view.h"
#import "redraw.h"
#import "font.h"

extern int g_argc;
extern char **g_argv;

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

- (void)newWindow
{
    activeWindow = [[[VimWindow alloc] init] retain];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
    return YES;
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

    [self newWindow];

    // Open files given on command-line
    for (int i=1; i<g_argc; i++) {
        [activeWindow openFilename:[NSString stringWithUTF8String:g_argv[i]]];
    }
}

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
    [activeWindow openFilename:filename];
    return YES;
}


@end
