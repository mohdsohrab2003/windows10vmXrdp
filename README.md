# Windows 10 VM — KVM/QEMU optimized

This project is a cleaned-up/high-performance version of the `hopingboyz/windows10vm`
pattern.

## Important Railway limitation

A normal Railway **Service** runs as a container and does not expose `/dev/kvm` or
the privileges required by QEMU/KVM. Railway's current public docs/forum material
therefore does not make a Windows 10 KVM VM deployable as an ordinary Railway
service.

This image is designed for a **KVM-capable Linux VM/bare-metal host**. It deliberately
fails fast when KVM is unavailable instead of silently falling back to QEMU TCG,
because TCG is far too slow for a practical Windows 10 RDP desktop.

## Architecture

Linux host
  -> Docker
     -> QEMU/KVM
        -> Windows 10
           -> RDP

The VM disk lives in `/data`, so the container image does not contain the Windows
installation.

## Build

```bash
docker build -t windows10vm-optimized .
```

## First boot / Windows installation

Put your Windows ISO at:

```text
./iso/Win10.iso
```

Then run:

```bash
docker run --rm -it \
  --device /dev/kvm \
  -p 6080:6080 \
  -p 3389:3389 \
  -v "$PWD/data:/data" \
  -v "$PWD/iso:/iso:ro" \
  -e VM_RAM=8G \
  -e VM_CPUS=4 \
  -e DISK_SIZE=80G \
  windows10vm-optimized
```

For the first installation, the container starts QEMU with the installer ISO and
a temporary VNC/noVNC console.

After Windows is installed and RDP is enabled, restart without the installer ISO.
The runtime automatically switches to the fast RDP profile.

## Performance profile

Defaults:

- KVM acceleration required
- `-cpu host`
- Q35 machine
- 4 vCPUs
- 8 GB RAM
- VirtIO block device
- `cache=none`
- `aio=native`
- VirtIO network
- no graphical QEMU window
- RDP for normal use
- no VNC/noVNC in normal runtime

For a smaller machine:

```bash
-e VM_RAM=6G -e VM_CPUS=3
```

For a larger host:

```bash
-e VM_RAM=12G -e VM_CPUS=6
```

## Security

Do not expose RDP directly to the public Internet without a firewall/VPN or an
authenticated TCP gateway. Use a strong Windows password and disable unnecessary
Windows services.

## Files

- `Dockerfile` — minimal QEMU/noVNC runtime
- `scripts/entrypoint.sh` — validation, disk creation, install/runtime selection
- `scripts/qemu-install.sh` — first-boot installer profile
- `scripts/qemu-runtime.sh` — optimized runtime profile
- `docker-compose.yml` — local KVM deployment example
