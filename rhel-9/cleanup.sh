#!/bin/bash -ex

rm redhat* -rf

umount /rootfs/dev
umount /rootfs/proc
umount /rootfs/sys/fs/selinux
umount /rootfs/sys
umount /rootfs/boot/efi
umount /rootfs/boot
umount /rootfs
