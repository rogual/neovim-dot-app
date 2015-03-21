OS X GUI for NeoVim


Not production-ready.


License:
    This source code is distributed under the terms of the GNU General
    Public License, version 3:

        http://www.gnu.org/licenses/gpl-3.0.html


Compiling:

    Prerequisites:
        SCons
            $ easy_install scons

        MsgPack-C
            https://github.com/msgpack/msgpack-c

        A NeoVim binary
            https://github.com/neovim/neovim

    To compile:

        $ make

        This will look for a NeoVim executable on your PATH. To specify
        an executable to use, just set the NVIM environment variable, e.g.:

        $ NVIM=/path/to/nvim make
