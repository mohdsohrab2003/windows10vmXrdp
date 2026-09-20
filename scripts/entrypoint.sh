#!/usr/bin/env bash
set -Eeuo pipefail

: "${VM_RAM:=4G}"
: "${VM_CPUS:=2}"
: "${DISK_SIZE:=40G}"
: "${VM_DISK:=/data/windows10.qcow2}"
: "${WINDOWS_ISO:=/data/Win10.iso}"
: "${FORCE_INSTALL:=0}"
: "${SKIP_INSTALL:=0}"
: "${RDP_PORT:=3389}"
: "${NOVNC_PORT:=6080}"
: "${DISK_IF:=ide}"
: "${NET_MODEL:=e1000}"

log() {
    printf '[windows10vm] %s\n' "$*"
}

die() {
    printf '[windows10vm] ERROR: %s\n' "$*" >&2
    exit 1
}

mkdir -p /data /iso /run/qemu /var/log/qemu

# --------------------------------------------------
# Detect acceleration
# --------------------------------------------------

if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    export VM_ACCEL="kvm"
    export VM_CPU="host"

    log "KVM available."
else
    export VM_ACCEL="tcg"
    export VM_CPU="max"

    log "KVM unavailable (/dev/kvm missing)."
    log "Using QEMU TCG software emulation."
fi

log "CPU model: ${VM_CPU}"

# --------------------------------------------------
# Create Windows disk
# --------------------------------------------------

if [[ ! -f "$VM_DISK" ]]; then

    log "Creating ${DISK_SIZE} Windows disk:"
    log "$VM_DISK"

    qemu-img create \
        -f qcow2 \
        "$VM_DISK" \
        "$DISK_SIZE"

    log "Windows disk created."

else

    log "Using existing Windows disk:"
    log "$VM_DISK"

fi

# --------------------------------------------------
# Check Windows ISO
# --------------------------------------------------

if [[ ! -f "$WINDOWS_ISO" ]]; then

    log "Windows ISO not found:"
    log "$WINDOWS_ISO"

    log "Download the Windows 10 ISO and place it at:"
    log "$WINDOWS_ISO"

    exit 1
fi

log "Windows ISO found:"
log "$WINDOWS_ISO"

# --------------------------------------------------
# Installation mode
# --------------------------------------------------

if [[ "$FORCE_INSTALL" == "1" ]]; then

    log "Starting Windows installation."

    exec /usr/local/bin/qemu-install.sh

fi

# --------------------------------------------------
# First boot installation
# --------------------------------------------------

if [[ "$SKIP_INSTALL" != "1" && ! -f /data/.windows-installed ]]; then

    log "Windows installation has not completed."

    exec /usr/local/bin/qemu-install.sh

fi

# --------------------------------------------------
# Normal Windows boot
# --------------------------------------------------

exec /usr/local/bin/qemu-runtime.sh