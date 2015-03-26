# OS X GUI for NeoVim

![](https://raw.githubusercontent.com/rogual/neovim-osx-gui/screenshots/1.png)


## License

This source code is distributed under the terms of the GNU General
Public License, version 3:

http://www.gnu.org/licenses/gpl-3.0.html

## Features

### What's Done

Text editing, mouse support, tabs, clipboard, basic Mac menus, font selection,
font size adjustments

### Stil to do

Multi-window support, non-ugly cursor, services integration, dead-keys support,
drag-and-drop.

Pull requests are welcome, and greatly appreciated!


## Compiling

### Prerequisites

#### SCons
    $ brew install scons

#### MsgPack-C
https://github.com/msgpack/msgpack-c

Homebrew's version is too old and won't work, so you'll need to compile your
own. It's an easy compile though.

#### A NeoVim binary
https://github.com/neovim/neovim

### To compile:

    $ make

This will look for a NeoVim executable on your PATH. To specify
an executable to use, just set the NVIM environment variable, e.g.:

    $ NVIM=/path/to/nvim make

When the .app bundle is created, Vim's runtime files will be copied into it.
By default, the build script asks Vim where its runtime files are, and Vim
will probably say they're somewhere under `/usr`.

If you're compiling your own Neovim, and you don't want to install the runtime
files system-wide, the build script can copy the runtime files directly from
your neovim checkout. Just set `VIM` when compiling, e.g.:

    $ VIM=/path/to/your/neovim/checkout make
