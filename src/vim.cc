#include <sstream>
#include <tuple>
#include <iostream>
#include <msgpack.hpp>
#include <unistd.h>

#include "vim.h"

extern int g_argc;
extern char **g_argv;

const char *vim_argv[] = {"nvim", "--embed", 0};

const char **vim_create_argv()
{
    if (!(isatty (STDIN_FILENO) || isatty (STDOUT_FILENO) || isatty(STDERR_FILENO)))
        return vim_argv;

    if (g_argc == 1)
        return vim_argv;

    const char **argv = new const char *[g_argc+2];
    argv[0] = vim_argv[0];
    argv[1] = vim_argv[1];
    for (int x = 2; x-1 < g_argc; x++)
       argv[x] = g_argv[x-1];

    argv[g_argc+1] = 0;

    return argv;
}

Vim::Vim(const char *vim_path):
    process(vim_path, vim_create_argv()),
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

