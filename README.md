## Build firmware for f1c200s

`make build`

## Update build firmware for esp-hosted-ng solution

0. enter `src/esp-hosted/esp_hosted_ng/esp/esp_driver`

1. run `cmake .` to setup enviornment, it will setup esp-idf as submodule to be used by `network_adapter`

2. setup compiling environment by `. ./export.sh` in esp-idf directory

3. In the `network_adapter` directory of this project, input command `idf.py set-target <chip_name>` to set target.

4. Use `idf.py build` to recompile `network_adapter` and generate new firmware.

## Checks

Power sources : 
3v3 : OK
5v : OK
2.5v : OK
1.1v : NOK

Communication with ESP32-C2 : OK
Used Arduino + UART, after pressing the reset button on the board, the ESP32-C2 sends a message on the UART.
Problem : Unable to flash esp32-c3, the boot mode by default tries to download the firmware from the USB and not the UART. It seems that the mode can be changed by modifying GPIO8 pin. and pull this GPIO down.

Flashing SPI Nand requires to modify the u-boot-with-spl.bin. This can be done by using the mknandboot.sh script. This is script is located in mds_external/board/mds_network_player and it comes from 
- https://github.com/bamkrs/openwrt/blob/dolphinpi-spinand/target/linux/sunxi/image/gen_sunxi_spinand_onlyboot_img.sh
- https://github.com/TiNredmc/u-boot/blob/v2020/f1c100_uboot_spinand.sh
- https://tinlethax.wordpress.com/2021/04/11/lichee-pi-nano-with-w25n01gv-support-complete-guide/

SPL is booting correctly after executing f1c100_uboot_spinand.sh on u-boot-with-spl.bin. But it doesn't detect the 2nd stage after this. 
That means that BootROM is able to load the SPL and run it, but SPI NAND boot is not supported completely in the SPL itself.
Different solution has been pushed to mailing list : https://patchwork.ozlabs.org/project/uboot/cover/20221014030520.3067228-1-uwu@icenowy.me/

Another one that looks supporting NAND boot : https://github.com/TiNredmc/u-boot/commits/v1.0

9/02/2024 : Boot fro SPI nand is ok
Problem was that mknans=dboot.sh was incorrect. This script split the SPL to be loaded correctly by the BootROM. This was working, but after the bootROM, the SPL itself were not able to load u-boot payload. This has been fixed by correcting the script to load the u-boot size at the correct address.

To flash the SPI NAND, the following command can be used : 

load the u-boot-with-spl.bin in fel mode and write the output ok mknand.sh to address 0x80000000. This is the start of the RAM : 
./sunxi-fel -p uboot images/u-boot-sunxi-with-spl.bin write 0x80000000 images/spi-nand.bin

On a serial console, u-boot starts. The following command can be used to flash the SPI NAND :
```
mtd erase boot ; mtd write.raw boot 0x80000000
```
Then the board can be rebooted and the u-boot will boot from the SPI NAND.: 
```
reset
```


### UBI NOK
```
ubiformat /dev/mtd1
ubiattach -p /dev/mtd1
ubimkvol /dev/ubi0 -N rootfs -m
mount -t ubifs ubi:rootfs /mnt/

umount /mnt
ubidetach -p /dev/mtd1
```

In u-boot
Error mounting ubifs partition + super slow to attache ubi 
```
=> ubi part rootfs
ubi0: attaching mtd2
ubi0: scanning is finished
ubi0: attached mtd2 (name "rootfs", size 127 MiB)
ubi0: PEB size: 131072 bytes (128 KiB), LEB size: 126976 bytes
ubi0: min./max. I/O unit sizes: 2048/2048, sub-page size 2048
ubi0: VID header offset: 2048 (aligned 2048), data offset: 4096
ubi0: good PEBs: 1016, bad PEBs: 0, corrupted PEBs: 0
ubi0: user volume: 1, internal volumes: 1, max. volumes count: 128
ubi0: max/mean erase counter: 1/0, WL threshold: 4096, image sequence number: 1738062171
ubi0: available PEBs: 0, total reserved PEBs: 1016, PEBs reserved for bad PEB handling: 20
=> ubi info l
Volume information dump:
        vol_id          0
        reserved_pebs   992
        alignment       1
        data_pad        0
        vol_type        3
        name_len        6
        usable_leb_size 126976
        used_ebs        992
        used_bytes      125960192
        last_eb_bytes   126976
        corrupted       0
        upd_marker      0
        skip_check      0
        name            rootfs
Volume information dump:
        vol_id          2147479551
        reserved_pebs   2
        alignment       1
        data_pad        0
        vol_type        3
        name_len        13
        usable_leb_size 126976
        used_ebs        2
        used_bytes      253952
        last_eb_bytes   2
        corrupted       0
        upd_marker      0
        skip_check      0
        name            layout volume
=> ubi     
  ubi ubifsload ubifsls ubifsmount ubifsumount
=> ubi
  ubi ubifsload ubifsls ubifsmount ubifsumount
=> ubi
  ubi ubifsload ubifsls ubifsmount ubifsumount
=> ubifsmount rootfs
UBIFS error (pid: 1): cannot open "rootfs", error -22
Error reading superblock on volume 'rootfs' errno=-22!
=> ubifsmount ubi0:rootfs
UBIFS error (ubi0:0 pid 0): validate_sb: bad superblock, error 13
        magic          0x6101831
        crc            0x83e6525
        node_type      6 (superblock node)
        group_type     0 (no node group)
        sqnum          2
        len            4096
        key_hash       0 (R5)
        key_fmt        0 (simple)
        flags          0x8
        big_lpt        0
        space_fixup    0
        min_io_size    2048
        leb_size       126976
        leb_cnt        992
        max_leb_cnt    992
        max_bud_bytes  5713920
        log_lebs       4
        lpt_lebs       2
        orph_lebs      2
        jhead_cnt      1
        fanout         8
        lsave_cnt      256
        default_compr  3
        rp_size        5242880
        rp_uid         0
        rp_gid         0
        fmt_version    5
        time_gran      1000000000
        UUID           83bc6bac
Error reading superblock on volume 'ubi0:rootfs' errno=-22!

```


ubi0: attaching mtd1
ubi0: scanning is finished
ubi0: empty MTD device detected
ubi0: attached mtd1 (name "rootfs", size 127 MiB)
ubi0: PEB size: 131072 bytes (128 KiB), LEB size: 126976 bytes
ubi0: min./max. I/O unit sizes: 2048/2048, sub-page size 2048
ubi0: VID header offset: 2048 (aligned 2048), data offset: 4096
ubi0: good PEBs: 1016, bad PEBs: 0, corrupted PEBs: 0
ubi0: user volume: 0, internal volumes: 1, max. volumes count: 128
ubi0: max/mean erase counter: 0/0, WL threshold: 4096, image sequence number: 1578400881
ubi0: available PEBs: 992, total reserved PEBs: 24, PEBs reserved for bad PEB handling: 20
ubi0: background thread "ubi_bgt0d" started, PID 218
UBIFS error (pid: 229): cannot open "ubi:rootfs", error -19
ubi: mtd1 is already attached to ubi0


=> ubi part rootfs 2048
ubi0: attaching mtd2
ubi0: scanning is finished
ubi0: attached mtd2 (name "rootfs", size 127 MiB)
ubi0: PEB size: 131072 bytes (128 KiB), LEB size: 126976 bytes
ubi0: min./max. I/O unit sizes: 2048/2048, sub-page size 2048
ubi0: VID header offset: 2048 (aligned 2048), data offset: 4096
ubi0: good PEBs: 1016, bad PEBs: 0, corrupted PEBs: 0
ubi0: user volume: 1, internal volumes: 1, max. volumes count: 128
ubi0: max/mean erase counter: 3/2, WL threshold: 4096, image sequence number: 1562993607
ubi0: available PEBs: 0, total reserved PEBs: 1016, PEBs reserved for bad PEB handling: 20

### Mass Storage NOK
```
modprobe g_mass_storage iSerialNumber=123456 file=/mnt/fat32.part stall=0 removable=1

losetup /dev/loop0 /mnt/fat32.part


``` 
### After u-boot config changes :

Boot FEL ok
Boot from NAND ok but not after hard reboot
reset cmd not working :
```
=> reset
resetting ...
System reset not supported on this platform
### ERROR ### Please RESET the board ###
```
bootm cmd not working :
```
=> bootm 0x80000000
Wrong Image Type for bootm command
ERROR -91: can't get kernel image!
```

Add support for FIT image and now OK !
