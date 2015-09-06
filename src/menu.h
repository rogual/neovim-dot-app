
@interface VimView (Menus)
    - (void) initMenu;
    - (void) updateMenu;
    - (void) showMenu;
    - (void) customizeMenu:(const msgpack::object &)update_o;

    - (void) increaseFontSize;
    - (void) decreaseFontSize;
    - (void) showFontSelector;

    - (NSArray *) showFileOpenDialog;
    - (NSURL *) showFileSaveDialog;
@end
