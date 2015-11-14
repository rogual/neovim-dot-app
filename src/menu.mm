#include "vim.h"
#include "vimutils.h"

#import "app.h"
#import "window.h"
#import "menu.h"

#include <iostream>

struct MenuInfo {
    std::string keyEquivalent;
    unsigned modifierMask;
};

std::map<std::string, MenuInfo> infoMap;

MenuInfo parseKeyEquivalent(std::string str)
{
    std::stringstream ss(str);

    MenuInfo info;

    info.modifierMask = 0;

    char last;
    for (;;) {
        char ch = ss.get();
        if (ss.eof())
            break;

        if (ch == '-' && last != '-') {
            switch (last) {
                case 'C': info.modifierMask |= NSControlKeyMask; break;
                case 'T': info.modifierMask |= NSCommandKeyMask; break;
                case 'M': info.modifierMask |= NSAlternateKeyMask; break;
                case 'S': info.modifierMask |= NSShiftKeyMask; break;
                default: throw "Bad modifier";
            }
        }
        last = ch;
    }

    if (str.size() == 0)
        info.keyEquivalent = str;
    else
        info.keyEquivalent = str.substr(str.size() - 1);
    return info;
}

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

NSString *menuPath(NSMenuItem *item) {
    NSString *name = [item title];
    item = [item parentItem];
    while (item) {
        name = [@"." stringByAppendingString:name];
        name = [[item title] stringByAppendingString:name];
        item = [item parentItem];
    }
    return name;
}

@implementation VimView (Menus)

- (void) initMenu
{
    mFontMenu = makeFontMenu();
}

- (void) handleVimMenuItem:(id)sender
{
    NSMenuItem *item = (NSMenuItem *)sender;
    NSString *name = menuPath(item);

    std::stringstream cmd;
    cmd << "emenu ";
    cmd << [name UTF8String];
    mVim->vim_command(cmd.str());
}

- (void) customizeMenu:(const msgpack::object &)update_o
{
    std::vector<msgpack::object> args = update_o.convert();

    if (args.size() != 2) {
        throw "MacMenu expects 2 arguments (name, keyEquivalent)";
    }

    std::string path = args[0].convert();
    std::string keyEquivalentStr = args[1].convert();

    MenuInfo menuInfo = parseKeyEquivalent(keyEquivalentStr);
    infoMap[path] = menuInfo;
    [self updateMenu];
}

- (void) updateMenu
{
    mVim->vim_command_output("silent menu").then([self](std::string string) {
        [self createMenuFromVimString:string];
    });
}

- (void) showAbout
{
    mVim->vim_command("intro");
}

- (void) executeMenuItem:(NSMenuItem *)item
{
    id target = [item target];
    SEL action = [item action];

    [target performSelector:action withObject:item];
}

- (void) increaseFontSize
{
    [self executeMenuItem:[mFontMenu itemWithTitle:@"Larger"]];
}

- (void) decreaseFontSize
{
    [self executeMenuItem:[mFontMenu itemWithTitle:@"Smaller"]];
}

- (void) showFontSelector
{
    [self executeMenuItem:[mFontMenu itemWithTitle:@"Show Fonts"]];
}

- (NSArray *) showFileOpenDialog 
{
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setPrompt:@"Open"];
    [openDlg setAllowsMultipleSelection:YES];

    if ([openDlg runModal] == NSFileHandlingPanelOKButton) 
        return [openDlg URLs];

    return nil;
}

- (NSURL *) showFileSaveDialog
{
    NSSavePanel *saveDlg = [NSSavePanel savePanel];
    [saveDlg setPrompt:@"Save"];

    if ([saveDlg runModal] == NSFileHandlingPanelOKButton) 
        return [saveDlg URL];

    return nil;
}

- (void) createMenuFromVimString:(const std::string &)string {

    static int g_counter = 0;
    int inst = g_counter++;

    [mPopupMenu release];
    mPopupMenu = nil;

    [mMenuBar release];
    mMenuBar = [[NSMenu alloc] initWithTitle: @""];

    // Make app menu
    NSMenu *app = [[NSMenu alloc] initWithTitle:@"Neovim"];
    [app addItemWithTitle:@"About Neovim" action:@selector(showAbout) keyEquivalent:@""];
    [app addItem:[NSMenuItem separatorItem]];
    [app addItemWithTitle:@"Hide Neovim" action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem* item = [app addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    item.keyEquivalentModifierMask = NSCommandKeyMask|NSAlternateKeyMask;
    [app addItem:[NSMenuItem separatorItem]];
    [app addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenuItem *appItem = [mMenuBar addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [appItem setSubmenu:app];

    std::map<int, NSMenuItem *> treeMap;

    std::istringstream stream(string);
    std::string line;
    while(std::getline(stream, line)) {

        if (line.empty())
            continue;

        if (line[0] == '-')
            continue;

        std::stringstream ss(line);

        int indent = 0;
        while(ss.get() == 32)
            indent += 1;
        ss.unget();

        std::string priority_or_mode;
        ss >> priority_or_mode >> std::ws;

        char key = priority_or_mode[0];
        if ('0' <= key && key <= '9') {
            std::stringstream priority_ss(priority_or_mode);
            int priority;
            priority_ss >> priority;

            std::string caption;
            std::getline(ss, caption);

            size_t tab_pos = caption.find("^I");
            if (tab_pos != std::string::npos) {
                caption = caption.substr(0, tab_pos);
            }

            NSString *nsCaption = [NSString stringWithUTF8String:caption.c_str()];
            nsCaption = [nsCaption stringByReplacingOccurrencesOfString:@"&" withString:@""];

            if (indent == 0) {
                NSMenu *menu = [[NSMenu alloc] initWithTitle:nsCaption];
                NSMenuItem *heading = [[NSMenuItem alloc] initWithTitle:nsCaption action:nil keyEquivalent:@""];

                if (mPopupMenu) {
                    [mMenuBar addItem:heading];
                }
                else {
                    mPopupMenu = heading;
                }

                [heading setSubmenu:menu];

                treeMap[2] = heading;
            }
            else {
                NSMenuItem *parentItem = treeMap[indent];
                if (!parentItem) {
                    std::cerr << "Menu is weird\n";
                    std::cerr << "no parent for indent level " << indent << "\n";

                    for (auto x: treeMap) {
                    std::cerr << x.first << " :: " << x.second << "\n";
                    }
                    continue;
                }

                NSMenu *parent = [parentItem submenu];
                if (!parent) {
                    parent = [[NSMenu alloc] initWithTitle:nsCaption];
                    [parentItem setSubmenu:parent];
                }

                NSMenuItem *item;

                if (caption[0] == '-') {
                    item = [NSMenuItem separatorItem];
                    [parent addItem:item];
                }
                else {
                    item = [parent addItemWithTitle:nsCaption
                                             action:@selector(handleVimMenuItem:)
                                      keyEquivalent:@""];
                }

                treeMap[indent + 2] = item;

                NSString *nsPath = menuPath(item);
                std::string path = [nsPath UTF8String];
                auto it = infoMap.find(path);
                if (it != infoMap.end()) {
                    const MenuInfo &info = it->second;
                    NSString *keyEquivalent =
                        [NSString stringWithUTF8String:info.keyEquivalent.c_str()];
                    [item setKeyEquivalent:keyEquivalent];
                    [item setKeyEquivalentModifierMask:info.modifierMask];
                }
            }
        }
    }

    if ([[self window] isKeyWindow])
        [self showMenu];
}

-(void)showMenu
{
    [NSApp setMainMenu:mMenuBar];
}

@end
