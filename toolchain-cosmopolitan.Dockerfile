FROM alpine:3.20

RUN apk update && \
    apk add git patch make xxd unzip

# Install cosmopolitan
RUN <<EOF
wget -O /usr/bin/ape https://cosmo.zip/pub/cosmos/bin/ape-$(uname -m).elf
chmod +x /usr/bin/ape
mkdir -p cosmocc
cd cosmocc
wget https://github.com/jart/cosmopolitan/releases/download/3.9.4/cosmocc-3.9.4.zip
unzip cosmocc-3.9.4.zip
EOF

ENV PATH=$PATH:/cosmocc/bin

# Install libslirp
RUN <<EOF
set -e
git clone --branch v4.8.0-2 --depth 1 https://github.com/edubart/minislirp.git
cd minislirp
sed -i 's|if_nametoindex|0,|' src/slirp.c
make -C src install \
    PREFIX=/cosmocc \
    CC=cosmocc \
    AR="cosmoar rcs"
mkdir -p /cosmocc/lib/.aarch64/
cp src/.aarch64/libslirp.a /cosmocc/lib/.aarch64/
cd ..
rm -r minislirp
EOF

# Install lua
RUN <<EOF
set -e
wget -O /cosmocc/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /cosmocc/include/lualib.h
echo '#include "minilua.h"' > /cosmocc/include/lauxlib.h
echo '#include "minilua.h"' > /cosmocc/include/lua.h
cosmocc -c -o lua.o -x c /cosmocc/include/minilua.h -O2 -fPIC -DNDEBUG -DLUA_IMPL
cosmoar rcs /cosmocc/lib/liblua.a lua.o
rm lua.o
EOF

# Download cartesi machine
RUN <<EOF
set -e
echo bump2
git clone --branch edubart --depth 1 https://github.com/cartesi/machine-emulator.git
cd machine-emulator
make bundle-boost
EOF

# Patch cartesi machine
RUN <<EOF
set -e
cd machine-emulator

# uarch files
wget https://github.com/cartesi/machine-emulator/releases/download/v0.18.1/add-generated-files.diff
patch -Np0 < add-generated-files.diff

# # feature/windows-virtio-9p
# wget https://github.com/cartesi/machine-emulator/pull/242.patch
# patch -Np1 < 242.patch

# # feature/optim-fetch
# wget https://github.com/cartesi/machine-emulator/pull/226.patch
# patch -Np1 < 226.patch
EOF

# Build cartesi machine
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) libcartesi.a libluacartesi.a \
    CC=cosmocc \
    CXX=cosmoc++ \
    AR="cosmoar rcs" \
    LUA_INC= LUA_LIB=
EOF

# Build cartesi machine cli
COPY cli machine-emulator/src/cli
RUN <<EOF
set -e
cd machine-emulator
ls -la /cosmocc/lib/.aarch64
make -C src/cli -j$(nproc) \
    CC=cosmocc \
    CXX=cosmoc++ \
    MYCFLAGS=-DNO_CARTESI_JSONRPC \
    CARTESI_JSONRPC_LIBS= \
    LUA_LIB=/cosmocc/lib/liblua.a \
    SLIRP_LIB=/cosmocc/lib/libslirp.a
mkdir -p pkg/usr/bin/
cp src/cli/cartesi-machine pkg/usr/bin/
EOF
