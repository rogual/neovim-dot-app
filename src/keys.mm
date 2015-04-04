#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "keys.h"

/* For easy overriding in the tests */
TISInputSourceRef g_input_source = 0;

/* Returns Vim's key-name for applicable keycodes, 0 otherwise */
static const char *keyName(unsigned short keyCode)
{
    /* All the "layout-independent" codes from Carbon's Events.h, except
       for the modifier keys */
    switch (keyCode) {
        case kVK_Return: return "CR";
        case kVK_Delete: return "BS";
        case kVK_ForwardDelete: return "Del";
        case kVK_Escape: return "Esc";

        case kVK_LeftArrow: return "Left";
        case kVK_RightArrow: return "Right";
        case kVK_DownArrow: return "Down";
        case kVK_UpArrow: return "Up";

        /* These keys are named the same in Vim and OS X */
        #define _(x) case kVK_##x: return #x;

            _(Tab) _(Space)
            _(VolumeUp) _(VolumeDown) _(Mute) _(Help)
            _(Home) _(End) _(PageUp) _(PageDown)

            _(F1) _(F2) _(F3) _(F4) _(F5) _(F6) _(F7) _(F8) _(F9) _(F10)
            _(F11) _(F12) _(F13) _(F14) _(F15) _(F16) _(F17) _(F18) _(F19) _(F20)

        #undef _
    }
    return 0;
}

/* Convert between Apple's two modifier bitmasks */
static unsigned cocoaToCarbonModifiers(unsigned mods)
{
    return ((mods & NSShiftKeyMask) ? shiftKey : 0) |
           ((mods & NSCommandKeyMask) ? cmdKey : 0) |
           ((mods & NSControlKeyMask) ? controlKey : 0) |
           ((mods & NSAlternateKeyMask) ? optionKey : 0);
}

/* Return the string that a key will produce when the given modifiers are
   down. Cocoa can't quite manage this, but luckily there are deprecated
   APIs that can */
static NSString *stringFromModifiedKey(unsigned keyCode, unsigned modifiers)
{
    TISInputSourceRef keyboard = g_input_source;

    if (keyboard) {
        CFRetain(keyboard);
    }
    else {
        keyboard = TISCopyCurrentKeyboardInputSource();
    }

    CFDataRef layoutData = (CFDataRef)TISGetInputSourceProperty(
        keyboard,
        kTISPropertyUnicodeKeyLayoutData
    );

    const UCKeyboardLayout *layout =
        (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);

    unsigned deadKeyState;
    unichar chars[5];
    UniCharCount numChars;

    unsigned carbonModifiers = cocoaToCarbonModifiers(modifiers);
    unsigned shiftedModifiers = (carbonModifiers >> 8) & 0xFF;

    UCKeyTranslate(
        layout,
        keyCode,
        kUCKeyActionDisplay,
        shiftedModifiers,
        LMGetKbdType(),
        kUCKeyTranslateNoDeadKeysBit,
        &deadKeyState,
        4,
        &numChars,
        chars
    );

    CFRelease(keyboard);

    chars[numChars] = 0;

    return [NSString stringWithFormat:@"%S", (const unichar *)chars];
}
/* Translate NSEvent modifier flags to Vim's prefix notation and write them
   to the given ostream */
static void addModifiers(std::ostream &os, unsigned mods)
{
    /* Alphabetical order */
    if (mods & NSControlKeyMask) os << "C-";
    if (mods & NSCommandKeyMask) os << "D-";
    if (mods & NSAlternateKeyMask) os << "M-";
    if (mods & NSShiftKeyMask) os << "S-";
}

static void addModifiedName(std::ostream &os, unsigned flags, int clickCount, const char *name)
{
    os << "<";
    addModifiers(os, flags);

    if (2 <= clickCount && clickCount <= 4)
        os << clickCount << "-";

    os << name;
    os <<
        ">";
}

void addModifiedName(std::ostream &os, NSEvent *event, const char *name)
{
    int clickCount = 1;

    int eventType = [event type];

    // get clickCount only for mouse events
    if (eventType == NSLeftMouseDown || 
        eventType == NSLeftMouseUp ||
        eventType == NSRightMouseDown ||
        eventType == NSRightMouseUp) {

       clickCount = [event clickCount];
    }

    addModifiedName(os, [event modifierFlags], clickCount, name);
}

void translateKeyEvent(std::ostream &os, unsigned short keyCode, unsigned flags)
{
    const char *name = keyName(keyCode);

    bool printable = (name == 0);

    /* Modifiers to actually send to Vim as S-/M-/etc. prefixes */
    unsigned sendflags = flags;

    /* For printable keys, shift and alt modify the character so we don't
        send them as modifiers (no "S-" or "M-") */
    if (printable)
        sendflags &= ~(NSShiftKeyMask | NSAlternateKeyMask);

    /* If Ctrl or Cmd is down, Cocoa doesn't give us a usable "characters"
       field. (Ctrl gives ASCII ctrl-codes, Cmd forces lowercase.) It does
       give us "charactersIgnoringModifiers" but we only want to
       ignore Ctrl and Cmd. To simplify things, let's not rely on "characters"
       at all. */
    NSString *chars = stringFromModifiedKey(
        keyCode,
        flags & ~(NSControlKeyMask | NSCommandKeyMask)
    );

    /* If Alt is combined with Cmd or Ctrl, send it as a modifier rather
        than sending the alternate character for that key; nobody wants to
        map <C-∆> */
    if (flags & NSAlternateKeyMask)
    if (flags & (NSCommandKeyMask | NSControlKeyMask)) {
        chars = stringFromModifiedKey(keyCode, flags & NSShiftKeyMask);
        sendflags |= NSAlternateKeyMask;
        flags &= ~NSAlternateKeyMask;
    }

    /* Vim doesn't distinguish between <C-j> and <C-J>, so let's send the
        S- modifier if:

        - The key is shifted
        - We are sending other modifiers but we weren't going to send S-, and
        - the shifted and nonshifted chars for this key differ only
            by case */
    if (flags & NSShiftKeyMask)
    if (sendflags)
    if (!(sendflags & NSShiftKeyMask)) {
        NSString *unshifted = stringFromModifiedKey(
            keyCode,
            flags & NSAlternateKeyMask
        );

        if ([unshifted caseInsensitiveCompare:chars] == NSOrderedSame) {
            sendflags |= NSShiftKeyMask;
            chars = [chars lowercaseString];
        }
    }

    /* The only character (not key) with a name */
    if ([chars isEqualToString:@"<"])
        name = "lt";

    /* Send named or modified keys inside <>, other keys on their own */
    if (name || sendflags) {
        addModifiedName(os, sendflags, 1, name ? name : [chars UTF8String]);
    }
    else {
        os << [chars UTF8String];
    }
}

void translateKeyEvent(std::ostream &os, NSEvent *event)
{
    unsigned short keyCode = [event keyCode];

    /* We only care about these modifiers */
    unsigned flags = [event modifierFlags] & (
        NSShiftKeyMask |
        NSAlternateKeyMask |
        NSControlKeyMask |
        NSCommandKeyMask
    );

    translateKeyEvent(os, keyCode, flags);
}
