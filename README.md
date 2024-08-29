# Cartesi Machine Everywhere

This project goal is to make it easy to distribute the Cartesi Machine
across different platforms and architectures,
by providing ready to use prebuilt binaries for various platforms and architectures.

Just grab and run no matter what host you are running on!

The archives are designed to be dependency free, it will not need anything installed in your host system. Notably you don't need Lua to run anything, since the `cartesi-machine` becomes an executable binary.

The goal is to make it easy for anyone to hack applications using the cartesi machine,
no matter if you want to use just the cli, its C API, script with Lua, or build other statically linked binaries on top.

## Archive contents

Each archive provides the following binaries:

- `cartesi-machine` cli, so you can emulate machines in your terminal.
- `jsonrpc-cartesi-machine`, so you can emulate remote machines with forking support.
- `libcartesi`/`libcartesi_jsonrpc` headers so you can use the cartesi machine C API directly.
- `libcartesi`/`libcartesi_jsonrpc` shared libraries, so you can link applications using the C API dynamically.
- `libcartesi`/`libcartesi_jsonrpc` static libraries, so you can link applications using the C API statically.
- `cartesi` Lua 5.4 library, so you can prototype applications using your system's Lua interpreter.
- `linux.bin` standard cartesi machine kernel.
- `rootfs.ext2` standard Ubuntu riscv64 OS containing cartesi machine tools, so you can test quickly.

Although all these components could be split across archives,
they are all provided in a single archive for convenience.

## Platforms

The following platforms are supported:

- Linux (amd64/arm64/riscv64) (GLIBC 2.35+ / MUSL)
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

## Quick example

Here is a quick example of running `cartesi-machine` on any Linux amd64.
```
wget https://github.com/edubart/cartesi-machine-everywhere/releases/latest/download/cartesi-machine-linux-musl-amd64.tar.xz
tar xJf cartesi-machine-linux-musl-amd64.tar.xz
export CARTESI_IMAGES_PATH=$(pwd)/cartesi-machine-linux-musl-amd64/share/cartesi-machine/images
./cartesi-machine-linux-musl-amd64/bin/cartesi-machine

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

## Using the cartesi-machine cli

1. Go to latest release page and download the archive for your host platform.
2. Extract the archive.
3. Run `bin/cartesi-machine` and you are done!

## Using the libcartesi C API

1. Go to the latest release page and download the archive for your host platform.
2. Extract the archive.
3. Compile your application using `lib` library directory and `include` directory while linking to `libcartesi` and you are done!

**Remarks:** For linking dynamically add `-lcartesi` linker flag, for linking statically add the full path to `lib/libcartesi.a` as a linker flag.

## Using the cartesi Lua library

1. Go to the latest release page and download the archive for your host platform.
2. Extract the archive.
3. Update `LUA_CPATH_5_4` environment variables to search for libraries in `lib/lua/5.4`.
4. Install Lua 5.4 in your system and you are done!

## Patches

At the moment this project does not use standard cartesi machine sources,
it is based on cartesi machine v0.18.1 plus various patches to make this project possible:

- Makefile adjustments so this project can exist.
- Add VirtIO support for windows
- Instruction fetch optimization
- Fix compile errors for some platforms

The idea is to upstream these patches in the future.
