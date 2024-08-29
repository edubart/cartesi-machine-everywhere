FROM ubuntu:22.04

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git wget meson glib2.0-dev python3 glib2.0-dev xxd

# Install gcc
RUN <<EOF
set -e
apt-get install -y gcc-12 g++-12
update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-12 12
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12
update-alternatives --install /usr/bin/cpp cpp /usr/bin/cpp-12 12
update-alternatives --install /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-12 12
EOF

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
git clone --branch v4.8.0 --depth 1 https://gitlab.freedesktop.org/slirp/libslirp.git
cd libslirp
meson build -Ddefault_library=static
ninja -C build install
cd ..
rm -rf libslirp
EOF

# Install arc4random so we can avoid arc4random@GLIBC_2.36
RUN <<EOF
git clone --depth 1 https://github.com/opencoff/portable-lib.git
gcc -c -fPIC -O2 -I./portable-lib/inc -o /usr/lib/arc4random.o portable-lib/src/arc4random.c
rm -rf portable-lib
EOF

# Download cartesi machine
RUN <<EOF
set -e
git clone --branch feature/portable-cli --depth 1 https://github.com/cartesi/machine-emulator.git
cd machine-emulator
make bundle-boost
wget https://github.com/cartesi/machine-emulator/releases/download/v0.18.1/add-generated-files.diff
patch -Np0 < add-generated-files.diff

# feature/optim-fetch
wget https://github.com/cartesi/machine-emulator/pull/226.patch
patch -Np1 < 226.patch
EOF

# Build cartesi machine
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) \
    MYLDFLAGS="-static-libstdc++ -static-libgcc /usr/lib/arc4random.o" \
    SLIRP_LIB="-l:libslirp.a -l:libglib-2.0.a" \
    LUA_INC= LUA_LIB=
make install PREFIX=/usr DESTDIR=pkg
EOF

# Build cartesi machine cli
COPY cli machine-emulator/src/cli
RUN <<EOF
set -e
cd machine-emulator
make -C src/cli -j$(nproc) \
    MYLDFLAGS="-static-libstdc++ -static-libgcc /usr/lib/arc4random.o" \
    SLIRP_LIB="-l:libslirp.a -l:libglib-2.0.a"
rm -r pkg/usr/share/lua pkg/usr/share/cartesi-machine/gdb \
    pkg/usr/bin/cartesi-machine-stored-hash \
    pkg/usr/bin/merkle-tree-hash
cp src/cli/cartesi-machine pkg/usr/bin/
strip pkg/usr/bin/cartesi-machine
EOF
