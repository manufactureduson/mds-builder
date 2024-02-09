#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
OUT_DIR="${BUILD_DIR}/../images/"

FIT_IMAGE_CFG="${BOARD_DIR}/image.its"
FIT_IMAGE_OUT="${OUT_DIR}/mds_network_player.itb"

echo "FIT_IMAGE_CFG: ${FIT_IMAGE_CFG}"
echo "FIT_IMAGE_OUT: ${FIT_IMAGE_OUT}"

cp "$FIT_IMAGE_CFG" "$OUT_DIR"
cd "$OUT_DIR"
/usr/bin/mkimage -f image.its "${FIT_IMAGE_OUT}"

"$BOARD_DIR"/mknandboot.sh "${OUT_DIR}/spi-nand.bin" "${OUT_DIR}"/u-boot-sunxi-with-spl.bin 

exit $?
