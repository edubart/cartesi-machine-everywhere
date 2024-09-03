ROOTFS_VER=v0.16.1
KERNEL_VER=v0.20.0
LINUX_VER=6.5.13-ctsi-1-$(KERNEL_VER)
LINUX_BIN=linux-$(LINUX_VER).bin
ROOTFS_EXT2=rootfs-tools-$(ROOTFS_VER).ext2

all: linux macos windows wasm

$(LINUX_BIN):
	wget -O $@ https://github.com/cartesi/image-kernel/releases/download/$(KERNEL_VER)/$@
$(ROOTFS_EXT2):
	wget -O $@ https://github.com/cartesi/machine-emulator-tools/releases/download/$(ROOTFS_VER)/$@

linux: linux-glibc linux-musl
linux-glibc: cartesi-machine-linux-glibc-amd64 cartesi-machine-linux-glibc-arm64 cartesi-machine-linux-glibc-riscv64
linux-musl: cartesi-machine-linux-musl-amd64 cartesi-machine-linux-musl-arm64 cartesi-machine-linux-musl-riscv64
macos: cartesi-machine-macos-amd64 cartesi-machine-macos-arm64
windows: cartesi-machine-windows-amd64
wasm: cartesi-machine-wasm

# Linux GLIBC
cartesi-machine-linux-glibc-%: toolchain-linux-glibc.Dockerfile cli/* $(LINUX_BIN) $(ROOTFS_EXT2)
	rm -rf $@ $@.tar.xz
	docker build --tag cmdist/toolchain-$@ --file $< --progress plain --platform linux/$* .
	docker create --platform=linux/$* --name cmdist-$@-copy cmdist/toolchain-$@
	docker cp cmdist-$@-copy:/machine-emulator/pkg/usr $@
	docker rm cmdist-$@-copy
	mkdir -p $@/share/cartesi-machine/images
	touch $@
	cp $(LINUX_BIN) $(ROOTFS_EXT2) $@/share/cartesi-machine/images/
	ln -s $(LINUX_BIN) $@/share/cartesi-machine/images/linux.bin
	ln -s $(ROOTFS_EXT2) $@/share/cartesi-machine/images/rootfs.ext2
	mkdir -p $@/share/licenses/cartesi-machine
	cp COPYING $@/share/licenses/cartesi-machine/COPYING
	tar cf - $@ | xz -z - > $@.tar.xz

# Linux MUSL
cartesi-machine-linux-musl-%: toolchain-linux-musl.Dockerfile cli/* $(LINUX_BIN) $(ROOTFS_EXT2)
	rm -rf $@ $@.tar.xz
	docker build --tag cmdist/toolchain-$@ --file $< --progress plain --platform linux/$* .
	docker create --platform=linux/$* --name cmdist-$@-copy cmdist/toolchain-$@
	docker cp cmdist-$@-copy:/machine-emulator/pkg/usr $@
	docker rm cmdist-$@-copy
	mkdir -p $@/share/cartesi-machine/images
	touch $@
	cp $(LINUX_BIN) $(ROOTFS_EXT2) $@/share/cartesi-machine/images/
	ln -s $(LINUX_BIN) $@/share/cartesi-machine/images/linux.bin
	ln -s $(ROOTFS_EXT2) $@/share/cartesi-machine/images/rootfs.ext2
	mkdir -p $@/share/licenses/cartesi-machine
	cp COPYING $@/share/licenses/cartesi-machine/COPYING
	tar cf - $@ | xz -z - > $@.tar.xz

# MacOS
cartesi-machine-macos-amd64: CC_PREFIX=o64
cartesi-machine-macos-arm64: CC_PREFIX=oa64
cartesi-machine-macos-%: toolchain-macos.Dockerfile cli/* $(LINUX_BIN) $(ROOTFS_EXT2)
	rm -rf $@ $@.tar.gz
	docker build --tag cmdist/toolchain-$@ --file $< --progress plain --build-arg CC_PREFIX=$(CC_PREFIX) .
	docker create --name cmdist-$@-copy cmdist/toolchain-$@
	docker cp cmdist-$@-copy:/machine-emulator/pkg/usr $@
	docker rm cmdist-$@-copy
	touch $@
	mkdir -p $@/share/cartesi-machine/images
	cp $(LINUX_BIN) $(ROOTFS_EXT2) $@/share/cartesi-machine/images/
	ln -s $(LINUX_BIN) $@/share/cartesi-machine/images/linux.bin
	ln -s $(ROOTFS_EXT2) $@/share/cartesi-machine/images/rootfs.ext2
	mkdir -p $@/share/licenses/cartesi-machine
	cp COPYING $@/share/licenses/cartesi-machine/COPYING
	tar cf - $@ | pigz -9 - > $@.tar.gz

# Windows
cartesi-machine-windows-%: toolchain-windows.Dockerfile cli/* $(LINUX_BIN) $(ROOTFS_EXT2)
	rm -rf $@ $@.zip
	docker build --tag cmdist/toolchain-$@ --file $< --progress plain .
	docker create --name cmdist-$@-copy cmdist/toolchain-$@
	docker cp cmdist-$@-copy:/machine-emulator/pkg/usr $@
	docker rm cmdist-$@-copy
	touch $@
	mkdir -p $@/share/cartesi-machine/images
	cp $(LINUX_BIN) $@/share/cartesi-machine/images/linux.bin
	cp $(ROOTFS_EXT2) $@/share/cartesi-machine/images/rootfs.ext2
	mkdir -p $@/share/licenses/cartesi-machine
	cp COPYING $@/share/licenses/cartesi-machine/COPYING
	zip -q9r $@.zip $@

# WebAssembly
cartesi-machine-wasm: toolchain-wasm.Dockerfile cli/* $(LINUX_BIN) $(ROOTFS_EXT2)
	rm -rf $@ $@.tar.xz
	docker build --tag cmdist/toolchain-$@ --file $< --progress plain .
	docker create --name cmdist-$@-copy cmdist/toolchain-$@
	docker cp cmdist-$@-copy:/machine-emulator/pkg/usr $@
	docker rm cmdist-$@-copy
	mkdir -p $@/share/cartesi-machine/images
	touch $@
	cp $(LINUX_BIN) $(ROOTFS_EXT2) $@/share/cartesi-machine/images/
	ln -s $(LINUX_BIN) $@/share/cartesi-machine/images/linux.bin
	ln -s $(ROOTFS_EXT2) $@/share/cartesi-machine/images/rootfs.ext2
	mkdir -p $@/share/licenses/cartesi-machine
	cp COPYING $@/share/licenses/cartesi-machine/COPYING
	tar cf - $@ | xz -z - > $@.tar.xz

clean:
	rm -rf cartesi-machine-*

distclean: clean
	rm -f linux-*.bin rootfs-*.ext2

clean-docker-images:
	docker rmi $(shell docker images | grep cmdist/toolchain | awk '{print $1}')
