#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Windows 10 QEMU Runtime
# ============================================================

: "${VM_RAM:=4G}"
: "${VM_CPUS:=2}"

: "${VM_DISK:=/data/windows10.qcow2}"

: "${RDP_PORT:=3389}"

: "${DISK_IF:=ide}"
: "${NET_MODEL:=e1000}"

log() {
    printf '[windows10vm-runtime] %s\n' "$*"
}

die() {
    printf '[windows10vm-runtime] ERROR: %s\n' "$*" >&2
    exit 1
}

# ------------------------------------------------------------
# Validate disk
# ------------------------------------------------------------

[[ -f "$VM_DISK" ]] || die \
    "Windows disk not found: $VM_DISK"

# ------------------------------------------------------------
# Detect KVM / TCG
# ------------------------------------------------------------

if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then

    ACCEL_ARGS=(
        "-enable-kvm"
        "-cpu"
        "host"
    )

    log "KVM detected."
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
# Storage
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
# Network
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
# Prepare runtime directory
# ------------------------------------------------------------

mkdir -p /run/qemu /var/log/qemu

rm -f /run/qemu/windows.pid

log "Starting Windows 10..."
log "RAM: ${VM_RAM}"
log "vCPU: ${VM_CPUS}"
log "Disk: ${VM_DISK}"
log "Disk interface: ${DISK_IF}"
log "Network: ${NET_MODEL}"
log "RDP port: ${RDP_PORT}"

# ------------------------------------------------------------
# Start QEMU
# ------------------------------------------------------------

qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" \
    -machine q35 \
    -smp "${VM_CPUS}" \
    -m "${VM_RAM}" \
    "${DISK_ARGS[@]}" \
    -device "${NETWORK_DEVICE},netdev=net0" \
    -netdev "user,id=net0,hostfwd=tcp::${RDP_PORT}-:3389" \
    -boot order=c \
    -vga std \
    -display none \
    -monitor none \
    -serial none \
    -daemonize \
    -pidfile /run/qemu/windows.pid \
    -D /var/log/qemu/windows.log

# ------------------------------------------------------------
# Verify QEMU started
# ------------------------------------------------------------

sleep 3

if [[ ! -f /run/qemu/windows.pid ]]; then
    die "QEMU did not create its PID file."
fi

QEMU_PID="$(cat /run/qemu/windows.pid)"

if ! kill -0 "$QEMU_PID" 2>/dev/null; then

    log "QEMU exited during startup."

    if [[ -f /var/log/qemu/windows.log ]]; then
        tail -100 /var/log/qemu/windows.log >&2
    fi

    exit 1
fi

log "Windows VM started successfully."
log "QEMU PID: ${QEMU_PID}"
log "RDP public/container port: ${RDP_PORT}"
log "Acceleration: ${VM_ACCEL:-auto}"

# ------------------------------------------------------------
# Keep container alive while QEMU runs
# ------------------------------------------------------------

while kill -0 "$QEMU_PID" 2>/dev/null; do
    sleep 5
done

log "QEMU process stopped."

if [[ -f /var/log/qemu/windows.log ]]; then
    tail -100 /var/log/qemu/windows.log || true
fi

exit 1