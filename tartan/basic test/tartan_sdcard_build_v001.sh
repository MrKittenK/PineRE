#!/bin/sh
# PineRE Tartan v0.01 Builder

set -eu

DEVICE="${1:-}"

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 /dev/sdX"
    exit 1
fi

echo "=== PineRE Tartan v0.01 ==="

umount ${DEVICE}?* 2>/dev/null || true

parted -s "$DEVICE" mklabel msdos
parted -s "$DEVICE" mkpart primary fat32 4MiB 260MiB
parted -s "$DEVICE" set 1 boot on
parted -s "$DEVICE" mkpart primary ext4 260MiB 8192MiB
parted -s "$DEVICE" mkpart primary ext4 8192MiB 100%

echo "BOOT ROOT EASYROMS created"

echo "Install Alpine rootfs manually for now"
echo "Install extlinux.conf"
echo "Install pinere-boot-test"
echo "Goal: Boot -> Mode Screen -> Alpine Shell"
