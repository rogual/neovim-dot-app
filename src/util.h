#pragma once

struct NoCopy
{
    NoCopy() {}
    NoCopy(const NoCopy &) = delete;
    NoCopy &operator=(const NoCopy &) = delete;
};

