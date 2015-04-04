#pragma once

#include <msgpack.hpp>

#include "util.h"
#include "vimtypes.h"
#include "maybe.h"

class Client;

class RPC: NoCopy
{
    friend class Client;

    public:
        typedef std::function<void(msgpack::object, msgpack::object)> callback_t;

        callback_t callback;

        bool is_resolved() const { return resolved; }
        msgpack::object get_value() const { return value; }
        msgpack::object get_error() const { return error; }

        void then(callback_t);

    private:
        typedef msgpack::type::tuple<
            int,
            int,
            msgpack::object,
            msgpack::object
        > response_t;

        RPC(Client &, int id);

        Client &client;
        int id;

        bool resolved;
        msgpack::object value;
        msgpack::object error;
};

template<typename T>
class TypedRPC
{
    public:
        typedef Maybe<T> maybe_t;
        typedef std::function<void(maybe_t)> cautious_callback_t;
        typedef std::function<void(T)> optimistic_callback_t;

        TypedRPC(RPC *rpc): rpc(rpc) {}

        void then(cautious_callback_t callback)
        {
            rpc->then([callback](msgpack::object value, msgpack::object error) {
                T t;
                value >> t;
                callback(maybe_t(t, error));
            });
        }

        void then(optimistic_callback_t callback)
        {
            then([callback](maybe_t maybe) {
                callback(maybe.get());
            });
        }

    private:
        RPC *rpc;
};

class VoidRPC
{
    public:
        typedef std::function<void(msgpack::object)> cautious_callback_t;
        typedef std::function<void()> optimistic_callback_t;

        VoidRPC(RPC *rpc): rpc(rpc) {}

        void then(cautious_callback_t callback)
        {
            rpc->then([callback](msgpack::object value, msgpack::object error) {
                callback(error);
            });
        }

        void then(optimistic_callback_t callback)
        {
            then([callback](msgpack::object error) {
                if (!error.is_nil()) {
                    Maybe<int>(0, error).get();
                }
                callback();
            });
        }

    private:
        RPC *rpc;
};
