#!/bin/bash -ex

rm oraclelinux* -rf
rm yum* -rf

umount /rootfs/dev
umount /rootfs/proc
umount /rootfs/sys/fs/selinux
umount /rootfs/sys
umount /rootfs

