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

nvim = env['ENV'].get('NVIM')
if not nvim:
    print('Please set NVIM to the path to a NeoVim executable.')
    sys.exit(-1)

env.VariantDir('build', 'src', duplicate=False)

hashfile = env.Command(
    'build/redraw-hash.gen.h',
    'src/redraw.gperf',
    'gperf -cCD -L C++ -Z RedrawHash -t $SOURCE > $TARGET'
)

sources = env.Glob('build/*.cc') + env.Glob('build/*.mm')


env.Program('build/NeoVim.app/Contents/MacOS/NeoVim', sources)
env.Install('build/NeoVim.app/Contents', 'res/Info.plist')
env.Install('build/NeoVim.app/Contents/Resources', nvim)

env.Command(
    'build/NeoVim.app/Contents/Resources/NeoVim.icns',
    'res/NeoVim.png',
    'sh makeicons.sh $TARGET $SOURCE'
)
