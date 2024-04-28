#!/bin/bash -ex

DEVICE=/dev/xvdf
ROOTFS=/rootfs

apt-get install -y gdisk wget dosfstools unzip debootstrap

sgdisk --zap-all ${DEVICE}
sgdisk -og ${DEVICE}

sgdisk --new=14:0:+4M --typecode=14:EF02 ${DEVICE}
sgdisk --new=15:0:+106M --typecode=15:EF00 --attributes=15:set:2 ${DEVICE}
sgdisk --new=1:0:0 --typecode=1:8300 ${DEVICE}

mkfs.vfat -n UEFI -F 32 ${DEVICE}15
mkfs.ext4 -L cloudimg-rootfs ${DEVICE}1 -F

# Mount the rootfs
mkdir -p ${ROOTFS}
mount ${DEVICE}1 ${ROOTFS}

# Create /boot/ef in rootfs/boot and mount device
mkdir -p ${ROOTFS}/boot/efi
mount ${DEVICE}15 ${ROOTFS}/boot/efi

debootstrap \
  --arch=amd64 \
  --variant=minbase \
  jammy \
  ${ROOTFS} \
  http://archive.ubuntu.com/ubuntu/

# Setup other mounts
mkdir -p ${ROOTFS}/{dev,proc,sys}
mount -t proc none ${ROOTFS}/proc
mount --bind /dev ${ROOTFS}/dev
mount -t sysfs sysfs ${ROOTFS}/sys

DEBIAN_FRONTEND=noninteractive chroot ${ROOTFS} apt-get install -y linux-aws \
  cloud-init \
  cloud-initramfs-copymods \
  cloud-initramfs-dyn-netconf \
  chrony \
  cron \
  ec2-hibinit-agent \
  ec2-instance-connect \
  grub-common \
  grub-efi-amd64-bin \
  grub-pc \
  grub2-common \
  linux-aws \
  man \
  openssh-server \
  python3 \
  shim-signed \
  ubuntu-minimal

cat > ${ROOTFS}/etc/fstab << END
LABEL=cloudimg-rootfs   /        ext4   discard,errors=remount-ro       0 1
LABEL=UEFI      /boot/efi       vfat    umask=0077      0 1
END

chroot ${ROOTFS} grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy
chroot ${ROOTFS} grub-install --target=i386-pc --bootloader-id=ubuntu --recheck --no-floppy ${DEVICE}

chroot ${ROOTFS} grub-mkconfig -o /boot/grub/grub.cfg
chroot ${ROOTFS} grub-mkconfig -o /boot/efi/EFI/ubuntu/grub.cfg
chroot ${ROOTFS} grub-install --recheck ${DEVICE}

chroot ${ROOTFS} apt-get clean

truncate -s 0 ${ROOTFS}/etc/machine-id
truncate -s 0 ${ROOTFS}/etc/hostname
truncate -s 0 ${ROOTFS}/etc/resolv.conf
truncate -s 0 ${ROOTFS}/var/log/alternatives.log
truncate -s 0 ${ROOTFS}/var/log/btmp
truncate -s 0 ${ROOTFS}/var/log/dpkg.log
truncate -s 0 ${ROOTFS}/var/log/faillog
truncate -s 0 ${ROOTFS}/var/log/lastlog
truncate -s 0 ${ROOTFS}/var/log/ubuntu-advantage.log
truncate -s 0 ${ROOTFS}/var/log/wtmp

chroot ${ROOTFS} rm -rf /var/log/apt/*
chroot ${ROOTFS} rm -rf /var/log/bootstrap.log
