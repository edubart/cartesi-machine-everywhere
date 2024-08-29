FROM alpine:3.20

RUN apk update && \
    apk add meson git gcc g++ musl-dev pkgconfig glib-dev glib-static cmake patch make boost-dev xxd

# Install lua
RUN <<EOF
set -e
wget -O /usr/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /usr/include/lualib.h
echo '#include "minilua.h"' > /usr/include/lauxlib.h
echo '#include "minilua.h"' > /usr/include/lua.h
EOF

# Install libslirp
RUN <<EOF
set -e
git clone --branch v4.7.0 --depth 1 https://gitlab.freedesktop.org/slirp/libslirp.git
cd libslirp
meson build -Ddefault_library=static
ninja -C build install
cd ..
rm -rf libslirp
EOF

# Download cartesi machine
RUN <<EOF
set -e
git clone --branch feature/portable-cli --depth 1 https://github.com/cartesi/machine-emulator.git
cd machine-emulator
wget https://github.com/cartesi/machine-emulator/releases/download/v0.18.1/add-generated-files.diff
patch -Np0 < add-generated-files.diff

# fix/alpine-compile
wget https://github.com/cartesi/machine-emulator/pull/267.patch
patch -Np1 < 267.patch

# feature/optim-fetch
wget https://github.com/cartesi/machine-emulator/pull/226.patch
patch -Np1 < 226.patch
EOF

# Build cartesi machine
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) \
    MYLDFLAGS="-static-libstdc++ -static-libgcc" \
    MYEXELDFLAGS="-static" \
    LIBCARTESI_COMMON_LIBS="-l:libslirp.a -l:libglib-2.0.a" \
    JSONRPC_REMOTE_CARTESI_MACHINE_LIBS="-l:libslirp.a -l:libglib-2.0.a -l:libintl.a" \
    LUA_INC= LUA_LIB=
make install PREFIX=/usr DESTDIR=pkg
EOF

# Build cartesi machine cli
COPY cli machine-emulator/src/cli
RUN <<EOF
set -e
cd machine-emulator
make -C src/cli -j$(nproc) \
    MYLDFLAGS="-static-libstdc++ -static-libgcc -static" \
    SLIRP_LIB="-l:libslirp.a -l:libglib-2.0.a -l:libintl.a"
rm -r pkg/usr/share/lua pkg/usr/share/cartesi-machine/gdb \
    pkg/usr/bin/cartesi-machine-stored-hash \
    pkg/usr/bin/merkle-tree-hash
cp src/cli/cartesi-machine pkg/usr/bin/
strip pkg/usr/bin/cartesi-machine
EOF
