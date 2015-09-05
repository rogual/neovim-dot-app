#include <sstream>
#include <tuple>
#include <iostream>
#include <msgpack.hpp>
#include <unistd.h>

#include "vim.h"

extern int g_argc;
extern char **g_argv;


const char **vim_create_argv(const std::vector<char *> &args)
{
    std::vector<char *> *argv = new std::vector<char *>();
    argv->push_back(const_cast<char*>("nvim"));
    argv->push_back(const_cast<char*>("--embed"));

    for (auto arg: args)
      argv->push_back(const_cast<char*>(arg));

    argv->push_back(0);

    return (const char **)&(*argv)[0];
}

Vim::Vim(const char *vim_path, const std::vector<char *> &args):
    process(vim_path, vim_create_argv(args)),
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

