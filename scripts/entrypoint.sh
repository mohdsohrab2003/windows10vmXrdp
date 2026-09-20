#!/usr/bin/env bash
set -Eeuo pipefail

: "${VM_RAM:=8G}"
: "${VM_CPUS:=4}"
: "${DISK_SIZE:=80G}"
: "${VM_DISK:=/data/windows10.qcow2}"
: "${WINDOWS_ISO:=/iso/Win10.iso}"
: "${FORCE_INSTALL:=0}"
: "${RDP_PORT:=3389}"
: "${NOVNC_PORT:=6080}"

log() { printf '[windows10vm] %s\n' "$*"; }
die() { printf '[windows10vm] ERROR: %s\n' "$*" >&2; exit 1; }

[[ -e /dev/kvm ]] || die \
  "KVM is unavailable (/dev/kvm missing). This VM intentionally does not fall back to slow TCG emulation."

[[ -r /dev/kvm && -w /dev/kvm ]] || die \
  "/dev/kvm exists but is not accessible. Start the container with --device /dev/kvm."

mkdir -p /data /iso /run/qemu /var/log/qemu

if [[ ! -f "$VM_DISK" ]]; then
  log "Creating $DISK_SIZE Windows disk at $VM_DISK"
  qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE"
fi

if [[ "$FORCE_INSTALL" == "1" ]]; then
  [[ -f "$WINDOWS_ISO" ]] || die "Installer ISO not found: $WINDOWS_ISO"
  exec /usr/local/bin/qemu-install.sh
fi

# A marker is created after the first installer boot. If the marker doesn't exist,
# start the installation profile. Set SKIP_INSTALL=1 only if the disk is already
# a fully installed Windows system.
if [[ "${SKIP_INSTALL:-0}" != "1" && ! -f /data/.windows-installed ]]; then
  [[ -f "$WINDOWS_ISO" ]] || die \
    "No installed Windows marker and no ISO at $WINDOWS_ISO. Mount a Windows 10 ISO or set SKIP_INSTALL=1 for an existing disk."
  exec /usr/local/bin/qemu-install.sh
fi

exec /usr/local/bin/qemu-runtime.sh
