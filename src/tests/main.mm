#include <sstream>
#include <cstring>

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "../keys.h"

bool pass = true;

extern TISInputSourceRef g_input_source;

static void test(unsigned short keyCode, unsigned flags, std::string expected)
{
    std::stringstream ss;
    translateKeyEvent(ss, keyCode, flags, NO);
    std::string got = ss.str();
    if (got != expected) {
        pass = false;
        std::cerr << "** FAIL **\n";
        std::cerr << "Expected: " << expected << "\n";
        std::cerr << "Got: " << got << "\n";
    }
}

static void test(unsigned short keyCode, int ctrl, int cmd, int alt, int shift, std::string expected)
{
    unsigned flags = ( ctrl ? NSControlKeyMask   : 0) |
                     (  cmd ? NSCommandKeyMask   : 0) |
                     (  alt ? NSAlternateKeyMask : 0) |
                     (shift ? NSShiftKeyMask     : 0);

    test(keyCode, flags, expected);
}

static TISInputSourceRef getKeyboardLayout(CFStringRef id)
{
    const int sz = 1;
    const void *keys[sz] = {kTISPropertyInputSourceID};
    const void *vals[sz] = {id};

    CFDictionaryRef query = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        vals,
        sz,
        0,
        0
    );

    CFArrayRef sources = TISCreateInputSourceList(query, true);

    assert (CFArrayGetCount(sources) == 1);

    const void *v = CFArrayGetValueAtIndex(sources, 0);
    TISInputSourceRef r = (TISInputSourceRef)v;
    return r;
}

int main()
{
    /* For reproducible test runs, make sure we use a specific
       keyboard layout */
    g_input_source = getKeyboardLayout(CFSTR("com.apple.keylayout.British"));

    // Special Keys  C  T  M  S  Expected
    test(kVK_Return, 0, 0, 0, 0, "<CR>");
    test(kVK_Return, 0, 0, 0, 1, "<S-CR>");
    test(kVK_Return, 0, 0, 1, 0, "<M-CR>");
    test(kVK_Return, 0, 0, 1, 1, "<M-S-CR>");
    test(kVK_Return, 0, 1, 0, 0, "<D-CR>");
    test(kVK_Return, 0, 1, 0, 1, "<D-S-CR>");
    test(kVK_Return, 0, 1, 1, 0, "<D-M-CR>");
    test(kVK_Return, 0, 1, 1, 1, "<D-M-S-CR>");
    test(kVK_Return, 1, 0, 0, 0, "<C-CR>");
    test(kVK_Return, 1, 0, 0, 1, "<C-S-CR>");
    test(kVK_Return, 1, 0, 1, 0, "<C-M-CR>");
    test(kVK_Return, 1, 0, 1, 1, "<C-M-S-CR>");
    test(kVK_Return, 1, 1, 0, 0, "<C-D-CR>");
    test(kVK_Return, 1, 1, 0, 1, "<C-D-S-CR>");
    test(kVK_Return, 1, 1, 1, 0, "<C-D-M-CR>");
    test(kVK_Return, 1, 1, 1, 1, "<C-D-M-S-CR>");

    // Letters       C  T  M  S  Expected
    test(kVK_ANSI_J, 0, 0, 0, 0, "j");
    test(kVK_ANSI_J, 0, 0, 0, 1, "J");
    test(kVK_ANSI_J, 0, 0, 1, 0, "∆");
    test(kVK_ANSI_J, 0, 0, 1, 1, "Ô");
    test(kVK_ANSI_J, 0, 1, 0, 0, "<D-j>");
    test(kVK_ANSI_J, 0, 1, 0, 1, "<D-S-j>");
    test(kVK_ANSI_J, 0, 1, 1, 0, "<D-M-j>");
    test(kVK_ANSI_J, 0, 1, 1, 1, "<D-M-S-j>");
    test(kVK_ANSI_J, 1, 0, 0, 0, "<C-j>");
    test(kVK_ANSI_J, 1, 0, 0, 1, "<C-S-j>");
    test(kVK_ANSI_J, 1, 0, 1, 0, "<C-M-j>");
    test(kVK_ANSI_J, 1, 0, 1, 1, "<C-M-S-j>");
    test(kVK_ANSI_J, 1, 1, 0, 0, "<C-D-j>");
    test(kVK_ANSI_J, 1, 1, 0, 1, "<C-D-S-j>");
    test(kVK_ANSI_J, 1, 1, 1, 0, "<C-D-M-j>");
    test(kVK_ANSI_J, 1, 1, 1, 1, "<C-D-M-S-j>");

    // Numbers       C  T  M  S  Expected
    test(kVK_ANSI_6, 0, 0, 0, 0, "6");
    test(kVK_ANSI_6, 0, 0, 0, 1, "^");
    test(kVK_ANSI_6, 0, 0, 1, 0, "§");
    test(kVK_ANSI_6, 0, 0, 1, 1, "ﬂ");
    test(kVK_ANSI_6, 0, 1, 0, 0, "<D-6>");
    test(kVK_ANSI_6, 0, 1, 0, 1, "<D-^>");
    test(kVK_ANSI_6, 0, 1, 1, 0, "<D-M-6>");
    test(kVK_ANSI_6, 0, 1, 1, 1, "<D-M-^>");
    test(kVK_ANSI_6, 1, 0, 0, 0, "<C-6>");
    test(kVK_ANSI_6, 1, 0, 0, 1, "<C-^>");
    test(kVK_ANSI_6, 1, 0, 1, 0, "<C-M-6>");
    test(kVK_ANSI_6, 1, 0, 1, 1, "<C-M-^>");
    test(kVK_ANSI_6, 1, 1, 0, 0, "<C-D-6>");
    test(kVK_ANSI_6, 1, 1, 0, 1, "<C-D-^>");
    test(kVK_ANSI_6, 1, 1, 1, 0, "<C-D-M-6>");
    test(kVK_ANSI_6, 1, 1, 1, 1, "<C-D-M-^>");

    // Symbols           C  T  M  S  Expected
    test(kVK_ANSI_Comma, 0, 0, 0, 0, ",");
    test(kVK_ANSI_Comma, 0, 0, 0, 1, "<lt>");
    test(kVK_ANSI_Comma, 0, 0, 1, 0, "≤");
    test(kVK_ANSI_Comma, 0, 0, 1, 1, "¯");
    test(kVK_ANSI_Comma, 0, 1, 0, 0, "<D-,>");
    test(kVK_ANSI_Comma, 0, 1, 0, 1, "<D-lt>");
    test(kVK_ANSI_Comma, 0, 1, 1, 0, "<D-M-,>");
    test(kVK_ANSI_Comma, 0, 1, 1, 1, "<D-M-lt>");
    test(kVK_ANSI_Comma, 1, 0, 0, 0, "<C-,>");
    test(kVK_ANSI_Comma, 1, 0, 0, 1, "<C-lt>");
    test(kVK_ANSI_Comma, 1, 0, 1, 0, "<C-M-,>");
    test(kVK_ANSI_Comma, 1, 0, 1, 1, "<C-M-lt>");
    test(kVK_ANSI_Comma, 1, 1, 0, 0, "<C-D-,>");
    test(kVK_ANSI_Comma, 1, 1, 0, 1, "<C-D-lt>");
    test(kVK_ANSI_Comma, 1, 1, 1, 0, "<C-D-M-,>");
    test(kVK_ANSI_Comma, 1, 1, 1, 1, "<C-D-M-lt>");

    if (!pass) {
        std::cerr << "Tests are failing.\n";
        exit(-1);
    }
}
