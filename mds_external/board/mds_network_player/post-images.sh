#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
OUT_DIR="${BUILD_DIR}/../images/"

"$BOARD_DIR"/mknandboot.sh "${OUT_DIR}/spi-nand.bin" "${OUT_DIR}"/u-boot-sunxi-with-spl.bin > /dev/null 2>&1

mkdir -p "${BUILD_DIR}"/../../../../out/"$(basename "$CONFIG_DIR")"
IMAGE_OUT=$(realpath "${BUILD_DIR}"/../../../../out/"$(basename "$CONFIG_DIR")")

mkdir -p "$IMAGE_OUT"
cp "${OUT_DIR}"/* "${IMAGE_OUT}"

echo "Images are in $IMAGE_OUT"
