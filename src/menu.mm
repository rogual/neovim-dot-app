#include "app.h"

@implementation AppDelegate (Menus)

/* Create our anaemic menu bar. TODO: Ask Vim for its menus */
- (void) initMenu
{
    NSMenu *menu, *sub;
    NSMenuItem *mi;

    menu = [[NSMenu alloc] initWithTitle: @""];

    sub = [[NSMenu alloc] initWithTitle:@"NeoVim"];
    [sub addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    sub = [[NSMenu alloc] initWithTitle:@"File"];
    [sub addItemWithTitle:@"New Tab" action:@selector(newTab) keyEquivalent:@"t"];
    [sub addItemWithTitle:@"Close Tab" action:@selector(closeTab) keyEquivalent:@"w"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    sub = [[NSMenu alloc] initWithTitle:@"Edit"];
    [sub addItemWithTitle:@"Cut" action:@selector(cutText) keyEquivalent:@"x"];
    [sub addItemWithTitle:@"Copy" action:@selector(copyText) keyEquivalent:@"c"];
    [sub addItemWithTitle:@"Paste" action:@selector(pasteText) keyEquivalent:@"v"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    sub = [[NSMenu alloc] initWithTitle:@"View"];
    mi = [sub addItemWithTitle:@"Toggle Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
    [mi setKeyEquivalentModifierMask: NSControlKeyMask | NSCommandKeyMask];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    sub = [[NSMenu alloc] initWithTitle:@"Window"];
    [sub addItemWithTitle:@"Show Previous Tab" action:@selector(prevTab) keyEquivalent:@"{"];
    [sub addItemWithTitle:@"Show Next Tab" action:@selector(nextTab) keyEquivalent:@"}"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    [NSApp setMainMenu:menu];
}

@end
