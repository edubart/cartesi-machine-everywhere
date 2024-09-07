CFLAGS=-O2 -fPIC -DNDEBUG
TARGET_OS?=$(shell uname)
CARTESI_LIBS=../libluacartesi.a ../libcartesi.a
CARTESI_JSONRPC_LIBS=../libluacartesi_jsonrpc.a ../libcartesi_jsonrpc.a
LUA_LIB=-llua
SLIRP_LIB=-lslirp

ifeq ($(TARGET_OS),Darwin)
CC=clang
CXX=clang++
LDFLAGS=-Wl,-export_dynamic
TARGET_LIBS=-lresolv
EXE=cartesi-machine
else ifeq ($(TARGET_OS),Windows)
CC=x86_64-w64-mingw32-gcc
CXX=x86_64-w64-mingw32-g++
LDFLAGS=
TARGET_LIBS=-lws2_32 -liphlpapi -lshlwapi
EXE=cartesi-machine.exe
else
CC=gcc
CXX=g++
LDFLAGS=-Wl,--export-dynamic
TARGET_LIBS=-lm
EXE=cartesi-machine
endif

LIBS=$(CARTESI_LIBS) $(CARTESI_JSONRPC_LIBS) $(LUA_LIB) $(SLIRP_LIB) $(TARGET_LIBS)

all: $(EXE)

$(EXE): cartesi-machine.cpp cartesi-machine.lua.h cartesi-proof.lua.h cartesi-gdbstub.lua.h cartesi-util.lua.h
	$(CXX) $< -o $@ $(CFLAGS) $(MYCFLAGS) $(LIBS) $(MYLIBS) $(LDFLAGS) $(MYLDFLAGS)

cartesi-machine.lua.h: ../cartesi-machine.lua
	rm -f cartesi-machine.lua
	sed '1 s/.*//' $< > cartesi-machine.lua
	xxd -i cartesi-machine.lua | sed 's/___//' > $@
	rm -f cartesi-machine.lua
cartesi-proof.lua.h: ../cartesi/proof.lua
	xxd -i $< | sed 's/___//'  > $@
cartesi-util.lua.h: ../cartesi/util.lua
	xxd -i $< | sed 's/___//'  > $@
cartesi-gdbstub.lua.h: ../cartesi/gdbstub.lua
	xxd -i $< | sed 's/___//'  > $@

clean:
	rm -f $(EXE) *.lua.h *.o
