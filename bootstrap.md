# bootstrap

Bootstrap process consist to run an initial software on the board and from this software, flash the final software.
This software is build with the machine mds_network_bootstrap. We need first to buiild it :
```bash
make build MACHINE=mds_network_bootstrap
```

the output files are located in out/mds_network_bootstrap

Once the image is build, we can run `bootstrap.sh` script to load the image in the RAM and execute u-boot on it. This script will also load uImage and the rootfsimage in the RAM.

It uses the sunxi-fel tool to load the image in the RAM. This tool is available in the sunxi-tools package. It's possible to build it for macos aswell.

The bootstrap script takes a serial console as argument to interrupt the boot process and enter the u-boot console. The serial console is the device file of the serial port connected to the board. For example, /dev/ttyUSB0 or /dev/tty.usbserial-FTA02VH8

```bash
./bootstrap /dev/tty.usbserial-FTA02VH8
```

Once the prompt display Staring U-Boot (0x81700000).
We can open a console on the device :
```
picocom -b 115200 /dev/tty.usbserial-FTA02VH8
```
Then we need to flash the board with the output files. The board is connected to the computer with a USB cable.

Now we should have a console on the Linux system running on the board. We can login with the root user and the password root.

We should also be able to connect the board trough ssh with the root user and the password root. The connexion is done thanks to the USB network gardget. The IP address of the board is 192.168.2.2


# Flashing the board

We need first to format the flash memory of the board. We can do it with the following command :
```bash

flash_erase /dev/mtd0 0 0
flash_erase /dev/mtd1 0 0
flash_erase /dev/mtd2 0 0
flash_erase /dev/mtd3 0 0

```
Then we can attach ubi partition to the mtd device :
```bash
ubiformat /dev/mtd1
ubiformat /dev/mtd2
ubiformat /dev/mtd3
```

attach all partitions
```
ubiattach -p /dev/mtd1
ubiattach -p /dev/mtd2
ubiattach -p /dev/mtd3
```

Generate partitions
```
ubimkvol /dev/ubi0 -N fota -m
ubimkvol /dev/ubi1 -N rootfs -m
ubimkvol /dev/ubi2 -N data -m
mkdir /mnt/fota /mnt/rootfs /mnt/data

mount -t ubifs /dev/ubi2_0    /mnt/data
```

Then copy to the rootfs and bootloader to the data partition
From the Host :
```
scp -O out/network_player/rootfs.ubifs root@192.168.2.2:/mnt/data
scp -O out/network_player/spi-nand.bin root@192.168.2.2:/mnt/data
```

And flash the files fron the target:
```
flashcp /mnt/data/spi-nand.bin /dev/mtd0
ubiupdatevol /dev/ubi1_0 /mnt/data/rootfs.ubifs
```

Then we can reboot the board and the new software should be running on the board.
