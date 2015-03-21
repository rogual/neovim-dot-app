#pragma once

#include <unistd.h>

class Process
{
    public:
        Process(const char *path, const char *argv[]);

        int get_stdin() const { return pipe_stdin[1]; }
        int get_stdout() const { return pipe_stdout[0]; }
        int get_stderr() const { return pipe_stderr[0]; }

    private:
        pid_t pid;
        int pipe_stdin[2];
        int pipe_stdout[2];
        int pipe_stderr[2];
};
