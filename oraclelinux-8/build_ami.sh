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

if [ -f /etc/oracle-release ]; then
    dnf --installroot=${ROOTFS} --nogpgcheck -y install oraclelinux-release-el9 yum glibc-langpack-en
else
    dnf --installroot=/rootfs \
      --repofrompath=ol8_baseos_latest,https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/ --repo=ol8_baseos_latest \
      --nogpgcheck --setopt=tsflags=nocontexts -y install oraclelinux-release-el8 yum dnf-plugins-core glibc-langpack-en
fi

chroot ${ROOTFS} dnf config-manager --set-enabled ol8_UEKR7
chroot ${ROOTFS} dnf config-manager --set-disabled ol8_UEKR6

dnf --installroot=${ROOTFS} --nogpgcheck --setopt=tsflags=nocontexts -y groupinstall "Minimal Install" \
  --exclude="iwl*-firmware" \
  --exclude="dracut-config-rescue" \
  --exclude="firewalld" \
  --exclude="glibc-minimal-langpack" \
  --exclude="glibc-all-langpacks"

dnf --installroot=${ROOTFS} --nogpgcheck --setopt=tsflags=nocontexts -y install acpid \
  bind-export-libs \
  checkpolicy \
  chrony \
  cloud-init \
  cloud-utils-growpart \
  dhcp-client \
  dhcp-common \
  dhcp-libs \
  freetype \
  gdisk \
  geolite2-city \
  geolite2-country \
  grub2-efi-x64 \
  grub2-pc \
  grub2-pc-modules \
  grub2-tools-extra \
  ipcalc \
  ipset \
  ipset-libs \
  iptables \
  iptables-ebtables \
  iptables-libs \
  iptables-services \
  kernel-uek-core \
  kernel-uek-modules \
  langpacks-en \
  libevent \
  libibverbs \
  libmaxminddb \
  libnetfilter_conntrack \
  libnfnetlink \
  libnftnl \
  libpcap \
  libpng \
  libsecret \
  libxkbcommon \
  nftables \
  pinentry \
  python3-audit \
  python3-babel \
  python3-chardet \
  python3-configobj \
  python3-decorator \
  python3-firewall \
  python3-idna \
  python3-jinja2 \
  python3-jsonpatch \
  python3-jsonpointer \
  python3-jsonschema \
  python3-jwt \
  python3-libselinux \
  python3-libsemanage \
  python3-markupsafe \
  python3-nftables \
  python3-oauthlib \
  python3-policycoreutils \
  python3-prettytable \
  python3-pyserial \
  python3-pysocks \
  python3-pytz \
  python3-pyyaml \
  python3-requests \
  python3-setools \
  python3-slip \
  python3-slip-dbus \
  python3-unbound \
  python3-urllib3 \
  qemu-guest-agent \
  tmpwatch \
  unbound-libs \
  xkeyboard-config

# Install Amazon SSM Agent
dnf --installroot=${ROOTFS} --nogpgcheck --setopt=tsflags=nocontexts -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

# Enable Xen drivers
cat > ${ROOTFS}/etc/dracut.conf.d/01-dracut-vm.conf << END
add_drivers+=" xen_netfront xen_blkfront "
add_drivers+=" virtio_blk virtio_net virtio_pci virtio_balloon "
add_drivers+=" hyperv_keyboard hv_netvsc hid_hyperv hv_utils hv_storvsc hyperv_fb "
add_drivers+=" ahci libahci "
add_drivers+=" ahci_platform libahci_platform "
END

echo 'add_drivers+=" ena "' > ${ROOTFS}/etc/dracut.conf.d/02-aws-ol-m5.conf
echo 'dracut_rescue_image="no"' > ${ROOTFS}/etc/dracut.conf.d/05-rescue.conf
echo 'add_drivers+=" nvme nvme-core "' > ${ROOTFS}/etc/dracut.conf.d/10-nvme.conf
echo 'force_drivers+=" nfit ena libnvdimm nvme-common nvme-core nvme "' > ${ROOTFS}/etc/dracut.conf.d/15-rhck.conf
chroot ${ROOTFS} dracut -f --regenerate-all

chroot ${ROOTFS} systemctl set-default multi-user.target
chroot ${ROOTFS} systemctl mask tmp.mount

chroot ${ROOTFS} systemctl enable sshd
chroot ${ROOTFS} systemctl enable chronyd
chroot ${ROOTFS} systemctl enable cloud-config
chroot ${ROOTFS} systemctl enable cloud-init
chroot ${ROOTFS} systemctl enable cloud-init-local
chroot ${ROOTFS} systemctl enable cloud-final
chroot ${ROOTFS} systemctl enable amazon-ssm-agent

# fstab
# Need the UUID of our device
EFIUUID=$(blkid -o export ${DEVICE}2 -s UUID | grep ^UUID)
BOOTUUID=$(blkid -o export ${DEVICE}3 -s UUID | grep ^UUID)
ROOTUUID=$(blkid -o export ${DEVICE}4 -s UUID | grep ^UUID)
cat > ${ROOTFS}/etc/fstab << END
${BOOTUUID} /boot                       xfs     defaults        0 0
${EFIUUID} /boot/efi                       vfat     defaults,uid=0,gid=0,umask=077,shortname=winnt        0 2
${ROOTUUID} /                       xfs     defaults        0 0
END

cat > ${ROOTFS}/etc/default/grub << END
GRUB_TIMEOUT=1
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_HIDDEN_MENU_QUIET=false
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_DISABLE_RECOVERY=true
GRUB_ENABLE_BLSCFG=true
GRUB_TERMINAL="serial console"
GRUB_CMDLINE_LINUX="crashkernel=auto LANG=en_US.UTF-8 console=tty0 console=ttyS0,115200n8 rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0 net.ifnames=1 nvme_core.shutdown_timeout=10 nvme_core.io_timeout=4294967295 ipmi_si.tryacpi=0 ipmi_si.trydmi=0 ipmi_si.trydefaults=0 libiscsi.debug_libiscsi_eh=1 loglevel=4"
END

# Configure time settings
cp ${ROOTFS}/usr/share/zoneinfo/UTC ${ROOTFS}/etc/localtime

cat > ${ROOTFS}/etc/cloud/cloud.cfg.d/00_ol-default-user.cfg << END
ssh_pwauth: 0
system_info:
  default_user:
    name: ec2-user
    lock_passwd: true
    gecos: Cloud User
    groups: [adm, systemd-journal]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
  distro: rhel
END

chroot ${ROOTFS} grubby --update-kernel ALL --args="ro crashkernel=auto LANG=en_US.UTF-8 console=tty0 console=ttyS0,115200n8 rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0 net.ifnames=1 nvme_core.shutdown_timeout=10 nvme_core.io_timeout=4294967295 ipmi_si.tryacpi=0 ipmi_si.trydmi=0 ipmi_si.trydefaults=0 libiscsi.debug_libiscsi_eh=1 loglevel=4"
chroot ${ROOTFS} grub2-install --recheck ${DEVICE}
chroot ${ROOTFS} grub2-mkconfig -o /boot/grub2/grub.cfg
chroot ${ROOTFS} chmod 600 /boot/grub2/grub.cfg
