#!/bin/bash
set -e

ALPINE_VERSION="3.20.0"
ARCH="x86_64"
BUILD_DIR="./alpine_iso_build"
KERNEL_VERSION="6.6.21"

echo "[*] Setting up workspace directory at $BUILD_DIR..."
mkdir -p "$BUILD_DIR/iso_root/boot" "$BUILD_DIR/rootfs" && cd "$BUILD_DIR"

if [ ! -f "alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz" ]; then
    echo "[*] Downloading Alpine minirootfs..."
    wget "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/$ARCH/alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz"
fi
sudo tar -xzf "alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz" -C rootfs

if [ ! -d "linux-$KERNEL_VERSION" ]; then
    echo "[*] Downloading Linux kernel v$KERNEL_VERSION..."
    wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz"
    tar -xf "linux-$KERNEL_VERSION.tar.xz"
fi

cd "linux-$KERNEL_VERSION"
if [ ! -f "arch/x86/boot/bzImage" ]; then
    echo "[*] Configuring and compiling minimal kernel..."
    make defconfig
    scripts/config --disable CONFIG_SOUND
    scripts/config --disable CONFIG_WIRELESS
    scripts/config --disable CONFIG_NETFILTER
    scripts/config --set-val CONFIG_BASE_SMALL 1
    make -j$(nproc) bzImage
fi

cp arch/x86/boot/bzImage ../iso_root/boot/vmlinuz
cd ..

echo "[*] Packing rootfs into initramfs..."
cd rootfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../iso_root/boot/initramfs.gz
cd ..

echo "[*] Setting up bootloader..."
mkdir -p iso_root/boot/syslinux
cat << 'CFG' > iso_root/boot/syslinux/syslinux.cfg
DEFAULT alpine
TIMEOUT 10
PROMPT 1

LABEL alpine
    KERNEL /boot/vmlinuz
    INITRD /boot/initramfs.gz
    APPEND root=/dev/ram0 init=/sbin/init
CFG

cp /usr/lib/ISOLINUX/isolinux.bin iso_root/boot/syslinux/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 iso_root/boot/syslinux/

echo "[*] Generating bootable ISO image..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "CUSTOM_ALPINE" \
    -eltorito-boot boot/syslinux/isolinux.bin \
    -eltorito-catalog boot/syslinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -output custom_alpine_ram_optimized.iso \
    iso_root

echo "[+] Success! Bootable ISO generated: $BUILD_DIR/custom_alpine_ram_optimized.iso"
