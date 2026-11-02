#!/bin/sh
set -e

echo "[+] Preparing rootfs directories..."
mkdir -p rootfs/etc/X11 rootfs/usr/local/bin rootfs/iso_root/boot/syslinux

echo "[+] Installing packages via Alpine Docker container..."
docker run --rm -v "$(pwd)/rootfs:/rootfs" alpine:latest sh -c "
  echo 'https://dl-cdn.alpinelinux.org/alpine/v3.20/main' > /etc/apk/repositories &&
  echo 'https://dl-cdn.alpinelinux.org/alpine/v3.20/community' >> /etc/apk/repositories &&
  apk update &&
  apk add --no-cache --root /rootfs --initdb \
    xorg-server \
    xf86-video-fbdev \
    xf86-input-libinput \
    openbox \
    pcmanfm \
    lxsession
"

echo "[+] Creating init script..."
cat << 'INIT_EOF' > rootfs/init
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /dev/input
mount -t devpts devpts /dev/pts
mkdir -p /run /tmp

exec /usr/local/bin/autostart_gui.sh
INIT_EOF
chmod +x rootfs/init

echo "[+] Creating autostart GUI script..."
cat << 'GUI_EOF' > rootfs/usr/local/bin/autostart_gui.sh
#!/bin/sh
export DISPLAY=:0
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Start Xorg and launch lxsession directly via xinit
exec xinit /usr/bin/lxsession -- :0 vt1 >/var/log/xinit.log 2>&1
GUI_EOF
chmod +x rootfs/usr/local/bin/autostart_gui.sh

echo "[+] Packing initramfs..."
cd rootfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../iso_root/boot/initramfs.gz
cd ..

echo "[+] Build completed successfully!"
