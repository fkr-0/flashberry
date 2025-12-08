SHELL := /usr/bin/env bash
CFG   := flashberry.yml

.PHONY: all prepare rootfs configure image compress flash clean distclean shell

## Build the full image and compress it
all: image compress

## Prepare the environment (enable binfmt inside the assembler)
prepare:
	docker compose run --rm assembler bash scripts/10-prepare-binfmt.sh

## Bootstrap the root filesystem using mmdebstrap
rootfs:
	docker compose run --rm assembler bash scripts/20-mmdebstrap-rootfs.sh $(CFG)

## Configure the rootfs in a qemu-driven chroot
configure:
	docker compose run --rm assembler bash scripts/30-chroot-configure.sh $(CFG)

## Optional: drop into an interactive shell inside the configured rootfs
shell:
	docker compose run --rm assembler bash scripts/35-chroot-shell.sh $(CFG)

## Assemble the bootable image
image:
	docker compose run --rm assembler bash scripts/40-make-image.sh $(CFG)

## Compress the image and generate a checksum
compress:
	@if ls -1 out/*.img >/dev/null 2>&1; then \
		for f in out/*.img; do \
			zstd -19 -T0 -f "$$f" -o "$$f.zst"; \
			sha256sum "$$f.zst" > "$$f.zst.sha256"; \
		done; \
	else \
		echo "No .img files found in out/. Run make image first."; \
		exit 1; \
	fi

## Flash the compressed image to an SD card (use DEV=/dev/sdX)
flash:
	@if [ -z "$(DEV)" ]; then echo "Set DEV=/dev/sdX (the SD card device)"; exit 1; fi
	docker compose run --rm -e DEV=$(DEV) flasher bash scripts/50-flash.sh

## Clean temporary directories
clean:
	rm -rf tmp/rootfs tmp/mnt-* || true

## Remove build artifacts (including images)
distclean: clean
	rm -rf out/* || true