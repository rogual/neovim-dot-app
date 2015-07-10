#pragma once

#include <string>
#include <functional>

class Vim;

typedef std::function<void()> VoidFn;
typedef std::function<void(VoidFn)> AsyncCallback;

void with_option(Vim *vim, std::string option, VoidFn cb);
