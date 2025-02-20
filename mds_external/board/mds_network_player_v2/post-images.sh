#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
OUT_DIR="${BUILD_DIR}/../images/"

GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

rm -rf "${GENIMAGE_TMP}"

genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_CFG}"


mkdir -p "${BUILD_DIR}"/../../../../out/"$(basename "$CONFIG_DIR")"
IMAGE_OUT=$(realpath "${BUILD_DIR}"/../../../../out/"$(basename "$CONFIG_DIR")")
mkdir -p "$IMAGE_OUT"
cp "${OUT_DIR}"/* "${IMAGE_OUT}"

echo "Images are in $IMAGE_OUT"
