#include <iostream>
#include "vim.h"
#import <Cocoa/Cocoa.h>
#import "app.h"

int main()
{
    [NSApplication sharedApplication];

    AppDelegate *delegate = [[AppDelegate alloc] init];

    [NSApp setDelegate: (id<NSFileManagerDelegate>)delegate];
    [NSApp run];
}
