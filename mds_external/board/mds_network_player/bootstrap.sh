ssh-keygen -f ~/.ssh/known_hosts -R "192.168.2.2"

~/Dev/sunxi-tools/sunxi-fel -v uboot ../u-boot-sunxi-with-spl.bin \
   write-with-progress 0x80000000 uboot.bootstrap.env \
   write-with-progress 0x80020000 uImage \
   write-with-progress 0x80FE0000 suniv-f1c200s-mds-network-streamer-v1.0.dtb
