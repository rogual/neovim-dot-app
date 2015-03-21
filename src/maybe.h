#pragma once

#include <iostream>
#include <msgpack.hpp>

template<class T>
class Maybe
{
    public:
        Maybe(T value, msgpack::object error):
            value(value), error(error) {}

        T get() const
        {
            if (error.is_nil())
                return value;
            std::cerr << error << "\n";
            exit(-1);
        }

        msgpack::object get_error() const
        {
            return error;
        }

    private:
        T value;
        msgpack::object error;
};
