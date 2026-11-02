#!/bin/sh
export DISPLAY=:0
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Start Xorg and launch lxsession directly via xinit
exec xinit /usr/bin/lxsession -- :0 vt1 >/var/log/xinit.log 2>&1
