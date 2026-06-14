#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 /dev/sdX"
    exit 1
fi

DEVICE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BOOT_DIR="${SCRIPT_DIR}/boot"
ALPINE_DIR="${SCRIPT_DIR}/alpine-files"
UBOOT_DIR="${SCRIPT_DIR}/install/u-boot"

BOOT_MNT="/mnt/pinere_boot"
ROOT_MNT="/mnt/pinere_root"

umount ${DEVICE}?* 2>/dev/null || true

parted -s "$DEVICE" mklabel msdos
parted -s "$DEVICE" mkpart primary fat32 32MiB 512MiB
parted -s "$DEVICE" set 1 boot on
parted -s "$DEVICE" mkpart primary ext4 512MiB 100%

partprobe "$DEVICE"
sleep 3

if [[ "$DEVICE" == *mmcblk* ]]; then P="p"; else P=""; fi

BOOT_PART="${DEVICE}${P}1"
ROOT_PART="${DEVICE}${P}2"

mkfs.vfat -F32 -n BOOT "$BOOT_PART"
mkfs.ext4 -F -L ROOT "$ROOT_PART"

dd if="${UBOOT_DIR}/idbloader.img" of="$DEVICE" seek=64 conv=fsync,notrunc
dd if="${UBOOT_DIR}/u-boot.itb" of="$DEVICE" seek=16384 conv=fsync,notrunc

mkdir -p "$BOOT_MNT" "$ROOT_MNT"

mount "$BOOT_PART" "$BOOT_MNT"
mount "$ROOT_PART" "$ROOT_MNT"

tar -xpf "${ALPINE_DIR}/alpine-minirootfs-3.23.4-aarch64.tar.gz" -C "$ROOT_MNT"

cp "${BOOT_DIR}/Image" "$BOOT_MNT/"
cp "${BOOT_DIR}/rk3326-r36ultra-linux.dtb" "$BOOT_MNT/"

mkdir -p "$BOOT_MNT/extlinux"
cp "${BOOT_DIR}/extlinux/extlinux.conf" "$BOOT_MNT/extlinux/"

echo pinere > "$ROOT_MNT/etc/hostname"

sync

umount "$BOOT_MNT"
umount "$ROOT_MNT"

echo "Build complete."
