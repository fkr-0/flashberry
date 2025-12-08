#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

CFG="${1:-$ROOT/flashberry.yml}"

ARCH="$(yget arch || true)"
ARCH="${ARCH:-arm64}"
SUITE="$(yget suite || true)"
SUITE="${SUITE:-bookworm}"
MIRROR="$(yget mirror || true)"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"

# NEW: read components, default to all that matter for Pi
COMPONENTS="$(
  python3 - <<'PY'
import yaml,sys
cfg=yaml.safe_load(open("flashberry.yml"))
comps=cfg.get("components",["main","contrib","non-free","non-free-firmware"])
print(",".join(comps))
PY
)"

RFSDIR="$TMP/rootfs"
mkdir -p "$RFSDIR"

log "Bootstrapping rootfs: arch=$ARCH suite=$SUITE mirror=$MIRROR components=$COMPONENTS"

# Clean up any previous rootfs
rm -rf "${RFSDIR:?}/"*

mmdebstrap \
  --verbose \
  --architectures="$ARCH" \
  --components="$COMPONENTS" \
  --include="ca-certificates,systemd-sysv,openssh-server,raspi-firmware,firmware-brcm80211,wireless-regdb,gpg,locales,tzdata" \
  "$SUITE" "$RFSDIR" "$MIRROR"

# QEMU static for foreign-arch chroot
case "$ARCH" in
arm64) cp /usr/bin/qemu-aarch64-static "$RFSDIR/usr/bin/" ;;
armhf | arm) cp /usr/bin/qemu-arm-static "$RFSDIR/usr/bin/" ;;
esac

log "Rootfs bootstrap complete -> $RFSDIR"
