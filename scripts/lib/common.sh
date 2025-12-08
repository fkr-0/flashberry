#!/usr/bin/env bash
set -euo pipefail

# Common variables and helper functions for Flashberry scripts.

# Determine project root relative to this script
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/out"
TMP="$ROOT/tmp"
LOG="$OUT/flashberry.log"

mkdir -p "$OUT" "$TMP"
touch "$LOG"

##
# yget key
#
# Fetch a simple key from flashberry.yml.  This helper uses python
# because POSIX shells lack a YAML parser.  For complex values
# (lists/dicts), yget prints nothing.  Keys are dot‑separated to
# traverse nested structures.
yget() {
  local key="$1"
  python3 - "$ROOT/flashberry.yml" "$key" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    cfg=yaml.safe_load(f)
keys=sys.argv[2].split('.')
x=cfg
for k in keys:
    if x is None: break
    x=x.get(k)
if isinstance(x,(list,dict)):
    print()
elif x is None:
    print()
else:
    print(x)
PY
}

# Log a message with timestamp to both stdout and the build log.
log() {
  echo "[$(date +'%F %T')] $*" | tee -a "$LOG"
}