#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
OUT_DIR="${BUILD_DIR}/../images"

mkdir -p ${BUILD_DIR}/../../../../out/fota
cp ${OUT_DIR}/* ${BUILD_DIR}/../../../../out/fota
cp ${BOARD_DIR}/uboot.bootstrap.env ${BUILD_DIR}/../../../../out/fota
cp ${BOARD_DIR}/bootstrap.sh ${BUILD_DIR}/../../../../out/fota


exit $?
