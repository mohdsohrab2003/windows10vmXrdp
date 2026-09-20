#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Windows 10 QEMU Installation Script
# KVM + TCG compatible
# noVNC installer console
# ============================================================

: "${VM_RAM:=4G}"
: "${VM_CPUS:=2}"

: "${VM_DISK:=/data/windows10.qcow2}"
: "${WINDOWS_ISO:=/data/Win10.iso}"

: "${RDP_PORT:=3389}"
: "${NOVNC_PORT:=6080}"
: "${VNC_PORT:=5900}"

: "${DISK_IF:=ide}"
: "${NET_MODEL:=e1000}"

VNC_DISPLAY=":0"

log() {
    printf '[windows10vm-install] %s\n' "$*"
}

die() {
    printf '[windows10vm-install] ERROR: %s\n' "$*" >&2
    exit 1
}

# ============================================================
# Directories
# ============================================================

mkdir -p \
    /data \
    /run/qemu \
    /var/log/qemu

# ============================================================
# Validate required files
# ============================================================

if [[ ! -f "$VM_DISK" ]]; then
    die "Windows disk not found: $VM_DISK"
fi

if [[ ! -f "$WINDOWS_ISO" ]]; then
    die "Windows ISO not found: $WINDOWS_ISO"
fi

# ============================================================
# Validate ISO
# ============================================================

ISO_SIZE=$(stat -c%s "$WINDOWS_ISO" 2>/dev/null || echo 0)

if [[ "$ISO_SIZE" -lt 100000000 ]]; then
    die "Windows ISO appears invalid or incomplete. Size: ${ISO_SIZE} bytes"
fi

log "Windows ISO:"
log "  $WINDOWS_ISO"

log "ISO size:"
log "  $ISO_SIZE bytes"

# ============================================================
# Detect KVM
# ============================================================

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

    log "KVM unavailable (/dev/kvm missing)."
    log "Using QEMU TCG software emulation."

fi

# ============================================================
# Storage
# ============================================================

case "$DISK_IF" in

    virtio)

        DISK_ARGS=(
            "-drive"
            "file=${VM_DISK},if=virtio,format=qcow2,cache=none,aio=threads"
        )

        log "Disk interface: VirtIO"
        ;;

    ide|*)

        DISK_ARGS=(
            "-drive"
            "file=${VM_DISK},if=ide,format=qcow2,cache=writeback"
        )

        log "Disk interface: IDE"
        ;;

esac

# ============================================================
# Network
# ============================================================

case "$NET_MODEL" in

    virtio)

        NETWORK_DEVICE="virtio-net-pci"

        log "Network model: VirtIO"
        ;;

    e1000|*)

        NETWORK_DEVICE="e1000"

        log "Network model: Intel E1000"
        ;;

esac

# ============================================================
# Clean previous QEMU / noVNC processes
# ============================================================

if [[ -f /run/qemu/windows-install.pid ]]; then

    OLD_PID="$(cat /run/qemu/windows-install.pid 2>/dev/null || true)"

    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        log "Stopping previous QEMU process: $OLD_PID"
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
    fi

fi

rm -f /run/qemu/windows-install.pid

# ============================================================
# Start QEMU installer
# ============================================================

log "============================================================"
log "Starting Windows 10 installer"
log "============================================================"

log "RAM: ${VM_RAM}"
log "vCPU: ${VM_CPUS}"
log "Disk: ${VM_DISK}"
log "ISO: ${WINDOWS_ISO}"
log "VNC: ${VNC_PORT}"
log "noVNC: ${NOVNC_PORT}"
log "RDP forwarding: ${RDP_PORT} -> Windows:3389"

rm -f /var/log/qemu/windows-install.log

qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" \
    -machine q35 \
    -smp "${VM_CPUS}" \
    -m "${VM_RAM}" \
    "${DISK_ARGS[@]}" \
    -drive "file=${WINDOWS_ISO},media=cdrom,readonly=on,format=raw" \
    -boot order=d,menu=on \
    -device "${NETWORK_DEVICE},netdev=net0" \
    -netdev "user,id=net0,hostfwd=tcp::${RDP_PORT}-:3389" \
    -vga std \
    -display "${VNC_DISPLAY}" \
    -monitor none \
    -serial none \
    -pidfile /run/qemu/windows-install.pid \
    -D /var/log/qemu/windows-install.log \
    -no-reboot \
    > /var/log/qemu/windows-install-console.log 2>&1 &

QEMU_PID=$!

log "QEMU process started."
log "QEMU PID: ${QEMU_PID}"

# ============================================================
# Wait for QEMU startup
# ============================================================

sleep 5

if ! kill -0 "$QEMU_PID" 2>/dev/null; then

    log "QEMU failed to start."

    if [[ -f /var/log/qemu/windows-install.log ]]; then
        log "QEMU log:"
        tail -100 /var/log/qemu/windows-install.log >&2 || true
    fi

    if [[ -f /var/log/qemu/windows-install-console.log ]]; then
        log "QEMU console:"
        tail -100 /var/log/qemu/windows-install-console.log >&2 || true
    fi

    exit 1

fi

log "QEMU is running."

# ============================================================
# Start noVNC / Websockify
# ============================================================

log "Starting noVNC..."

NOVNC_WEB="/usr/share/novnc"

if [[ ! -d "$NOVNC_WEB" ]]; then
    die "noVNC directory not found: $NOVNC_WEB"
fi

# Find websockify executable
WEBSOCKIFY_BIN=""

if command -v websockify >/dev/null 2>&1; then
    WEBSOCKIFY_BIN="$(command -v websockify)"
elif [[ -x /usr/bin/websockify ]]; then
    WEBSOCKIFY_BIN="/usr/bin/websockify"
elif [[ -x /usr/bin/websockifyd ]]; then
    WEBSOCKIFY_BIN="/usr/bin/websockifyd"
fi

if [[ -z "$WEBSOCKIFY_BIN" ]]; then
    die "websockify executable not found."
fi

log "Websockify:"
log "  $WEBSOCKIFY_BIN"

# ============================================================
# Start Websockify
# ============================================================

rm -f /run/qemu/websockify.pid

"$WEBSOCKIFY_BIN" \
    --web "$NOVNC_WEB" \
    "$NOVNC_PORT" \
    "127.0.0.1:${VNC_PORT}" \
    > /var/log/qemu/websockify.log 2>&1 &

WEBSOCKIFY_PID=$!

echo "$WEBSOCKIFY_PID" > /run/qemu/websockify.pid

sleep 3

if ! kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then

    log "WARNING: websockify failed to start."

    if [[ -f /var/log/qemu/websockify.log ]]; then
        tail -100 /var/log/qemu/websockify.log >&2 || true
    fi

else

    log "noVNC started successfully."
    log "noVNC port: ${NOVNC_PORT}"

fi

# ============================================================
# Installation information
# ============================================================

log "============================================================"
log "WINDOWS INSTALLER READY"
log "============================================================"

log "Browser console:"
log "http://<RAILWAY-DOMAIN>:${NOVNC_PORT}/vnc.html"

log ""
log "VNC:"
log "127.0.0.1:${VNC_PORT}"

log ""
log "RDP forwarding:"
log "Container ${RDP_PORT} -> Windows 3389"

log ""
log "Install Windows using the noVNC console."
log "============================================================"

# ============================================================
# Keep container alive
# ============================================================

while true; do

    # QEMU stopped
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then

        log "QEMU installer stopped."

        if [[ -f /var/log/qemu/windows-install.log ]]; then

            log "Last QEMU log entries:"

            tail -50 \
                /var/log/qemu/windows-install.log \
                || true

        fi

        break
    fi

    # Restart websockify if it dies
    if ! kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then

        log "Websockify stopped. Restarting..."

        "$WEBSOCKIFY_BIN" \
            --web "$NOVNC_WEB" \
            "$NOVNC_PORT" \
            "127.0.0.1:${VNC_PORT}" \
            > /var/log/qemu/websockify.log 2>&1 &

        WEBSOCKIFY_PID=$!

        echo "$WEBSOCKIFY_PID" > /run/qemu/websockify.pid

    fi

    sleep 5

done

# ============================================================
# Cleanup
# ============================================================

log "Cleaning up..."

if [[ -n "${WEBSOCKIFY_PID:-}" ]] \
   && kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then

    kill "$WEBSOCKIFY_PID" 2>/dev/null || true

fi

rm -f /run/qemu/windows-install.pid
rm -f /run/qemu/websockify.pid

log "Windows installation process ended."

exit 1