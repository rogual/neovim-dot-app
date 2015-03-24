NVIM?=$(shell which nvim)
VIM?=$(shell $(NVIM) --version | grep 'fall-back' | cut -d '"' -f 2)

all:
	VIM=$(VIM) NVIM=$(NVIM) scons -Q
