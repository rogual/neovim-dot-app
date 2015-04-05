NVIM?=$(shell which nvim)

ifneq "$(NVIM)" ""
VIM?=$(shell $(NVIM) --version | grep 'fall-back' | cut -d '"' -f 2)
endif

all:
	VIM=$(VIM) NVIM=$(NVIM) scons -Q

clean:
	$(RM) -r build

install:
	cp -fpRv "build/Neovim.app" "/Applications/Neovim.app"
