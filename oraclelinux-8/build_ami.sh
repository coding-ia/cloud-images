#!/bin/bash -ex

DEVICE=/dev/xvdb
ROOTFS=/rootfs

dnf install -y gdisk wget dosfstools unzip

sgdisk --zap-all ${DEVICE}
sgdisk -og ${DEVICE}

sgdisk -n 1:0:0 -t 1:8300 -c 1:"Linux filesystem" ${DEVICE}

mkfs.xfs ${DEVICE}1 -f

# Mount the rootfs
mkdir -p ${ROOTFS}
mount ${DEVICE}1 ${ROOTFS}


