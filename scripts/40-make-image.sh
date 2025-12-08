#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

# Build a partitioned disk image from the configured rootfs.  This
# script creates a sparse image, partitions it (msdos table with
# boot+root), formats filesystems, populates them and installs
# firmware/config.  The resulting image is placed in out/.

RFSDIR="$TMP/rootfs"
IMG="$OUT/flashberry.img"

SIZE_GB="$(yget image.size_gb || true)"; SIZE_GB="${SIZE_GB:-4}"

log "Creating sparse image (${SIZE_GB}G)…"
truncate -s "${SIZE_GB}G" "$IMG"

log "Partitioning (msdos: 256MiB FAT32 /boot + rest ext4 /)…"
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 1MiB 256MiB
parted -s "$IMG" set 1 boot on
parted -s "$IMG" mkpart primary ext4 256MiB 100%

LOOP="$(losetup --find --show --partscan "$IMG")"
trap 'sync; losetup -d "$LOOP" || true' EXIT

mkfs.vfat -F32 -n BOOT "${LOOP}p1"
mkfs.ext4 -F -L rootfs "${LOOP}p2"

MNT_BOOT="$TMP/mnt-boot"
MNT_ROOT="$TMP/mnt-root"
mkdir -p "$MNT_BOOT" "$MNT_ROOT"

mount "${LOOP}p2" "$MNT_ROOT"
mkdir -p "$MNT_ROOT/boot"
mount "${LOOP}p1" "$MNT_BOOT"

log "Installing rootfs…"
rsync -aH "$RFSDIR/" "$MNT_ROOT/"

log "Installing boot firmware/config…"
install -D -m 0644 "$ROOT/overlays/boot/config.txt" "$MNT_BOOT/config.txt"
install -D -m 0644 "$ROOT/overlays/boot/cmdline.txt" "$MNT_BOOT/cmdline.txt"

# Copy Raspberry Pi firmware files from rootfs if available
if [[ -d "$MNT_ROOT/usr/lib/firmware/raspberrypi/boot" ]]; then
  rsync -aH "$MNT_ROOT/usr/lib/firmware/raspberrypi/boot/" "$MNT_BOOT/"
fi

# Fallback fstab if none was provided via overlay
if [[ ! -f "$MNT_ROOT/etc/fstab" ]]; then
  cat > "$MNT_ROOT/etc/fstab" <<EOF
/dev/mmcblk0p2  /     ext4  defaults,noatime  0 1
/dev/mmcblk0p1  /boot vfat  defaults          0 2
EOF
fi

sync
umount -lf "$MNT_BOOT" "$MNT_ROOT"
trap - EXIT
losetup -d "$LOOP"

log "Image ready -> $IMG"