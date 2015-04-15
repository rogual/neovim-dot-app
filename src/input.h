#include <string>

@interface VimView (Input) <NSTextInputClient>

- (void)vimInput:(const std::string &)input;

@end
