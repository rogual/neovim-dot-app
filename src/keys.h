#include <iostream>

@class NSEvent;

void addModifiedName(std::ostream &, NSEvent *, const char *);
void translateKeyEvent(std::ostream &, unsigned short, unsigned, BOOL);
void translateKeyEvent(std::ostream &, NSEvent *, BOOL);
