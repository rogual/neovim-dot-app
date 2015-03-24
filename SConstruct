import os
import sys

from SCons.Script import Environment

env = Environment(ENV=os.environ)

env.Append(
    CCFLAGS=['-std=c++11', '-g', '-Wno-deprecated-register'],
    CPPPATH=['build'],
    LIBS=['msgpack'],
    FRAMEWORKS=['Cocoa']
)

if 0:
    env.Append(
        CCFLAGS=['-O3', '-DNDEBUG'],
    )

# Path to executable
nvim = env['ENV'].get('NVIM')
if not nvim:
    print('Please set NVIM to the path to a NeoVim executable.')
    sys.exit(-1)

# Path to runtime
vim = env['ENV'].get('VIM')
if not vim:
    print("Please set VIM to NeoVim's $VIM directory.")
    sys.exit(-1)

env.VariantDir('build', 'src', duplicate=False)

hashfile = env.Command(
    'build/redraw-hash.gen.h',
    'src/redraw.gperf',
    'gperf -cCD -L C++ -Z RedrawHash -t $SOURCE > $TARGET'
)

sources = env.Glob('build/*.cc') + env.Glob('build/*.mm')

res = 'build/NeoVim.app/Contents/Resources'
env.Program('build/NeoVim.app/Contents/MacOS/NeoVim', sources)
env.Install('build/NeoVim.app/Contents', 'res/Info.plist')
env.Install(res, nvim)
env.Install(res, 'res/nvimrc')
env.Install(res, vim + '/runtime')

env.Command(
    'build/NeoVim.app/Contents/Resources/NeoVim.icns',
    'res/NeoVim.png',
    'sh makeicons.sh $TARGET $SOURCE'
)
