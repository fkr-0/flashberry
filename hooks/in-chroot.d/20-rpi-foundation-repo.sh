#!/usr/bin/env bash
set -eux

# Add Raspberry Pi Foundation apt repo (pinned lower than Debian)
. /etc/os-release
echo "deb [signed-by=/usr/share/keyrings/rpi.gpg] http://archive.raspberrypi.org/debian/ ${VERSION_CODENAME} main" \
  >/etc/apt/sources.list.d/raspi.list

curl -fsSL https://archive.raspberrypi.org/debian/raspberrypi.gpg.key |
  gpg --dearmor -o /usr/share/keyrings/rpi.gpg

cat >/etc/apt/preferences.d/raspi-pin <<'PREF'
Package: *
Pin: origin archive.raspberrypi.org
Pin-Priority: 100
PREF

apt-get update
# Example: tools commonly desired
# apt-get install -y raspi-config rpi-eeprom pi-bluetooth
# == end/hooks/in-chroot.d/20-rpi-foundation-repo.sh ==
