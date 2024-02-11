#!/bin/bash

set -e
[ $# -eq 2 ] || {
    echo "SYNTAX: $0 <outputfile> <u-boot image>"
    echo "Given: $@"
    exit 1
}

OUTPUT="$1"
UBOOT="$2"
PAGESIZE=2048
BLOCKSIZE=128

TOOLCHECK=$(od --help | grep 'endia')
if [ "$TOOLCHECK" == "" ]; then
	echo "od cmd is too old not support endian"
	exit -1
fi
# SPL-Size is an uint32 at 16 bytes offset contained in the SPL header
#uboot header offset head in include/configs/sunxi-common.h CONFIG_SYS_SPI_U_BOOT_OFFS so spl max size is CONFIG_SYS_SPI_U_BOOT_OFFS
#f1c100s modify CONFIG_SYS_SPI_U_BOOT_OFFS to 0xd000(52K)
SPLSIZE=$(od -An -t u4 -j16 -N4 "$UBOOT" | xargs)
printf "SPLSIZE:%d(0x%x)\n" $SPLSIZE $SPLSIZE
# The u-boot size is an uint32 at (0xd000 + 12) bytes offset uboot start offset 0xd000(52K)
UBOOTSIZE=$(od --endian=big -An -t u4 -j$((32768 + 12)) -N4 "$UBOOT" | xargs)
printf "UBOOTSIZE:%d(0x%x)\n" $UBOOTSIZE $UBOOTSIZE
ALIGNCHECK=$(($PAGESIZE%1024))
if [ "$ALIGNCHECK" -ne "0" ]; then
	echo "Page-size is not 1k alignable and thus not supported by EGON"
	exit -1
fi

KPAGESIZE=$(($PAGESIZE/1024))
SPLBLOCKS=25

echo "Generating boot0 for boot part of max size 0x8000 SPLBLOCKS:$SPLBLOCKS"
dd if="/dev/zero" of="$OUTPUT" bs=1024 count=$((32 - $SPLBLOCKS))

for splcopy in `seq 0 $SPLBLOCKS`;
do
	to=$(($splcopy*$KPAGESIZE))
	echo "Copying block $splcopy to $to" 
	dd if="$UBOOT" of="$OUTPUT" bs=1024 count=1 seek=$to skip=$splcopy conv=notrunc
done

echo "Appending u-boot"
dd if="$UBOOT" of="$OUTPUT" bs=1024 seek=32 skip=32 conv=notrunc
sync
echo "done"
