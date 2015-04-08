import os
import sys

from SCons.Script import Environment

env = Environment(ENV=os.environ, CXX='clang++')

env.Append(
    CCFLAGS=['-std=c++11', '-stdlib=libc++', '-g', '-Wno-deprecated-register'],
    CPPPATH=['build'],
    LIBS=['c++', 'msgpack'],
    FRAMEWORKS=['Cocoa', 'Carbon']
)

if 0:
    env.Append(
        CCFLAGS=['-O3', '-DNDEBUG'],
    )

# Path to executable
nvim = env['ENV'].get('NVIM')
if not nvim:
    print('Please set NVIM to the path to a Neovim executable.')
    sys.exit(-1)

# Path to runtime
vim = env['ENV'].get('VIM')
if not vim:
    print("Please set VIM to Neovim's $VIM directory.")
    sys.exit(-1)

env.VariantDir('build', 'src', duplicate=False)

hashfile = env.Command(
    'build/redraw-hash.gen.h',
    'src/redraw.gperf',
    'gperf -cCD -L C++ -Z RedrawHash -t $SOURCE > $TARGET'
)

sources = env.Glob('build/*.cc') + env.Glob('build/*.mm')

res = 'build/Neovim.app/Contents/Resources'
env.Program('build/Neovim.app/Contents/MacOS/Neovim', sources)
env.Install('build/Neovim.app/Contents', 'res/Info.plist')
env.Install(res, nvim)
env.Install(res, 'res/nvimrc')

# Tests
env.Program('build/test', env.Glob('build/tests/*.mm') + ['build/keys.mm'])

if not os.path.isdir(vim + '/runtime'):
    print(
        "Warning: Not installing runtime files: can't find them at %s" %
        vim
    )
    print(
        "Help will not be available. Re-run with VIM=/path/to/neovim/repo "
        "to fix this."
    )
else:
    env.Install(res, vim + '/runtime')

env.Command(
    'build/Neovim.app/Contents/Resources/Neovim.icns',
    'res/Neovim.png',
    'sh makeicons.sh $TARGET $SOURCE'
)
