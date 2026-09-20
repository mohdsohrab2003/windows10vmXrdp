#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Windows 10 QEMU Installation
# ============================================================

: "${VM_RAM:=4G}"
: "${VM_CPUS:=2}"

: "${VM_DISK:=/data/windows10.qcow2}"
: "${WINDOWS_ISO:=/iso/Win10.iso}"

: "${RDP_PORT:=3389}"
: "${NOVNC_PORT:=6080}"

: "${DISK_IF:=ide}"
: "${NET_MODEL:=e1000}"

log() {
    printf '[windows10vm-install] %s\n' "$*"
}

die() {
    printf '[windows10vm-install] ERROR: %s\n' "$*" >&2
    exit 1
}

# ------------------------------------------------------------
# Validate files
# ------------------------------------------------------------

[[ -f "$VM_DISK" ]] || die \
    "Windows disk not found: $VM_DISK"

[[ -f "$WINDOWS_ISO" ]] || die \
    "Windows ISO not found: $WINDOWS_ISO"

# ------------------------------------------------------------
# Detect KVM / TCG
# ------------------------------------------------------------

if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then

    ACCEL_ARGS=(
        "-enable-kvm"
        "-cpu"
        "host"
    )

    log "Using KVM hardware acceleration."

else

    ACCEL_ARGS=(
        "-accel"
        "tcg,thread=multi"
        "-cpu"
        "max"
    )

    log "KVM unavailable."
    log "Using TCG software emulation."

fi

# ------------------------------------------------------------
# Storage configuration
# ------------------------------------------------------------

case "$DISK_IF" in

    virtio)
        DISK_ARGS=(
            "-drive"
            "file=${VM_DISK},if=virtio,format=qcow2,cache=none,aio=threads"
        )
        ;;

    ide|*)
        DISK_ARGS=(
            "-drive"
            "file=${VM_DISK},if=ide,format=qcow2,cache=writeback"
        )
        ;;

esac

# ------------------------------------------------------------
# Network configuration
# ------------------------------------------------------------

case "$NET_MODEL" in

    virtio)
        NETWORK_DEVICE="virtio-net-pci"
        ;;

    e1000|*)
        NETWORK_DEVICE="e1000"
        ;;

esac

# ------------------------------------------------------------
# Remove stale PID
# ------------------------------------------------------------

rm -f /run/qemu/windows.pid

log "Starting Windows installation..."
log "RAM: ${VM_RAM}"
log "vCPU: ${VM_CPUS}"
log "Disk: ${VM_DISK}"
log "Disk interface: ${DISK_IF}"
log "Network: ${NET_MODEL}"

# ------------------------------------------------------------
# QEMU
# ------------------------------------------------------------

exec qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" \
    -machine q35 \
    -smp "${VM_CPUS}" \
    -m "${VM_RAM}" \
    "${DISK_ARGS[@]}" \
    -drive "file=${WINDOWS_ISO},media=cdrom,readonly=on" \
    -boot order=d,menu=on \
    -device "${NETWORK_DEVICE},netdev=net0" \
    -netdev "user,id=net0,hostfwd=tcp::${RDP_PORT}-:3389" \
    -vga std \
    -display vnc=:0 \
    -monitor none \
    -serial none \
    -no-reboot