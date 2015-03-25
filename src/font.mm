#import "font.h"

@implementation VimFontManager: NSFontManager

/*  Override to return only monospaced fonts.
    (This is how you write "collections.filter(c -> all(isMonospaced, c.fonts))"
    when you're paid by the word.) */
- (NSArray *)collectionNames
{
    NSArray *cnames = [super collectionNames];

    NSPredicate *collectionIsFixedWidth =
        [NSPredicate predicateWithBlock:
            ^(NSString *cname, NSDictionary *bindings) {
                NSArray *descs = [self fontDescriptorsInCollection:cname];
                for (NSFontDescriptor *desc in descs) {
                    if (!([desc symbolicTraits] & NSFontMonoSpaceTrait))
                        return NO;
                }
                return YES;
            }
        ];

    return [cnames filteredArrayUsingPredicate:collectionIsFixedWidth];
}

@end
