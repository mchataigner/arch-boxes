#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="Arch-Linux-x86_64-cloudimg-${build_version}.qcow2"
DISK_SIZE=""
# The growpart module[1] requires the growpart program, provided by the
# cloud-guest-utils package
# [1] https://cloudinit.readthedocs.io/en/latest/topics/modules.html#growpart
PACKAGES=(cloud-init cloud-guest-utils zsh qemu-guest-agent avahi man emacs-nox prezto-moot prezto-contrib-git)
SERVICES=(cloud-init-main.service cloud-init-local.service cloud-init-network.service cloud-config.service cloud-final.service)

function pre() {
  sed -Ei 's/^(GRUB_CMDLINE_LINUX_DEFAULT=.*)"$/\1 console=tty0 console=ttyS0,115200"/' "${MOUNT}/etc/default/grub"
  echo 'GRUB_TERMINAL="serial console"' >>"${MOUNT}/etc/default/grub"
  echo 'GRUB_SERIAL_COMMAND="serial --speed=115200"' >>"${MOUNT}/etc/default/grub"
  pushd "${MOUNT}"
  mv "etc/pacman.conf" "etc/pacman.conf.orig"
  cat <<EOF > "etc/pacman.conf"
[options]
HoldPkg     = pacman glibc
Architecture = auto
Color
CheckSpace
ParallelDownloads = 10
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[core-testing]
Include = /etc/pacman.d/mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist

[extra-testing]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib-testing]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[moot]
Server = http://3.arch.chataigner.me/moot/os/\$arch
Server = http://4.arch.chataigner.me/moot/os/\$arch
EOF

  cat <<EOF > "etc/pacman.d/mirrorlist"
################################################################################
################# Arch Linux mirrorlist generated by Reflector #################
################################################################################

# With:       reflector --latest 5 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
# When:       2024-07-28 12:15:09 UTC
# From:       https://archlinux.org/mirrors/status/json/
# Retrieved:  2024-07-28 12:14:02 UTC
# Last Check: 2024-07-28 12:01:21 UTC

Server = https://mirror.theo546.fr/archlinux/\$repo/os/\$arch
Server = https://london.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://mirror.ubrco.de/archlinux/\$repo/os/\$arch
Server = https://mirror.moson.org/arch/\$repo/os/\$arch
Server = https://archlinux.c3sl.ufpr.br/\$repo/os/\$arch
EOF

  popd

  arch-chroot "${MOUNT}" /usr/bin/chsh -s /usr/bin/zsh
  arch-chroot "${MOUNT}" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg

  mkdir -p "${MOUNT}/etc/systemd/system/avahi-daemon.service.d"
  cat <<EOF > "${MOUNT}/etc/systemd/system/avahi-daemon.service.d/override.conf"
[Unit]
After=systemd-networkd-wait-online.service
EOF

  arch-chroot "${MOUNT}" /usr/bin/systemctl enable avahi-daemon.service

  cat <<EOF >"${MOUNT}/etc/systemd/system/restart-avahi-after-first-cloud-init.service"
[Unit]
Description=restart avahi-daemon after first cloud init
Requires=cloud-init.target
After=cloud-init.target
ConditionFirstBoot=yes

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart systemd-networkd.service
ExecStart=/usr/bin/systemctl restart avahi-daemon.service
ExecStart=/usr/bin/systemctl disable restart-avahi-after-first-cloud-init.service

[Install]
WantedBy=graphical.target
EOF

  arch-chroot "${MOUNT}" /usr/bin/systemctl enable restart-avahi-after-first-cloud-init.service
}

function post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}
