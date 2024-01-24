#!/bin/sh

umount /mnt
mount /dev/mmcblk0p1 /mnt/
touch /mnt/logs
ip a >> /mnt/logs
modprobe brcmfmac
dmesg >> /mnt/logs
lsmod >> /mnt/logs
journalctl -b >> /mnt/logs
sync
umount /mnt