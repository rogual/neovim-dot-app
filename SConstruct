import os
import sys
import re
import subprocess

from SCons.Script import Environment

env = Environment(ENV=os.environ, CXX='clang++')

# dynamically generate CFLAGS and LDFLAGS
try:
    env.ParseConfig('pkg-config --cflags --libs msgpack')
except OSError:
    print("Unable to execute pkg-config, you may have to set CFLAGS and LDFLAGS by hand.")

env.Append(
    CCFLAGS=['-std=c++11', '-stdlib=libc++', '-g', '-Wno-deprecated-register', '-mmacosx-version-min=10.9'],
    CPPPATH=['build'],
    LIBS=['c++', 'msgpackc'],
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

# Check Neovim version
ver_str = subprocess.check_output([nvim, '--version']).split('\n', 1)[0]
if '-dev' in ver_str:
    print(
        "WARNING: Could not determine exact Neovim version. If your Neovim is "
        "not up to date, there may be incompatibilities."
    )
else:
    ver = re.match(r'NVIM v?(\d+)\.(\d+).(\d+)(?:-(\d+))?', ver_str).groups('0')
    ver = tuple(map(int, ver))
    required = (0, 1, 3, 202)
    if ver < required:
        fmt_ver = \
            lambda ver: ('%s.%s.%s' if len(ver) == 3 else '%s.%s.%s-%s') % ver
        print(
            "\n"
            "Your Neovim is too old. Please update Neovim to the latest HEAD "
            "and recompile it.\n\n"
            "Your version: %s\n"
            "Required: %s\n" % (
                fmt_ver(ver),
                fmt_ver(required)
            )
        )
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

# Neovim no longer reads nvimrc, it now reads sysinit.vim. Keep the old one
# for backcompat.
nvimrc = env.Install(res, 'res/nvimrc')
env.Command(
    res + '/sysinit.vim', nvimrc, 'cd %s && ln -s nvimrc sysinit.vim' % res
)

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

    runtime = env.Dir(res + '/runtime')
    env.Install(runtime, env.Glob(vim + '/runtime/*'))
    env.Install(runtime.Dir('doc'), env.Glob('doc/*'))

env.Command(
    'build/Neovim.app/Contents/Resources/Neovim.icns',
    'res/Neovim.png',
    'sh makeicons.sh $TARGET $SOURCE'
)

#  vim: set et fenc=utf-8 ff=unix ft=python sts=4 sw=4 ts=8 : 
