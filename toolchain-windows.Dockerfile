FROM archlinux:base-devel

# Install build tools
RUN pacman -Syyu --noconfirm && \
    pacman -S --noconfirm git wget mingw-w64-toolchain vim

# Install lua
RUN <<EOF
set -e
wget -O /usr/x86_64-w64-mingw32/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /usr/x86_64-w64-mingw32/include/lualib.h
echo '#include "minilua.h"' > /usr/x86_64-w64-mingw32/include/lauxlib.h
echo '#include "minilua.h"' > /usr/x86_64-w64-mingw32/include/lua.h
EOF

# Download cartesi machine
RUN <<EOF
set -e
git clone --branch feature/portable-cli --depth 1 https://github.com/cartesi/machine-emulator.git
cd machine-emulator
make bundle-boost
wget https://github.com/cartesi/machine-emulator/releases/download/v0.18.1/add-generated-files.diff
patch -Np0 < add-generated-files.diff

# feature/windows-virtio-9p (includes feature/optim-fetch)
wget https://github.com/cartesi/machine-emulator/pull/242.patch
patch -Np1 < 242.patch
EOF

# Build cartesi machine
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) \
    libcartesi.dll libcartesi.a libluacartesi.a \
    TARGET_OS=Windows \
    SO_EXT=dll \
    CC=x86_64-w64-mingw32-gcc \
    CXX=x86_64-w64-mingw32-g++ \
    AR="x86_64-w64-mingw32-ar rcs" \
    MYLDFLAGS="-static-libstdc++ -static-libgcc -lws2_32" \
    LUA_INC= \
    slirp=no
make install-headers DESTDIR=pkg
mkdir -p pkg/usr/lib/lua/5.4
cp src/libcartesi.dll src/libcartesi.a src/libluacartesi.a pkg/usr/lib/
x86_64-w64-mingw32-strip -S pkg/usr/lib/*.a
x86_64-w64-mingw32-strip -S -x pkg/usr/lib/*.dll
EOF

# Build cartesi machine cli
COPY cli machine-emulator/src/cli
RUN <<EOF
set -e
cd machine-emulator
make -C src/cli -j$(nproc) \
    TARGET_OS=Windows \
    TABGET_LIBS="-lshlwapi -lws2_32" \
    CC=x86_64-w64-mingw32-gcc \
    CXX=x86_64-w64-mingw32-g++ \
    LDFLAGS= \
    MYCFLAGS=-DNO_JSONRPC \
    MYLDFLAGS="-static-libstdc++ -static-libgcc" \
    CARTESI_LIBS="../libluacartesi.a ../libcartesi.a" \
    SLIRP_LIB=
mkdir -p pkg/usr/bin
cp src/cli/cartesi-machine.exe pkg/usr/bin/
x86_64-w64-mingw32-strip pkg/usr/bin/cartesi-machine.exe
EOF
