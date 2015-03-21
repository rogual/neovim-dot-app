NVIM?=$(shell which nvim)

all:
	NVIM=$(NVIM) scons -Q
