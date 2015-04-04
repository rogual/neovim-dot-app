#include <iostream>

@class NSEvent;

void addModifiedName(std::ostream &, NSEvent *, const char *name);
void translateKeyEvent(std::ostream &, unsigned short keyCode, unsigned flags);
void translateKeyEvent(std::ostream &, NSEvent *);
