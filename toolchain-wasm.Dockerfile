FROM archlinux:base-devel

# Install build tools
RUN pacman -Syyu --noconfirm && \
    pacman -S --noconfirm git wget vim emscripten wasi-libc wasi-libc++ wasi-libc++abi wasi-compiler-rt clang llvm lld

# Install lua
RUN <<EOF
set -e
wget -O /usr/lib/emscripten/system/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /usr/lib/emscripten/system/include/lualib.h
echo '#include "minilua.h"' > /usr/lib/emscripten/system/include/lauxlib.h
echo '#include "minilua.h"' > /usr/lib/emscripten/system/include/lua.h

wget -O /usr/share/wasi-sysroot/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /usr/share/wasi-sysroot/include/lualib.h
echo '#include "minilua.h"' > /usr/share/wasi-sysroot/include/lauxlib.h
echo '#include "minilua.h"' > /usr/share/wasi-sysroot/include/lua.h
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
source /etc/profile.d/emscripten.sh
cd machine-emulator
make -C src -j$(nproc) \
    libcartesi.a \
    SO_EXT=wasm \
    CC=emcc \
    CXX=em++ \
    MYDEFS="-DNO_POSIX_FILE -DNO_THREADS -DNO_IOCTL -DNO_TERMIOS" \
    AR="emar rcs" \
    LUA_LIB= LUA_INC= \
    OPTFLAGS="-O3 -g0" \
    slirp=no
make install-headers install-static-libs \
    STRIP=emstrip \
    EMU_TO_LIB_A="src/libcartesi.a" \
    PREFIX=/usr \
    DESTDIR=pkg
EOF

# This is disabled because we need WASM exceptions,
# but there is no WASM runtime with proper support for exception handling,
# at the time of this writing.

# Build cartesi machine cli
# COPY cli machine-emulator/src/cli
# RUN <<EOF
# set -e
# source /etc/profile.d/emscripten.sh
# cd machine-emulator
# make -C src/cli -j$(nproc) \
#     EXE=cartesi-machine.wasm \
#     CC=em++ \
#     CXX=em++ \
#     MYLDFLAGS="-sSTACK_SIZE=4MB -sTOTAL_MEMORY=512MB" \
#     MYCFLAGS="-DLUA_USE_POSIX -DNO_JSONRPC -O3 -g" \
#     CARTESI_LIBS="../libluacartesi.a ../libcartesi.a" \
#     SLIRP_LIB=
# mkdir -p pkg/usr/bin
# cp src/cli/cartesi-machine.wasm pkg/usr/bin/
# wasm-opt -Oz --enable-bulk-memory --enable-threads --strip-dwarf pkg/usr/bin/cartesi-machine.wasm
# EOF
