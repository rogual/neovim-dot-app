#include <string>

const int META_NONE  = 0x00000;
const int META_EITHER = 0x80100;
const int META_LEFT  = 0x80120;
const int META_RIGHT = 0x80140;
const int META_BOTH = 0x80160;

@interface VimView (Input)<NSTextInputClient>

- (BOOL)hasOptAsMetaForModifier:(int)modifiers;

- (void)vimInput:(const std::string &)input;

@end
