#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

RFSDIR="$TMP/rootfs"

log "Configuring rootfs in chroot via qemu…"

# Bind mounts for chroot
mount --bind /dev "$RFSDIR/dev"
mount --bind /sys "$RFSDIR/sys"
mount --bind /proc "$RFSDIR/proc"

# --- NEW: ensure locales + tzdata are present and generate the configured locale
LOCALE="$(yget locale || true)"
LOCALE="${LOCALE:-en_US.UTF-8}"

chroot "$RFSDIR" bash -eux <<'CH'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y locales tzdata xz-utils sudo curl
CH

# Add/ensure the right line in /etc/locale.gen (format: "<locale> UTF-8")
# and generate it, then set LANG
chroot "$RFSDIR" bash -eux -c "
  if ! grep -qE '^[[:space:]]*${LOCALE}[[:space:]]+UTF-8' /etc/locale.gen; then
    echo '${LOCALE} UTF-8' >> /etc/locale.gen
  fi
  locale-gen '${LOCALE}'
  update-locale LANG='${LOCALE}'
"

# Now safe to set via systemd-firstboot as well
HOSTNAME="$(yget hostname || true)"
HOSTNAME="${HOSTNAME:-flashpi}"
TZ="$(yget timezone || true)"
TZ="${TZ:-UTC}"

chroot "$RFSDIR" systemd-firstboot \
  --locale="$LOCALE" --timezone="$TZ" --hostname="$HOSTNAME" --root-password=locked

# Create user and set password if provided
USR="$(yget user.name || true)"
USR="${USR:-pi}"
PASS="$(yget user.password || true)"
PASS="${PASS:-disabled}"

chroot "$RFSDIR" useradd -m -s /bin/bash "$USR" || true
if [[ "$PASS" != "disabled" && -n "$PASS" ]]; then
  chroot "$RFSDIR" bash -c "echo '$USR:$PASS' | chpasswd"
fi

# Setup SSH authorized keys if provided
AUTH_KEYS=$(
  python3 - <<'PY'
import yaml, sys, json
cfg=yaml.safe_load(open('flashberry.yml'))
keys=cfg.get('ssh_authorized_keys',[])
print('\n'.join(keys))
PY
)
if [[ -n "$AUTH_KEYS" ]]; then
  mkdir -p "$RFSDIR/home/$USR/.ssh"
  chmod 700 "$RFSDIR/home/$USR/.ssh"
  printf '%s\n' "$AUTH_KEYS" >"$RFSDIR/home/$USR/.ssh/authorized_keys"
  chmod 600 "$RFSDIR/home/$USR/.ssh/authorized_keys"
  chroot "$RFSDIR" chown -R "$USR:$USR" "/home/$USR/.ssh"
fi

# Install additional packages
PKGS=$(
  python3 - <<'PY'
import yaml, sys
cfg=yaml.safe_load(open('flashberry.yml'))
pkgs=cfg.get('packages',[])
print(' '.join(pkgs))
PY
)
if [[ -n "$PKGS" ]]; then
  chroot "$RFSDIR" apt-get update
  chroot "$RFSDIR" apt-get install -y $PKGS
fi

# Enable ssh service
chroot "$RFSDIR" systemctl enable ssh || true

# Optional: expand rootfs on first boot
if [[ "$(yget firstboot_expand_root || true)" == "true" ]]; then
  # ensure growpart exists in the image
  chroot "$RFSDIR" apt-get update
  chroot "$RFSDIR" apt-get install -y cloud-guest-utils
  install -D -m 0644 "$ROOT/overlays/rootfs/etc/systemd/system/firstboot-grow.service" \
    "$RFSDIR/etc/systemd/system/firstboot-grow.service"
  chroot "$RFSDIR" systemctl enable firstboot-grow.service || true
fi

# Wi‑Fi configuration via wpa_supplicant.conf
if [[ -n "$(yget wifi.ssid || true)" ]]; then
  install -D -m 0600 "$ROOT/overlays/rootfs/etc/wpa_supplicant/wpa_supplicant.conf" \
    "$RFSDIR/etc/wpa_supplicant/wpa_supplicant.conf"
fi

# Copy overlay files into the rootfs (boot and rootfs)
rsync -aH --ignore-existing "$ROOT/overlays/rootfs/" "$RFSDIR/" || true

# --- copy in-chroot hooks into the rootfs, run them, then clean up ---
SRC_HOOKS="$ROOT/hooks/in-chroot.d"
DST_HOOKS="$RFSDIR/tmp/flashberry-hooks"
if compgen -G "$SRC_HOOKS/*.sh" >/dev/null; then
  mkdir -p "$DST_HOOKS"
  cp -a "$SRC_HOOKS/"* "$DST_HOOKS/" || true
  chroot "$RFSDIR" bash -eux -c 'chmod +x /tmp/flashberry-hooks/*.sh || true'
  for s in "$DST_HOOKS/"*.sh; do
    [[ -e "$s" ]] || break
    log "Running in-chroot hook: $(basename "$s")"
    chroot "$RFSDIR" bash -eux "/tmp/flashberry-hooks/$(basename "$s")"
  done
  rm -rf "$DST_HOOKS"
fi

# Clean up mounts
umount -lf "$RFSDIR/proc" || true
umount -lf "$RFSDIR/sys" || true
umount -lf "$RFSDIR/dev" || true

log "Chroot configuration complete."
