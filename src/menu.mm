#include "app.h"

@implementation AppDelegate (Menus)

/* Create our anaemic menu bar. TODO: Ask Vim for its menus */
- (void) initMenu
{
    NSMenu* appMenu = [[NSMenu alloc] initWithTitle:@"NeoVim"];
    [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];

    NSMenu* menu = [[NSMenu alloc] initWithTitle: @""];
    NSMenuItem* mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:appMenu];

    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"New Tab" action:@selector(newTab) keyEquivalent:@"t"];
    [fileMenu addItemWithTitle:@"Close Tab" action:@selector(closeTab) keyEquivalent:@"w"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:fileMenu];

    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Show Previous Tab" action:@selector(prevTab) keyEquivalent:@"{"];
    [windowMenu addItemWithTitle:@"Show Next Tab" action:@selector(nextTab) keyEquivalent:@"}"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:windowMenu];

    [NSApp setMainMenu:menu];
}

@end
