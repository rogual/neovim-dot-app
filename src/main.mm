#include <iostream>
#include "vim.h"
#import <Cocoa/Cocoa.h>
#import "app.h"

int g_argc;
char **g_argv;

int main(int argc, char **argv)
{
    g_argc = argc;
    g_argv = argv;

    [NSApplication sharedApplication];

    AppDelegate *delegate = [[AppDelegate alloc] init];

    [NSApp setDelegate: delegate];
    [NSApp run];
}
