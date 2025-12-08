#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

log "Ensuring binfmt is available for qemu-user-static…"

# Attempt to enable binfmt handlers inside the container.  The host
# should also have binfmt handlers installed via tonistiigi/binfmt.
if command -v update-binfmts >/dev/null 2>&1; then
  update-binfmts --enable || true
fi

log "binfmt ready (inside container)."