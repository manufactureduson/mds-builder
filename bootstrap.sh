# ~/Dev/sunxi-tools/sunxi-fel -v uboot out/u-boot-sunxi-with-spl.bin \
#   write-with-progress 0x80000000 out/mds_network_player.itb


~/Dev/sunxi-tools/sunxi-fel -v uboot out/u-boot-sunxi-with-spl.bin \
   write-with-progress 0x80000000 out/uImage \
   write-with-progress 0x80400000 out/rootfs.cpio.uboot \
   write-with-progress 0x80FE0000 out/suniv-f1c200s-mds-network-streamer-v1.0.dtb

echo "bootm 0x80000000 0x80400000 0x80FE0000"
