CC := luastatic

LUAJIT_HEADERS := ../LuaJIT-2.1/src
LUAJIT_LIB := ../LuaJIT-2.1/src/libluajit.a

entry := src/vbuild.lua
sources := $(shell find src -wholename "*.lua" -not -wholename $(entry))
modules := $(shell find modules -wholename "*.lua")

.PHONY: all
all: vbuild

vbuild: $(sources) $(modules)
	$(CC) $(entry) $(sources) $(modules) $(LUAJIT_LIB) -I$(LUAJIT_HEADERS)

run: vbuild
	mv -f vbuild ./test/vbuild
	cd test && ./vbuild

.PHONY: clean
clean:
	@if [ -f vbuild ]; then rm vbuild; fi
	@if [ -f ./test/vbuild ]; then rm ./test/vbuild; fi
	@if [ -f vbuild.luastatic.c ]; then rm vbuild.luastatic.c; fi
