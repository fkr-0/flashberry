Flashberry
===========

**Flashberry** is a container-based tool for building, configuring and
flashing Raspberry Pi images.  It uses `mmdebstrap` to bootstrap a
minimal Debian or Raspberry Pi OS root filesystem for your target
architecture, configures it inside a qemu‑powered chroot, and finally
assembles a partitioned disk image that can be flashed to an SD card
or booted in an emulator.  All of this happens inside Docker so the
host stays clean and reproducible.

### Key features

* Cross‑architecture bootstrapping using **mmdebstrap** and
  **qemu-user-static**.  You can build arm64 or armhf images on any
  Linux host.
* Overlay‑driven configuration: drop files into
  `overlays/boot` or `overlays/rootfs` and they will be merged into
  the final image.  Shell hooks under `hooks/` let you run arbitrary
  commands at various stages of the build.
* A declarative YAML configuration file (`flashberry.yml`) captures
  architecture, user accounts, packages, Wi‑Fi settings and more.
* Make targets for all the major steps: bootstrap the rootfs,
  configure it, assemble the image, compress it, flash it and even
  drop into an interactive shell inside the configured rootfs.
* Privileged Docker containers are used for tasks that need direct
  access to loop devices or block devices.  A separate “flasher”
  image is used to safely write the resulting image to an SD card.

### Getting started

1. Install Docker on a Linux host and ensure that you can run
   privileged containers.  For cross‑architecture builds you must
   install the binfmt handlers once on the host:

   ```sh
   docker run --privileged --rm tonistiigi/binfmt --install all
   ```

2. Populate `flashberry.yml` with your desired settings.  See
   below for an example.

3. Run the build pipeline using the provided Makefile.  Typical
   targets are:

   * `make prepare` – enable binfmt inside the assembler image.
   * `make rootfs` – bootstrap the root filesystem with mmdebstrap.
   * `make configure` – apply your configuration and install
     packages in a qemu‑chroot.
   * `make shell` – optional: enter a shell inside the configured
     rootfs to inspect or tweak it before image assembly.
   * `make image` – assemble the bootable image with a boot
     partition and root partition.
   * `make compress` – compress the image with `zstd` and emit a
     checksum.
   * `make flash DEV=/dev/sdX` – write the compressed image to an
     SD card (Linux hosts only).

### Example configuration (`flashberry.yml`)

```yaml
# Architecture and base suite
arch: arm64
suite: bookworm
mirror: http://deb.debian.org/debian

# System identity
hostname: flashpi
timezone: Europe/Berlin
locale: en_US.UTF-8

# User and authentication
user:
  name: pi
  password: disabled  # disable password login; use SSH keys only
ssh_authorized_keys:
  - "ssh-ed25519 AAAA... flo@laptop"

# Packages to install inside the chroot
packages:
  - vim
  - htop
  - net-tools
  - openssh-server

# Wi‑Fi configuration (optional)
wifi:
  country: DE
  ssid: "MySSID"
  psk: "supersecret"

# Expand the root filesystem on first boot
firstboot_expand_root: true

# Output image size (GB)
image:
  size_gb: 4
```

### Interactive shell after configuration

Sometimes you want to inspect or further tweak the root filesystem
before assembling the disk image.  Flashberry provides a `make shell`
target for this purpose.  After running `make configure`, simply run

```sh
make shell
```

This mounts the appropriate pseudo‑filesystems, sets up qemu
binfmt, and drops you into a chroot inside the configured rootfs.
Exit the shell (`Ctrl+D`) when you are done.  The subsequent
`make image` will pick up your changes.

### Running the resulting image in QEMU

While Flashberry itself does not run the image, you can boot the
resulting `flashberry.img` in QEMU for testing.  For an arm64 image,
install `qemu-system-aarch64` and run something like:

```sh
qemu-system-aarch64 \
  -M raspi4 \
  -m 2048 \
  -drive file=out/flashberry.img,format=raw,if=sd \
  -serial null -serial stdio \
  -nographic
```

This will boot the image in a virtual Raspberry Pi environment.
Graphics output over HDMI is not enabled in this minimal example; use
appropriate `-display` options if you need a GUI.  Running Raspberry
Pi images inside Docker is generally not feasible because Docker
provides process isolation rather than full hardware emulation.  Use
QEMU or another emulator instead.