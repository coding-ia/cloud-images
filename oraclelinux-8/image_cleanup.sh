#!/bin/bash -ex

ROOTFS=/rootfs

chroot ${ROOTFS} /sbin/fixfiles -f -F relabel
dnf -y --installroot=${ROOTFS} --nogpgcheck clean all
chroot ${ROOTFS} rm -rf /var/cache/dnf
chroot ${ROOTFS} rm -rf /var/lib/dnf/history*

truncate -s 0 ${ROOTFS}/etc/machine-id
truncate -s 0 ${ROOTFS}/etc/hostname
truncate -s 0 ${ROOTFS}/etc/resolv.conf
truncate -s 0 ${ROOTFS}/var/log/audit/audit.log
truncate -s 0 ${ROOTFS}/var/log/wtmp
truncate -s 0 ${ROOTFS}/var/log/lastlog
truncate -s 0 ${ROOTFS}/var/log/btmp
truncate -s 0 ${ROOTFS}/var/log/cron
truncate -s 0 ${ROOTFS}/var/log/maillog
truncate -s 0 ${ROOTFS}/var/log/messages
truncate -s 0 ${ROOTFS}/var/log/secure
truncate -s 0 ${ROOTFS}/var/log/spooler

chroot ${ROOTFS} rm -rf /var/log/anaconda
chroot ${ROOTFS} rm -rf /var/log/tuned
chroot ${ROOTFS} rm -rf /var/lib/cloud

rm -f ${ROOTFS}/etc/ssh/ssh_host_*
rm -f ${ROOTFS}/var/lib/systemd/random-seed

