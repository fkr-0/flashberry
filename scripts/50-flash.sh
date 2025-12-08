#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

# Flash the latest image onto a block device ($DEV) with progress.

DEV="${DEV:?Set DEV=/dev/sdX (the SD card device)}"
IMG="$(ls -1 out/*.img 2>/dev/null | tail -n1)"

if [[ ! -b "$DEV" ]]; then
  echo "Device $DEV not found or not a block device." >&2
  exit 1
fi

read -r -p "About to write $IMG to $DEV. This will DESTROY contents. Continue? [yes/NO] " yn
[[ "$yn" == "yes" ]]

log "Writing…"
pv "$IMG" | dd of="$DEV" bs=4M conv=fsync status=progress
sync
log "Done."