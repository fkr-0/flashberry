#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/common.sh" 2>/dev/null || true

need_archs=()
# If our YAML is present, use it to decide; otherwise require both.
if [[ -f "$ROOT/flashberry.yml" ]]; then
	ARCH="$(yget arch || true 2>/dev/null || true)"
else
	ARCH=""
fi

case "${ARCH,,}" in
arm64 | "") need_archs+=(qemu-aarch64 qemu-arm) ;;
arm | armhf) need_archs+=(qemu-arm) ;;
*) need_archs+=(qemu-aarch64 qemu-arm) ;;
esac

echo ">> Checking binfmt_misc status…"
if [[ ! -f /proc/sys/fs/binfmt_misc/status ]]; then
	echo "binfmt_misc not mounted (no /proc/sys/fs/binfmt_misc)."
	echo "Hint (host): sudo modprobe binfmt_misc && sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc"
	exit 2
fi

if ! grep -q '^enabled$' /proc/sys/fs/binfmt_misc/status; then
	echo "binfmt_misc present but not enabled."
	exit 2
fi

missing=()
badflags=()

echo ">> Required handlers: ${need_archs[*]}"
for h in "${need_archs[@]}"; do
	f="/proc/sys/fs/binfmt_misc/$h"
	if [[ ! -f "$f" ]]; then
		echo "  - $h: MISSING"
		missing+=("$h")
		continue
	fi
	echo "  - $h: found"
	# Expect the 'F' (fix-binary) flag so interpreter path is taken from the runtime rootfs.
	if ! grep -q '^flags: .*F' "$f"; then
		echo "    flags: $(grep '^flags:' "$f" | sed 's/^/    /')"
		echo "    -> Missing 'F' flag (fix-binary). Reinstall recommended."
		badflags+=("$h")
	fi
	grep -E '^(interpreter|flags):' "$f" | sed 's/^/    /'
done

echo ">> Docker smoke test: run an arm64 userland…"
set +e
docker run --rm --platform=linux/arm64 debian:bookworm bash -lc 'uname -m && echo OK'
rc=$?
set -e
if ((rc != 0)); then
	echo "Docker arm64 run failed (rc=$rc). binfmt likely not installed or Docker lacks binfmt access."
fi

echo
if ((${#missing[@]})); then
	echo "Result: missing handlers: ${missing[*]}"
fi
if ((${#badflags[@]})); then
	echo "Result: handlers with suboptimal flags: ${badflags[*]}"
fi
if ((rc != 0 || ${#missing[@]} || ${#badflags[@]})); then
	echo
	echo "Action: run this on the host to (re)install binfmt handlers:"
	echo "  docker run --privileged --rm tonistiigi/binfmt --install all"
	exit 1
fi

echo "All good: binfmt_misc enabled, handlers OK, Docker arm64 run works."
