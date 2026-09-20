#!/usr/bin/env bash
set -Eeuo pipefail

: "${VM_RAM:=8G}"
: "${VM_CPUS:=4}"
: "${VM_DISK:=/data/windows10.qcow2}"
: "${RDP_PORT:=3389}"
: "${NOVNC_PORT:=6080}"

# QEMU runs headless. RDP is the normal desktop transport.
# noVNC is started as a secondary emergency console.
qemu-system-x86_64 \
  -enable-kvm \
  -machine q35,accel=kvm \
  -cpu host \
  -smp "${VM_CPUS}" \
  -m "${VM_RAM}" \
  -drive "file=${VM_DISK},if=virtio,format=qcow2,cache=none,aio=native" \
  -device virtio-net-pci,netdev=net0 \
  -netdev "user,id=net0,hostfwd=tcp::${RDP_PORT}-:3389" \
  -boot order=c \
  -display none \
  -monitor none \
  -serial none \
  -daemonize \
  -pidfile /run/qemu/windows.pid \
  -D /var/log/qemu/windows.log

# QEMU VNC server is intentionally not enabled in the fast runtime profile.
# RDP is much lighter for normal Windows desktop use.
log() { printf '[windows10vm] %s\n' "$*"; }

log "Windows VM started with KVM."
log "RDP host port: ${RDP_PORT}"
log "VM RAM: ${VM_RAM}; vCPU: ${VM_CPUS}"

cleanup() {
  if [[ -f /run/qemu/windows.pid ]]; then
    kill "$(cat /run/qemu/windows.pid)" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

while kill -0 "$(cat /run/qemu/windows.pid)" 2>/dev/null; do
  sleep 5
done

exit 1
