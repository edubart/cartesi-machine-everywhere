FROM crazymax/osxcross:13.1-ubuntu AS osxcross

FROM ubuntu:24.04
RUN apt-get update && \
    apt-get install -y clang lld libc6-dev build-essential git wget xxd lua5.4
COPY --from=osxcross /osxcross /osxcross
ARG CC_PREFIX
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib"
ENV MACOSX_DEPLOYMENT_TARGET=13.1

# Install libslirp
RUN <<EOF
set -e
git clone --branch v4.8.0-2 --depth 1 https://github.com/edubart/minislirp.git
cd minislirp
make -C src -j$(nproc) install \
    CC=${CC_PREFIX}-clang \
    AR="llvm-ar-18 rcs" \
    MYCFLAGS="-include unistd.h" \
    PREFIX=/osxcross/SDK/MacOSX13.1.sdk/usr
cd ..
rm -r minislirp
EOF

# Install lua
RUN <<EOF
set -e
wget -O /osxcross/SDK/MacOSX13.1.sdk/usr/include/minilua.h https://raw.githubusercontent.com/edubart/minilua/v5.4.7/minilua.h
echo '#include "minilua.h"' > /osxcross/SDK/MacOSX13.1.sdk/usr/include/lualib.h
echo '#include "minilua.h"' > /osxcross/SDK/MacOSX13.1.sdk/usr/include/lauxlib.h
echo '#include "minilua.h"' > /osxcross/SDK/MacOSX13.1.sdk/usr/include/lua.h
${CC_PREFIX}-clang -c -o lua.o -x c /osxcross/SDK/MacOSX13.1.sdk/usr/include/minilua.h -O2 -fPIC -DNDEBUG -DLUA_IMPL
llvm-ar-18 rcs /osxcross/SDK/MacOSX13.1.sdk/usr/lib/liblua.a lua.o
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
    CXX=${CC_PREFIX}-clang++
rm -r pkg/usr/share/lua pkg/usr/share/cartesi-machine/gdb \
    pkg/usr/bin/cartesi-machine-stored-hash \
    pkg/usr/bin/merkle-tree-hash
cp src/cli/cartesi-machine pkg/usr/bin/
llvm-strip-18 pkg/usr/bin/cartesi-machine
EOF
