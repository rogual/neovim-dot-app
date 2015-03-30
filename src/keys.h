#include <iostream>

@class NSEvent;

void addModifiedName(std::ostream &os, NSEvent *event, const char *name);
void translateKeyEvent(std::ostream &os, unsigned short keyCode, unsigned flags);
void translateKeyEvent(std::ostream &os, NSEvent *event);
