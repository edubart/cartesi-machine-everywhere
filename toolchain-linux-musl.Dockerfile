FROM alpine:3.21

RUN apk update && \
    apk upgrade && \
    apk add git gcc g++ musl-dev patch make boost-dev xxd patchelf lua5.4

# Install libslirp
RUN <<EOF
set -e
git clone --branch v4.8.0-2 --depth 1 https://github.com/edubart/minislirp.git
cd minislirp
make -C src -j$(nproc) install
cd ..
rm -r minislirp
EOF

# Install lua
RUN <<EOF
set -e
wget -O /usr/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /usr/include/lualib.h
echo '#include "minilua.h"' > /usr/include/lauxlib.h
echo '#include "minilua.h"' > /usr/include/lua.h
gcc -c -o lua.o -x c /usr/include/minilua.h -O2 -fPIC -DNDEBUG -DLUA_IMPL
ar rcs /usr/lib/liblua.a lua.o
rm lua.o
EOF

# Download cartesi machine
RUN <<EOF
set -e
git clone --branch refactor/new-readme --depth 1 https://github.com/cartesi/machine-emulator.git
cd machine-emulator
EOF

# Patch cartesi machine
RUN <<EOF
set -e
cd machine-emulator

# uarch files
wget https://github.com/cartesi/machine-emulator/releases/download/v0.19.0-test1/add-generated-files.diff
patch -Np1 < add-generated-files.diff
EOF

# Build cartesi machine
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) \
    MYLDFLAGS="-static-libstdc++ -static-libgcc" \
    MYEXELDFLAGS="-static" \
    LUA_INC= LUA_LIB=
make install PREFIX=/usr DESTDIR=pkg
cp /usr/local/lib/libslirp.a pkg/usr/lib/
EOF

# Build cartesi machine cli
COPY cli machine-emulator/src/cli
RUN <<EOF
set -e
cd machine-emulator
make -C src/cli -j$(nproc) \
    MYLDFLAGS="-static-libstdc++ -static-libgcc -static"
rm -r pkg/usr/share/lua pkg/usr/share/cartesi-machine/gdb \
    pkg/usr/bin/cartesi-machine-stored-hash \
    pkg/usr/bin/merkle-tree-hash
cp src/cli/cartesi-machine pkg/usr/bin/
strip pkg/usr/bin/cartesi-machine
EOF

# Fix missing MUSL libc in other distributions
RUN <<EOF
set -e
find machine-emulator/pkg -name '*.so' -exec \
    patchelf --replace-needed libc.musl-$(uname -m).so.1 /lib/ld-musl-$(uname -m).so.1 {} \;
EOF
