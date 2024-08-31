# Cartesi Machine Everywhere

This project goal is to make it easy to distribute the Cartesi Machine
across different platforms and architectures,
by providing ready to use prebuilt binaries for various platforms and architectures.

Just grab and run no matter what host you are running on!

The archives are designed to be dependency free, it will not much installed in your host system. Notably you don't need Lua to run anything, since the `cartesi-machine` becomes an executable binary.

The goal is to make it easy for anyone to hack applications using the cartesi machine,
no matter if you want to use just the cli, its C API, script with Lua, or build other statically linked binaries on top.

## Archive contents

Each archive provides the following binaries:

- `cartesi-machine` cli, so you can emulate machines in your terminal.
- `jsonrpc-cartesi-machine`, so you can emulate remote machines with forking support.
- `libcartesi`/`libcartesi_jsonrpc` headers so you can use the cartesi machine C API directly.
- `libcartesi`/`libcartesi_jsonrpc` shared libraries, so you can link applications using the C API dynamically.
- `libcartesi`/`libcartesi_jsonrpc` static libraries, so you can link applications using the C API statically.
- `cartesi`/`cartesi.jsonrpc` Lua 5.4 library, so you can prototype applications using your system's Lua interpreter.
- `linux.bin` kernel to be used by cartesi machine guests.
- `rootfs.ext2` OS image based on Ubuntu riscv64, containing cartesi machine tools, so you can test quickly.

Although all these components could be split across archives,
they are all provided in a single archive for convenience.

## Platforms

The following platforms are supported:

- Linux GLIBC 2.35+ (amd64/arm64/riscv64)
- Linux MUSL (amd64/arm64/riscv64)
- MacOS (amd64/arm64)
- Windows (amd64)
- WebAssembly (so you can use in Web frontends with Emscripten)

### A note on Linux different flavors

Linux has two flavors for distributions based on different libc:

1. Based on GLIBC 2.35+ libc
2. Based on MUSL libc

You most likely you want to use the GLIBC libc (eg. Ubuntu/Debian/ArchLinux/...).
Unless you are using a system based on MUSL libc (eg. Alpine Linux),
or really want a statically linked `cartesi-machine` binary so it can run
even on very outdated Linux distributions.
When downloading the MUSL flavor the cli will work on any Linux,
however the shared libraries will not, unless your system have MUSL libc.

## Using the cartesi-machine cli

1. Go to latest release page and download the archive for your host platform.
2. Extract the archive.
3. Run `bin/cartesi-machine` and you are done!

Quick example of running `cartesi-machine` on any Linux amd64:

```sh
wget https://github.com/edubart/cartesi-machine-everywhere/releases/latest/download/cartesi-machine-linux-musl-amd64.tar.xz
tar xJf cartesi-machine-linux-musl-amd64.tar.xz
cd cartesi-machine-linux-musl-amd64
./bin/cartesi-machine

         .
        / \
      /    \
\---/---\  /----\
 \       X       \
  \----/  \---/---\
       \    / CARTESI
        \ /   MACHINE
         '

Nothing to do.

Halted
Cycles: 42051629
```

## Using the cartesi Lua library

1. Go to the latest release page and download the archive for your host platform.
2. Extract the archive.
3. Update `LUA_CPATH_5_4` environment variables to search for libraries in `lib/lua/5.4`.
4. Install Lua 5.4 in your system and you are done!

Example of Lua cartesi library usage on Linux GLIBC amd64:

```sh
wget https://github.com/edubart/cartesi-machine-everywhere/releases/latest/download/cartesi-machine-linux-glibc-amd64.tar.xz
tar xJf cartesi-machine-linux-glibc-amd64.tar.xz
cd cartesi-machine-linux-glibc-amd64
export LUA_CPATH_5_4="$(pwd)/lib/lua/5.4/?.so;;"
lua5.4 -e 'print("cartesi-machine "..require("cartesi").VERSION)'
cartesi-machine 0.18.1
```

## Using the libcartesi C API

1. Go to the latest release page and download the archive for your host platform.
2. Extract the archive.
3. Compile your application using `lib` library directory and `include` directory while linking to `libcartesi` and you are done!

**Remarks:** For linking dynamically add `-lcartesi` linker flag, for linking statically add the full path to `lib/libcartesi.a` as a linker flag.

Quick example of libcartesi C API usage on any Linux GLIBC amd64:

```sh
wget https://github.com/edubart/cartesi-machine-everywhere/releases/latest/download/cartesi-machine-linux-glibc-amd64.tar.xz
tar xJf cartesi-machine-linux-glibc-amd64.tar.xz
cd cartesi-machine-linux-glibc-amd64
cat <<EOF > main.c
#include <stdio.h>
#include <cartesi-machine/machine-c-api.h>
int main() {
     printf("register x1 is at 0x%x\n", cm_get_x_address(1));
}
EOF
gcc main.c -o main -I./include -L./lib -lcartesi
./main
register x1 is at 0x8
```

## Patches

At the moment this project does not use standard cartesi machine sources,
it is based on cartesi machine v0.18.1 plus various patches to make this project possible:

- Makefile adjustments so this project can exist.
- Add VirtIO support for Windows.
- Instruction fetch optimization.

The idea is to upstream these patches in the future.
