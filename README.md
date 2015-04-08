# OS X GUI for Neovim

![](https://raw.githubusercontent.com/rogual/neovim-osx-gui/screenshots/1.png)


## License

This source code is distributed under the terms of the GNU General
Public License, version 3:

http://www.gnu.org/licenses/gpl-3.0.html

## Features

### What's Done

Text editing, mouse support, tabs, clipboard, basic Mac menus, font selection,
font size adjustments

### Still to do

See the [list of issues](https://github.com/rogual/neovim-dot-app/issues).

Pull requests are welcome, and greatly appreciated!


## Compiling

### Prerequisites

#### OS and Compiler

* Neovim.app compiles on OS X 10.9 and 10.10.
* You'll need to install Xcode and its command-line tools.
* Homebrew isn't required but it's an easy way to install the rest of the 
  dependencies.

#### SCons
    $ brew install scons

#### MsgPack-C
    $ brew install msgpack

#### A Neovim binary
    $ brew tap neovim/homebrew-neovim
    $ brew install --HEAD neovim

### To compile:

    $ make

This will look for a Neovim executable on your PATH. To specify
an executable to use, just set the NVIM environment variable, e.g.:

    $ NVIM=/path/to/nvim make

When the .app bundle is created, Vim's runtime files will be copied into it.
By default, the build script asks Vim where its runtime files are, and Vim
will probably say they're somewhere under `/usr`.

If you're compiling your own Neovim, and you don't want to install the runtime
files system-wide, the build script can copy the runtime files directly from
your neovim checkout. Just set `VIM` when compiling, e.g.:

    $ VIM=/path/to/your/neovim/checkout make

If you're setting one of these options, you'll most likely want to set both.

### Problems Compiling?

    error: no member named 'ext' in 'msgpack::object::union_type'

This means your msgpack is out of date. Try:

    brew uninstall msgpack
    brew update
    brew install msgpack

## Running the Tests

    $ build/test

## Q&A

### I'm having Python problems

Neovim uses the first Python it finds on your PATH. If you've launched Neovim
from anywhere other than a terminal, it will only see your system PATH, which
probably doesn't have that fancy new version of Python you've installed on it.

To point Neovim at the Python installation you want to use, put this in
your .nvimrc:

    let g:python_host_prog='/path/to/python'
