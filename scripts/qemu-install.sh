#!/usr/bin/env bash
set -Eeuo pipefail

: "${VM_RAM:=8G}"
: "${VM_CPUS:=4}"
: "${VM_DISK:=/data/windows10.qcow2}"
: "${WINDOWS_ISO:=/iso/Win10.iso}"
: "${NOVNC_PORT:=6080}"

exec qemu-system-x86_64 \
  -enable-kvm \
  -machine q35,accel=kvm \
  -cpu host \
  -smp "${VM_CPUS}" \
  -m "${VM_RAM}" \
  -drive "file=${VM_DISK},if=virtio,format=qcow2,cache=none,aio=native" \
  -drive "file=${WINDOWS_ISO},media=cdrom,readonly=on" \
  -boot order=d,menu=on \
  -device virtio-net-pci,netdev=net0 \
  -netdev "user,id=net0,hostfwd=tcp::3389-:3389" \
  -vga virtio \
  -display vnc=:0 \
  -monitor none \
  -serial none
