#!/bin/bash
set -euo pipefail

# --- FUNCTIONS ---
log_info()  { echo "[INFO] $*"; }
confirm()   { [[ "${SELECTED_PHASES:-}" == *"$1"* ]]; }

cleanup_mounts() {
    log_info "Forcing release of all mount points on $TARGET_DEV..."
    lsblk -n -o MOUNTPOINT "$TARGET_DEV" | grep -v '^$' | while read -r mp; do
        fuser -k -m "$mp" 2>/dev/null || true
        umount -l "$mp" 2>/dev/null || true
    done
    umount -l /mnt/pine_boot 2>/dev/null || true
    umount -l /mnt/pine_root 2>/dev/null || true
    sync && sleep 2
}

error_handler() {
    local line_no=$1
    echo "[FATAL] Script failed on line $line_no." >&2
    {
        echo "--- PineRE CRASH DUMP ---"; echo "Timestamp: $(date)"; echo "Failed Line: $line_no"
        echo "--- DISK STATUS ---"; lsblk
    } > /tmp/r36_crash_dump.txt
    exit 1
}
trap 'error_handler $LINENO' ERR

# --- DIRECTORY MAP (Updated to match tree.txt) ---
WORKING_DIR="$(dirname "${BASH_SOURCE[0]}")"
UBOOT_DIR="${WORKING_DIR}/u-boot"
BOOT_FILES_DIR="${WORKING_DIR}/boot-files"
COPY_OVER_DIR="${WORKING_DIR}/copy-over"
ALPINE_TEMP_DIR="${WORKING_DIR}/alpine-temp"

BOOTFS="/mnt/pine_boot"
ROOTFS="/mnt/pine_root"
exec > >(tee -a "/tmp/r36ultra_setup.log") 2>&1

cleanup_mounts

# --- PARTITIONING ---
if confirm "Partition"; then
    log_info "Wiping and partitioning $TARGET_DEV..."
    dd if=/dev/zero of="$TARGET_DEV" bs=1M count=1 oflag=direct conv=notrunc
    parted -s "$TARGET_DEV" mklabel msdos
    parted -s "$TARGET_DEV" unit MiB mkpart primary fat32 32 512
    parted -s "$TARGET_DEV" unit MiB mkpart primary ext4 512 100%
    udevadm settle && partprobe "$TARGET_DEV" && blockdev --rereadpt "$TARGET_DEV" || true
    sleep 3
    P_SUFFIX=$( [[ "$TARGET_DEV" == *mmcblk* ]] && echo "p" || echo "" )
    mkfs.vfat -n BOOT "${TARGET_DEV}${P_SUFFIX}1"
    mkfs.ext4 -O ^has_journal -L ROOT "${TARGET_DEV}${P_SUFFIX}2"
    sync && sleep 5
fi

# --- MOUNTING ---
cleanup_mounts
P_SUFFIX=$( [[ "$TARGET_DEV" == *mmcblk* ]] && echo "p" || echo "" )
TARGET_UUID=$(blkid -s PARTUUID -o value "${TARGET_DEV}${P_SUFFIX}2")
mkdir -p "$BOOTFS" "$ROOTFS"
mount -o sync "${TARGET_DEV}${P_SUFFIX}1" "$BOOTFS"
mount -o sync "${TARGET_DEV}${P_SUFFIX}2" "$ROOTFS"

# --- INSTALLATION ---
if confirm "U-Boot"; then
    log_info "Flashing U-Boot..."
    dd if="${UBOOT_DIR}/idbloader.img" of="$TARGET_DEV" seek=64 conv=notrunc
    dd if="${UBOOT_DIR}/u-boot.itb" of="$TARGET_DEV" seek=16384 conv=notrunc
fi

if confirm "Extract"; then
    cleanup_mounts
    mount -o sync "${TARGET_DEV}${P_SUFFIX}1" "$BOOTFS"
    mount -o sync "${TARGET_DEV}${P_SUFFIX}2" "$ROOTFS"
    log_info "Extracting RootFS from alpine-temp..."
    tar -xzf "${ALPINE_TEMP_DIR}/alpine-minirootfs-3.23.4-aarch64.tar.gz" -C "$ROOTFS"
fi

if confirm "Packages"; then
    log_info "Installing packages..."
    cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
    
    # Push local APKs to the temp folder inside the RootFS
    cp "${ALPINE_TEMP_DIR}/"*.apk "$ROOTFS/tmp/" 2>/dev/null || true
    
    for d in dev proc sys run; do mount --bind /$d "$ROOTFS/$d"; done
    
    # Add testing repo for Musl EmulationStation
    echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> "$ROOTFS/etc/apk/repositories"
    
    # Install standard packages + emulationstation from @testing
    chroot "$ROOTFS" apk update && chroot "$ROOTFS" apk add openrc bash sudo networkmanager dbus mc alsa-utils mesa-dri-gallium xorg-server xf86-video-fbdev emulationstation@testing retroarch python3 py3-evdev xfce4 xfce4-terminal
    
    # Install the local offline APKs if they exist
    chroot "$ROOTFS" apk add --allow-untrusted /tmp/*.apk || true
    
    # Apply custom bios, roms, and themes from copy-over
    if [ -d "$COPY_OVER_DIR" ]; then
        log_info "Applying copy-over contents (bios, roms, themes)..."
        cp -r "${COPY_OVER_DIR}/"* "$ROOTFS/"
    fi
    
    for d in dev proc sys run; do umount "$ROOTFS/$d"; done
fi

if confirm "Bootfiles"; then
    log_info "Copying boot-files (Image, DTB, uInitrd)..."
    if [ -d "$BOOT_FILES_DIR" ]; then
        cp "${BOOT_FILES_DIR}/"* "$BOOTFS/"
    fi

    log_info "Generating boot.ini..."
    cat > "$BOOTFS/boot.ini" << 'EOF'
ODROIDC-UBOOT-CONFIG
setenv bootmode "es"
setenv kernel_addr_r 0x02000000
setenv fdt_addr_r 0x01f00000
setenv ramdisk_addr_r 0x04000000
setenv bootargs "console=ttyS2,1500000 console=tty1 root=PARTUUID=${target_uuid} rw rootwait video=Display-0:720x720@60 bootmode=${bootmode}"
load mmc 0:1 ${kernel_addr_r} Image
load mmc 0:1 ${fdt_addr_r} rk3326-r36ultra-linux.dtb
load mmc 0:1 ${ramdisk_addr_r} uInitrd
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
EOF
    sed -i "s/\${target_uuid}/$TARGET_UUID/g" "$BOOTFS/boot.ini"
    sync
fi

umount "$BOOTFS" "$ROOTFS"
log_info "✓ Compilation complete."