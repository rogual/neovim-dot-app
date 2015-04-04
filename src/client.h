#pragma once

#include <string>
#include <list>
#include <map>
#include <sstream>
#include <deque>

#include <msgpack.hpp>

#include "rpc.h"
#include "util.h"

class Process;

struct Event
{
    RPC *rpc;
    std::string note;
    msgpack::object note_arg;
};

class Client: NoCopy
{
    friend class RPC;
    friend class Listener;

    public:
        typedef RPC::response_t response_t;

        Client(Process &);
        ~Client();

        template<typename Args>
        RPC *call(const std::string &name, Args args);
        Event wait();

    private:
        typedef std::map<int, RPC *> rpc_map_t;

        Process &process;
        msgpack::unpacker unpacker;
        msgpack::unpacked unpacked;
        rpc_map_t rpc_map;
        int next_id;
        pthread_mutex_t mutex;

        void send(const std::string &message);
};

template<typename Args>
RPC *Client::call(const std::string &name, Args args)
{
    typedef msgpack::type::tuple<int, int, std::string, Args> call_t;

    int msgid = next_id++;

    call_t request(
        0, // 0=request, 1=response
        msgid,
        name,
        args
    );

    std::stringstream buffer;
    msgpack::pack(buffer, request);
    std::string msg = buffer.str();
    send(msg);

    RPC *rpc = new RPC(*this, msgid);
    return rpc;
}
