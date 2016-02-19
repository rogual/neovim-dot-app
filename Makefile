NVIM?=$(shell which nvim)

ifneq "$(NVIM)" ""
	# TODO the last `grep -v` might not be needed if you could get only the
	# matching group from sed
VIM?=$(shell $(NVIM) --version | grep '$VIM' | sed 's/.*$VIM:[ ]*"\(.*\)"/\1/' | grep -v '$VIM')
endif

all:
	VIM=$(VIM) NVIM=$(NVIM) scons -Q

clean:
	$(RM) -r build

install:
	cp -fpRv "build/Neovim.app" "/Applications"
