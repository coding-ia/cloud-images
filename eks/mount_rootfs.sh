#!/bin/bash -ex

DEVICE=/dev/xvdb
ROOTFS=/rootfs

# Mount the rootfs
mkdir -p ${ROOTFS}
mount ${DEVICE}1 ${ROOTFS}

