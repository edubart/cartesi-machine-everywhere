FROM crazymax/osxcross:13.1-ubuntu AS osxcross

FROM ubuntu:24.04
RUN apt-get update && \
    apt-get install -y clang lld libc6-dev build-essential git wget xxd
COPY --from=osxcross /osxcross /osxcross
ARG CC_PREFIX
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib"
ENV MACOSX_DEPLOYMENT_TARGET=13.1

# Install libslirp
RUN <<EOF
set -e
git clone --branch v4.8.0-1 --depth 1 https://github.com/edubart/minislirp.git
cd minislirp
make -C src install \
    CC=${CC_PREFIX}-clang \
    AR="llvm-ar-18 rcs" \
    MYCFLAGS="-include unistd.h" \
    PREFIX=/osxcross/SDK/MacOSX13.1.sdk/usr
cd ..
rm -rf minislirp
EOF

# Install lua
RUN <<EOF
set -e
wget -O /osxcross/SDK/MacOSX13.1.sdk/usr/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /osxcross/SDK/MacOSX13.1.sdk/usr/include/lualib.h
echo '#include "minilua.h"' > /osxcross/SDK/MacOSX13.1.sdk/usr/include/lauxlib.h
echo '#include "minilua.h"' > /osxcross/SDK/MacOSX13.1.sdk/usr/include/lua.h
EOF

# Install cartesi machine
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
    TARGET_OS=Darwin \
    CC=${CC_PREFIX}-clang \
    CXX=${CC_PREFIX}-clang++ \
    AR="llvm-ar-18 rcs" \
    SLIRP_LIB="-lslirp -lresolv" \
    LUA_INC= LUA_LIB=
make install \
    TARGET_OS=Darwin \
    STRIP=llvm-strip-18 \
    PREFIX=/usr \
    DESTDIR=pkg
EOF

# Build cartesi machine cli
COPY cli machine-emulator/src/cli
RUN <<EOF
set -e
cd machine-emulator
make -C src/cli -j$(nproc) \
    TARGET_OS=Darwin \
    CC=${CC_PREFIX}-clang \
    CXX=${CC_PREFIX}-clang++ \
    SLIRP_LIB="-lslirp -lresolv"
rm -r pkg/usr/share/lua pkg/usr/share/cartesi-machine/gdb \
    pkg/usr/bin/cartesi-machine-stored-hash \
    pkg/usr/bin/merkle-tree-hash
cp src/cli/cartesi-machine pkg/usr/bin/
llvm-strip-18 pkg/usr/bin/cartesi-machine
EOF
