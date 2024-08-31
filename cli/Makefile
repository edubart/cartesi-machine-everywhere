CFLAGS=-O2 -fPIC -DNDEBUG
TARGET_OS?=$(shell uname)
CARTESI_LIBS=../libluacartesi.a ../libluacartesi_jsonrpc.a ../libcartesi.a ../libcartesi_jsonrpc.a
EXE=cartesi-machine

ifeq ($(TARGET_OS),Darwin)
CC=clang
CXX=clang++
LDFLAGS=-Wl,-export_dynamic
TARGET_LIBS=
SLIRP_LIB=-lslirp
else
CC=gcc
CXX=g++
LDFLAGS=-Wl,--export-dynamic
TARGET_LIBS=-lm
SLIRP_LIB=-lslirp
endif

LIBS=$(CARTESI_LIBS) $(SLIRP_LIB) $(TARGET_LIBS)

all: $(EXE)

$(EXE): cartesi-machine.cpp lua.o cartesi-machine.lua.h cartesi-proof.lua.h cartesi-gdbstub.lua.h cartesi-util.lua.h
	$(CXX) $< -o $@ lua.o $(CFLAGS) $(MYCFLAGS) $(LIBS) $(MYLIBS) $(LDFLAGS) $(MYLDFLAGS)

lua.o: lua.c
	$(CC) -c $< -o $@ $(CFLAGS) $(MYCFLAGS)

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
