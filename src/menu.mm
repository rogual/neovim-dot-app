#include "app.h"

/* The Cocoa font menu contains stuff we don't want, like color, ligatures,
    etc., so make our own font menu (with texas hold 'em and loose women) and
    add only the best menu items. */
static NSMenu *makeFontMenu()
{
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSMenu *cocoaFontMenu = [fontManager fontMenu:YES];
    NSMenu *sub = [[NSMenu alloc] initWithTitle:@"Font"];
    bool sep = false;
    for (NSMenuItem *item in [cocoaFontMenu itemArray]) {
        SEL action = [item action];
        bool want = false;

        if (action == @selector(modifyFont:)) want = true;
        if (action == @selector(orderFrontFontPanel:)) want = true;

        if (!action && !sep) {
            sep = true;
            want = true;
        }

        if (action)
            sep = false;

        if (want)
        {
            [cocoaFontMenu removeItem:item];
            [sub addItem:item];
        }
    }
    return sub;
}

@implementation AppDelegate (Menus)

/* Create our anaemic menu bar. TODO: Ask Vim for its menus */
- (void) initMenu
{
    NSMenu *menu, *sub;
    NSMenuItem *mi;

    menu = [[NSMenu alloc] initWithTitle: @""];

    sub = [[NSMenu alloc] initWithTitle:@"Neovim"];
    [sub addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    sub = [[NSMenu alloc] initWithTitle:@"File"];
    [sub addItemWithTitle:@"New Window" action:@selector(newWindow) keyEquivalent:@"n"];
    [sub addItemWithTitle:@"New Tab" action:@selector(newTab) keyEquivalent:@"t"];
    [sub addItemWithTitle:@"Close Tab" action:@selector(closeTab) keyEquivalent:@"w"];
    [sub addItemWithTitle:@"Save Buffer" action:@selector(saveBuffer) keyEquivalent:@"s"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    sub = [[NSMenu alloc] initWithTitle:@"Edit"];
    [sub addItemWithTitle:@"Cut" action:@selector(cutText) keyEquivalent:@"x"];
    [sub addItemWithTitle:@"Copy" action:@selector(copyText) keyEquivalent:@"c"];
    [sub addItemWithTitle:@"Paste" action:@selector(pasteText) keyEquivalent:@"v"];
    [sub addItemWithTitle:@"Select All" action:@selector(selectAll) keyEquivalent:@"a"];
    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [mi setSubmenu:sub];

    mi = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    sub = makeFontMenu();
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
