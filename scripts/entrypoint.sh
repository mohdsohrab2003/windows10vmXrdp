#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Windows 10 VM - Railway / KVM compatible entrypoint
# ============================================================

: "${VM_RAM:=4G}"
: "${VM_CPUS:=2}"
: "${DISK_SIZE:=40G}"

: "${VM_DISK:=/data/windows10.qcow2}"
: "${WINDOWS_ISO:=/iso/Win10.iso}"

: "${FORCE_INSTALL:=0}"
: "${SKIP_INSTALL:=0}"

: "${RDP_PORT:=3389}"
: "${NOVNC_PORT:=6080}"

# Storage/network defaults.
#
# IDE + e1000 are intentionally used as the compatibility defaults
# because a fresh Windows 10 installer may not contain VirtIO drivers.
#
# Once VirtIO drivers are installed inside Windows, you can use:
#
# DISK_IF=virtio
# NET_MODEL=virtio-net-pci
#
: "${DISK_IF:=ide}"
: "${NET_MODEL:=e1000}"

log() {
    printf '[windows10vm] %s\n' "$*"
}

die() {
    printf '[windows10vm] ERROR: %s\n' "$*" >&2
    exit 1
}

# ------------------------------------------------------------
# Validate required programs
# ------------------------------------------------------------

command -v qemu-system-x86_64 >/dev/null 2>&1 || \
    die "qemu-system-x86_64 is not installed."

command -v qemu-img >/dev/null 2>&1 || \
    die "qemu-img is not installed."

# ------------------------------------------------------------
# Detect virtualization mode
# ------------------------------------------------------------

if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    VM_ACCEL="kvm"
    VM_CPU="host"

    log "KVM detected."
    log "Acceleration: KVM"
    log "CPU model: host"
else
    VM_ACCEL="tcg"
    VM_CPU="max"

    log "KVM unavailable (/dev/kvm missing)."
    log "Using QEMU TCG software emulation."
    log "CPU model: max"
fi

export VM_ACCEL
export VM_CPU

# ------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------

mkdir -p \
    /data \
    /iso \
    /run/qemu \
    /var/log/qemu

# ------------------------------------------------------------
# Create persistent Windows disk
# ------------------------------------------------------------

if [[ ! -f "$VM_DISK" ]]; then
    log "Windows disk does not exist."
    log "Creating $DISK_SIZE disk:"
    log "$VM_DISK"

    qemu-img create \
        -f qcow2 \
        "$VM_DISK" \
        "$DISK_SIZE"

    log "Windows disk created."
else
    log "Using existing Windows disk:"
    log "$VM_DISK"

    qemu-img info "$VM_DISK" || true
fi

# ------------------------------------------------------------
# Force installation
# ------------------------------------------------------------

if [[ "$FORCE_INSTALL" == "1" ]]; then

    [[ -f "$WINDOWS_ISO" ]] || die \
        "Windows ISO not found: $WINDOWS_ISO"

    log "FORCE_INSTALL=1"
    log "Starting Windows installation mode."

    exec /usr/local/bin/qemu-install.sh
fi

# ------------------------------------------------------------
# Existing Windows installation
# ------------------------------------------------------------

if [[ "$SKIP_INSTALL" == "1" ]]; then

    log "SKIP_INSTALL=1"
    log "Starting existing Windows disk."

    exec /usr/local/bin/qemu-runtime.sh
fi

# ------------------------------------------------------------
# First boot
# ------------------------------------------------------------

if [[ ! -f /data/.windows-installed ]]; then

    [[ -f "$WINDOWS_ISO" ]] || die \
        "Windows installation ISO not found at:"
    log "$WINDOWS_ISO"

    log "No /data/.windows-installed marker found."
    log "Starting Windows installation."

    exec /usr/local/bin/qemu-install.sh
fi

# ------------------------------------------------------------
# Normal Windows runtime
# ------------------------------------------------------------

log "Windows installation marker found."
log "Starting Windows runtime."

exec /usr/local/bin/qemu-runtime.sh