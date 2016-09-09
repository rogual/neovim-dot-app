NVIM?=$(shell which nvim)

ifneq "$(NVIM)" ""
VIM?=$(shell $(NVIM) --version | tr -d '\n' | egrep -o '$VIM.*:.*"' | sed 's/.*$VIM.*:[ ]*"\(.*\)"/\1/')
endif

all:
	VIM=$(VIM) NVIM=$(NVIM) scons -Q

clean:
	$(RM) -r build

install:
	cp -fpRv "build/Neovim.app" "/Applications"

dmg: all
	rm -rf build/dist
	mkdir build/dist
	cp -r build/Neovim.app build/dist
	hdiutil create -fs HFS+ -srcfolder build/dist -volname Neovim build/Neovim.dmg

