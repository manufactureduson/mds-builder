# ~/Dev/sunxi-tools/sunxi-fel -v uboot out/u-boot-sunxi-with-spl.bin \
#   write-with-progress 0x80000000 out/mds_network_player.itb


if [ "$#" -ne 1 ]; then
   echo "Usage: $0 <serial_port>"
   exit 1
fi

~/Dev/sunxi-tools/sunxi-fel -v uboot out/network_player_bootstrap/u-boot-sunxi-with-spl.bin \
   write-with-progress 0x80000000 out/network_player_bootstrap/uImage \
   write-with-progress 0x80500000 out/network_player_bootstrap/rootfs.cpio.uboot \
   write-with-progress 0x80FE0000 out/network_player_bootstrap/suniv-f1c200s-mds-network-streamer-v1.0.dtb
   
#   write-with-progress 0x80000000 out/rootfs.ubi


echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1
echo ' ' > $1

sleep 1
echo "bootm 0x80000000 0x80500000 0x80FE0000" > $1

