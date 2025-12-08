#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

# Drop into an interactive shell inside the configured rootfs.  This is
# useful to inspect the filesystem or run commands before assembling
# the final disk image.  When you exit the shell, mounts are
# unmounted automatically.

RFSDIR="$TMP/rootfs"

if [[ ! -d "$RFSDIR" || ! -f "$RFSDIR/bin/bash" ]]; then
  echo "Rootfs not found. Run make configure first." >&2
  exit 1
fi

log "Entering chroot shell (exit with Ctrl+D)…"

# Bind mount pseudo filesystems for chroot
mount --bind /dev "$RFSDIR/dev"
mount --bind /sys "$RFSDIR/sys"
mount --bind /proc "$RFSDIR/proc"

# Use bash as default shell.  qemu-user-static has been copied into
# /usr/bin by mmdebstrap step.
chroot "$RFSDIR" /bin/bash

# Unmount on exit
umount -lf "$RFSDIR/proc" || true
umount -lf "$RFSDIR/sys" || true
umount -lf "$RFSDIR/dev" || true

log "Exited chroot shell."