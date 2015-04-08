#pragma once

#include "process.h"
#include "client.h"
#include "vimtypes.h"

class Vim: public Client
{
    public:
        Vim(const char *vim_path);

        Event wait();

        TypedRPC<int> vim_get_version()
        {
            typedef msgpack::type::tuple<std::string> get_vvar_args_t;
            get_vvar_args_t args("version");
            return Client::call("vim_get_vvar", args);
        }

        TypedRPC<Buffer> vim_get_current_buffer()
        {
            typedef msgpack::type::tuple<> args_t;
            args_t args;
            return Client::call("vim_get_current_buffer", args);
        }

        TypedRPC<int> buffer_line_count(Buffer buf)
        {
            typedef msgpack::type::tuple<Buffer> args_t;
            args_t args(buf);
            return Client::call("buffer_line_count", args);
        }

        TypedRPC<std::string> buffer_get_name(Buffer buf)
        {
            typedef msgpack::type::tuple<Buffer> args_t;
            args_t args(buf);
            return Client::call("buffer_get_name", args);
        }

        VoidRPC vim_set_current_buffer(Buffer buf)
        {
            typedef msgpack::type::tuple<Buffer> args_t;
            args_t args(buf);
            return Client::call("vim_set_current_buffer", args);
        }

        VoidRPC vim_command(std::string cmd)
        {
            typedef msgpack::type::tuple<std::string> args_t;
            args_t args(cmd);
            return Client::call("vim_command", args);
        }

        TypedRPC<std::string> vim_command_output(std::string cmd)
        {
            typedef msgpack::type::tuple<std::string> args_t;
            args_t args(cmd);
            return Client::call("vim_command_output", args);
        }

        VoidRPC vim_input(std::string keys)
        {
            typedef msgpack::type::tuple<std::string> args_t;
            args_t args(keys);
            return Client::call("vim_input", args);
        }

        VoidRPC ui_attach(int w, int h, bool rgb)
        {
            typedef msgpack::type::tuple<int, int, bool> args_t;
            args_t args(w, h, rgb);
            return Client::call("ui_attach", args);
        }

        VoidRPC ui_try_resize(int w, int h)
        {
            typedef msgpack::type::tuple<int, int> args_t;
            args_t args(w, h);
            return Client::call("ui_try_resize", args);
        }


    private:
        Process process;
};
