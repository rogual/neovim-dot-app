#include <sstream>
#include <tuple>
#include <iostream>
#include <msgpack.hpp>
#include <unistd.h>

#include "vim.h"

const char *vim_argv[] = {"nvim", "--embed", 0};

Vim::Vim(const char *vim_path):
    process(vim_path, vim_argv),
    Client(process)
{
}


/* Vim loves sending us spurious messages. Detect them here and
   skip sending them to the main thread. */
Event Vim::wait()
{
    for (;;) {
        Event event = Client::wait();

        /* Redraw events with no instructions */
        if (event.note == "redraw") {
            if (event.note_arg.type != msgpack::type::ARRAY)
                continue;
            if (event.note_arg.via.array.size == 0)
                continue;
        }

        return event;
    }
}

