#pragma once

#include <msgpack.hpp>

template<int type_id>
struct VimObject
{
    unsigned char id;

    VimObject() {}
    VimObject(unsigned char id): id(id) {}

    void msgpack_unpack(const msgpack::object &o)
    {
        assert(o.via.ext.type() == type_id);
        id = o.via.ext.data()[0];
    }

    template <typename Stream>
    void msgpack_pack(msgpack::packer<Stream> &o) const
    {
        o.pack_ext(1, type_id);
        o.pack_ext_body((const char *)&id, 1);
    }
};

typedef VimObject<0> Buffer;
typedef VimObject<1> Tabpage;
typedef VimObject<2> Window;

inline std::ostream &operator<<(std::ostream &os, Buffer v)
{
    return os << "Buffer #" << (int)v.id;
}

inline std::ostream &operator<<(std::ostream &os, Tabpage v)
{
    return os << "Tabpage #" << (int)v.id;
}

inline std::ostream &operator<<(std::ostream &os, Window v)
{
    return os << "Window #" << (int)v.id;
}
