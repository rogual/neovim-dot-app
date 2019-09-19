

@interface VimView (Redraw)

- (void)redraw:(const msgpack::object &)update_o;
- (void) onUnmarkText:(int)len;

@end
