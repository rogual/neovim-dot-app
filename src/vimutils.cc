#include <sstream>

#include "vimutils.h"
#include "vim.h"

/* Set the given vim option, run cb(), then set it back to what it was before */
void with_option(Vim *vim, std::string option, VoidFn cb)
{
    // Get old option value
    std::stringstream ss;
    ss << "set " << option << "?";
    vim->vim_command_output(ss.str()).then([vim, cb, option](std::string old) {

        // When we ask vim for command output and we're in insert
        // mode, it helpfully appends the string "--INSERT--". THANKS VIM
        old.erase(old.find('-'), old.size());

        // It also throws in some newlines and shit for free
        std::stringstream i_love_vim;
        i_love_vim << old;
        old.clear();
        i_love_vim >> old;

        std::stringstream set_cmd;
        set_cmd << "set " << option;
        vim->vim_command(set_cmd.str()).then([vim, cb, old]() {

            // Do the actual thing
            cb();

            // Restore old option state
            std::stringstream ss;
            ss << "set " << old;
            vim->vim_command(ss.str());
        });
    });
}
