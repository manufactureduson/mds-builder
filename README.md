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
