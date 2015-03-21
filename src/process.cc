#include <unistd.h>
#include "process.h"

extern char **environ;

Process::Process(const char *path, const char *argv[])
{
    pipe(pipe_stdin);
    pipe(pipe_stdout);
    pipe(pipe_stderr);

    pid = fork();

    if (!pid) {

        close(pipe_stdin[1]);
        close(pipe_stdout[0]);
        close(pipe_stderr[0]);

        dup2(pipe_stdin[0], STDIN_FILENO);
        dup2(pipe_stdout[1], STDOUT_FILENO);
        dup2(pipe_stderr[1], STDERR_FILENO);

        const char *const argv[] = {"nvim", "--embed", 0};
        execve(
            path,
            const_cast<char **>(argv),
            environ
        );
    }

    close(pipe_stdin[0]);
    close(pipe_stdout[1]);
    close(pipe_stderr[1]);
}
