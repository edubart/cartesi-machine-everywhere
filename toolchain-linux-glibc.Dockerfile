FROM ubuntu:22.04

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git wget xxd gcc g++ make patch

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

# Install libslirp
RUN <<EOF
set -e
git clone --branch v4.8.0-1 --depth 1 https://github.com/edubart/minislirp.git
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
rm -f lua.o
EOF

# Download cartesi machine
RUN <<EOF
set -e
git clone --branch feature/optim-fetch --depth 1 https://github.com/cartesi/machine-emulator.git
cd machine-emulator
make bundle-boost
wget https://github.com/cartesi/machine-emulator/releases/download/v0.18.1/add-generated-files.diff
patch -Np0 < add-generated-files.diff
EOF

# Build cartesi machine
RUN <<EOF
set -e
cd machine-emulator
make -C src -j$(nproc) \
    MYLDFLAGS="-static-libstdc++ -static-libgcc" \
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
    MYLDFLAGS="-static-libstdc++ -static-libgcc"
rm -r pkg/usr/share/lua pkg/usr/share/cartesi-machine/gdb \
    pkg/usr/bin/cartesi-machine-stored-hash \
    pkg/usr/bin/merkle-tree-hash
cp src/cli/cartesi-machine pkg/usr/bin/
strip pkg/usr/bin/cartesi-machine
EOF
