#import "font.h"

@implementation VimFontManager: NSFontManager

/*  Override to return only monospaced fonts.
    There has got to be a better way to do this...*/
- (NSArray *)collectionNames
{
    return [NSArray arrayWithObject:@"Neovim Monospaced"];
}

@end
