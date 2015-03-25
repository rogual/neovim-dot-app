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

#### A NeoVim binary
https://github.com/neovim/neovim

### To compile:

    $ make

This will look for a NeoVim executable on your PATH. To specify
an executable to use, just set the NVIM environment variable, e.g.:

    $ NVIM=/path/to/nvim make

