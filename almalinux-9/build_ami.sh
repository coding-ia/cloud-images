#!/bin/bash -ex

DEVICE=/dev/xvdb
ROOTFS=/rootfs

dnf install -y gdisk wget dosfstools unzip

sgdisk --zap-all ${DEVICE}
sgdisk -og ${DEVICE}

sgdisk --new=1:0:+1M --typecode=1:EF02 ${DEVICE}
sgdisk --new=2:0:+200M --typecode=2:EF00 --attributes=2:set:2 ${DEVICE}
sgdisk --new=3:0:+600M --typecode=3:EA00 ${DEVICE}
sgdisk --new=4:0:0 --typecode=4:8300 ${DEVICE}

mkfs.vfat -F 32 ${DEVICE}2
mkfs.xfs -L boot ${DEVICE}3 -f
mkfs.xfs -L root ${DEVICE}4 -f

# Mount the rootfs
mkdir -p ${ROOTFS}
mount ${DEVICE}4 ${ROOTFS}

# Create /boot in rootfs and mount device
mkdir -p ${ROOTFS}/boot
mount ${DEVICE}3 ${ROOTFS}/boot

# Create /boot/ef in rootfs/boot and mount device
mkdir -p ${ROOTFS}/boot/efi
mount ${DEVICE}2 ${ROOTFS}/boot/efi

# Setup other mounts
mkdir -p ${ROOTFS}/{dev,proc,sys,sys/fs/selinux}
mount -t proc none ${ROOTFS}/proc
mount --bind /dev ${ROOTFS}/dev
mount -t sysfs sysfs ${ROOTFS}/sys
mount -t selinuxfs selinuxfs ${ROOTFS}/sys/fs/selinux

wget https://repo.almalinux.org/almalinux/almalinux-release-latest-9.x86_64.rpm
wget https://repo.almalinux.org/almalinux/almalinux-repos-latest-9.x86_64.rpm
wget https://repo.almalinux.org/almalinux/almalinux-gpg-keys-latest-9.x86_64.rpm

rpm --root=${ROOTFS} -ivh --nodeps almalinux-gpg-keys-latest-9.x86_64.rpm
rpm --root=${ROOTFS} -ivh --nodeps almalinux-repos-latest-9.x86_64.rpm
rpm --root=${ROOTFS} -ivh almalinux-release-latest-9.x86_64.rpm

dnf --installroot=${ROOTFS} --nogpgcheck -y groupinstall "Minimal Install" \
  --exclude="iwl*-firmware" \
  --exclude="dracut-config-rescue" \
  --exclude="firewalld"

dnf --installroot=${ROOTFS} --nogpgcheck -y install \
  acpid \
  efibootmgr \
  grub2-efi-x64 \
  grub2-pc \
  grub2-tools \
  kernel \
  openssh-server \
  shim-x64 \
  tuned

dnf --installroot=${ROOTFS} --nogpgcheck -y install \
  cloud-init \
  cloud-utils-growpart \
  dracut-config-generic \
  dstat \
  ethtool \
  gdisk \
  lsof \
  net-tools \
  nmap-ncat \
  chrony \
  openssl \
  psmisc \
  strace \
  sysstat \
  tmux \
  unzip \
  yum-utils

# Install Amazon SSM Agent
dnf --installroot=${ROOTFS} --nogpgcheck -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

# Enable Xen drivers
echo 'add_drivers+=" nvme xen-netfront xen-blkfront "' > ${ROOTFS}/etc/dracut.conf.d/02-ec2.conf
chroot ${ROOTFS} dracut -f --regenerate-all

# Fixes for various permissions issues
chmod +x ${ROOTFS}/etc/rc.d/rc.local
chmod 644 ${ROOTFS}/etc/udev/hwdb.bin

chroot ${ROOTFS} systemctl set-default multi-user.target
chroot ${ROOTFS} systemctl mask tmp.mount

chroot ${ROOTFS} systemctl enable sshd
chroot ${ROOTFS} systemctl enable chronyd
chroot ${ROOTFS} systemctl enable cloud-config
chroot ${ROOTFS} systemctl enable cloud-init
chroot ${ROOTFS} systemctl enable cloud-init-local
chroot ${ROOTFS} systemctl enable cloud-final
chroot ${ROOTFS} systemctl enable amazon-ssm-agent

# Disable virtual terminals allocation by logind
sed -i 's/^#NAutoVTs=.*/NAutoVTs=0/' ${ROOTFS}/etc/systemd/logind.conf

# Enable sgdisk in dracut
echo 'install_items+=" sgdisk "' > ${ROOTFS}/etc/dracut.conf.d/sgdisk.conf

# Disable dracut rescue kernels
echo 'dracut_rescue_image="no"' > ${ROOTFS}/etc/dracut.conf.d/02-rescue.conf

# Create homedir for root
cp -a /etc/skel/.bash* ${ROOTFS}/root

echo 'RUN_FIRSTBOOT=NO' > ${ROOTFS}/etc/sysconfig/firstboot

# fstab
# Need the UUID of our device
EFIUUID=$(blkid -o export ${DEVICE}2 -s UUID | grep ^UUID)
BOOTUUID=$(blkid -o export ${DEVICE}3 -s UUID | grep ^UUID)
ROOTUUID=$(blkid -o export ${DEVICE}4 -s UUID | grep ^UUID)
cat > ${ROOTFS}/etc/fstab << END
${ROOTUUID}     /               xfs       defaults                        0 0
${BOOTUUID}     /boot           xfs       defaults                        0 0
${EFIUUID}      /boot/efi       vfat    defaults,uid=0,gid=0,umask=077,shortname=winnt  0       2
END

cat > ${ROOTFS}/etc/default/grub << END
GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0 net.ifnames=0 rd.blacklist=nouveau nvme_core.io_timeout=4294967295"
GRUB_TIMEOUT=0
GRUB_ENABLE_BLSCFG=true
GRUB_DEFAULT=saved
END

cat > ${ROOTFS}/etc/sysconfig/kernel << END
DEFAULTKERNEL=kernel
UPDATEDEFAULT=yes
END

# Configure networking
touch ${ROOTFS}/etc/resolv.conf

# Configure time settings
cp /usr/share/zoneinfo/UTC ${ROOTFS}/etc/localtime

cat > ${ROOTFS}/etc/cloud/cloud.cfg.d/00-alma-default-user.cfg << END
system_info:
  default_user:
    name: ec2-user
END

chroot ${ROOTFS} grub2-mkconfig -o /boot/grub2/grub.cfg
chroot ${ROOTFS} grub2-install --recheck ${DEVICE}

chroot ${ROOTFS} /sbin/fixfiles -f -F relabel

truncate -s 0 ${ROOTFS}/etc/machine-id
truncate -s 0 ${ROOTFS}/etc/hostname

rm -f ${ROOTFS}/var/lib/systemd/random-seed
