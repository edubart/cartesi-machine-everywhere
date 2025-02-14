FROM archlinux:base-devel

# Install build tools
RUN pacman -Syyu --noconfirm && \
    pacman -S --noconfirm git wget vim mingw-w64-toolchain lua

# Install libslirp
RUN <<EOF
set -e
git clone --branch v4.8.0-2 --depth 1 https://github.com/edubart/minislirp.git
cd minislirp
make -C src -j$(nproc) install \
    PREFIX=/usr/x86_64-w64-mingw32 \
    CC=x86_64-w64-mingw32-gcc \
    AR="x86_64-w64-mingw32-ar rcs"
cd ..
rm -r minislirp
EOF

# Install lua
RUN <<EOF
set -e
wget -O /usr/x86_64-w64-mingw32/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /usr/x86_64-w64-mingw32/include/lualib.h
echo '#include "minilua.h"' > /usr/x86_64-w64-mingw32/include/lauxlib.h
echo '#include "minilua.h"' > /usr/x86_64-w64-mingw32/include/lua.h
x86_64-w64-mingw32-gcc \
    -o /usr/x86_64-w64-mingw32/lib/lua5.4.dll \
    -x c /usr/x86_64-w64-mingw32/include/minilua.h \
    -fPIC -O2 -DNDEBUG -DLUA_IMPL -DLUA_BUILD_AS_DLL -shared
x86_64-w64-mingw32-gcc -c \
    -o lua.o \
    -x c /usr/x86_64-w64-mingw32/include/minilua.h \
    -fPIC -O2 -DNDEBUG -DLUA_IMPL
ar rcs /usr/x86_64-w64-mingw32/lib/liblua.a lua.o
rm lua.o
EOF

# Download cartesi machine
RUN <<EOF
set -e
git clone --branch refactor/new-readme --depth 1 https://github.com/cartesi/machine-emulator.git
cd machine-emulator
make bundle-boost
EOF

# Patch cartesi machine
RUN <<EOF
set -e
cd machine-emulator

# uarch files
wget https://github.com/cartesi/machine-emulator/releases/download/v0.19.0-test1/add-generated-files.diff
patch -Np1 < add-generated-files.diff
EOF

# Build cartesi machine Lua libraries
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) cartesi.so cartesi/jsonrpc.so \
    TARGET_OS=Windows \
    SO_EXT=dll \
    CC=x86_64-w64-mingw32-gcc \
    CXX=x86_64-w64-mingw32-g++ \
    AR="x86_64-w64-mingw32-ar rcs" \
    MYLDFLAGS="-static-libstdc++ -static-libgcc -lws2_32 -liphlpapi -llua5.4" \
    LUA_INC= LUA_LIB=
rm -f src/*.o src/*.a
mkdir -p pkg/usr/lib/lua/5.4/cartesi
cp src/cartesi.so pkg/usr/lib/lua/5.4/cartesi.dll
cp src/cartesi/jsonrpc.so pkg/usr/lib/lua/5.4/cartesi/jsonrpc.dll
x86_64-w64-mingw32-strip -S -x pkg/usr/lib/lua/5.4/cartesi.dll pkg/usr/lib/lua/5.4/cartesi/jsonrpc.dll
EOF

# Build cartesi machine
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) \
    libcartesi.dll libcartesi.a libluacartesi.a \
    libcartesi_jsonrpc.dll libcartesi_jsonrpc.a libluacartesi_jsonrpc.a \
    TARGET_OS=Windows \
    SO_EXT=dll \
    CC=x86_64-w64-mingw32-gcc \
    CXX=x86_64-w64-mingw32-g++ \
    AR="x86_64-w64-mingw32-ar rcs" \
    MYLDFLAGS="-static-libstdc++ -static-libgcc -lws2_32 -liphlpapi" \
    LUA_INC= LUA_LIB=
make install-headers DESTDIR=pkg
cp src/libcartesi.dll src/libcartesi.a src/libluacartesi.a pkg/usr/lib/
cp src/libcartesi_jsonrpc.dll src/libcartesi_jsonrpc.a src/libluacartesi_jsonrpc.a pkg/usr/lib/
cp /usr/x86_64-w64-mingw32/lib/libslirp.a pkg/usr/lib/
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
    CC=x86_64-w64-mingw32-gcc \
    CXX=x86_64-w64-mingw32-g++ \
    MYLDFLAGS="-static-libstdc++ -static-libgcc"
mkdir -p pkg/usr/bin
cp src/cli/cartesi-machine.exe pkg/usr/bin/
x86_64-w64-mingw32-strip pkg/usr/bin/cartesi-machine.exe
EOF
