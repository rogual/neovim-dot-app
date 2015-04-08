#pragma once

#include <string>
#include <functional>

class Vim;

typedef std::function<void()> VoidFn;

void with_option(Vim *vim, std::string option, VoidFn cb);
