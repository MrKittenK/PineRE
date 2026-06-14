# R36 Ultra — "DTB Load Fail" Troubleshooting Report

> **Device:** Powkiddy R36 Ultra (RK3326, Cortex-A35 quad-core)
> **Goal:** Boot Alpine Linux using ArkOS's kernel (`Image`) and initramfs (`uInitrd`) with a custom Device Tree Blob (`rk3326-r36ultra-linux.dtb`) and boot script (`boot.ini`).
> **Symptom:** `dtb load fail` error during U-Boot boot sequence.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Root Cause Analysis](#root-cause-analysis)
3. [Corrected boot.ini](#corrected-bootini)
4. [Setup Script Fixes](#setup-script-fixes)
5. [Missing Files for Alpine Linux](#missing-files-for-alpine-linux)
6. [Recommended Folder Structure](#recommended-folder-structure)
7. [Educational Reference: U-Boot Boot Flow on RK3326](#educational-reference-u-boot-boot-flow-on-rk3326)

---

## Executive Summary

I found **five issues** that contribute to the "dtb load fail" error. The most critical is the **magic header string** — your `boot.ini` uses `ODROIDGO3-UBOOT-CONFIG` but the ArkOS U-Boot firmware expects `odroidgoa-uboot-config` (lowercase, and "goa" not "GO3"). When U-Boot cannot match this magic string, it **ignores your entire boot script** and falls back to a compiled-in default boot sequence that tries to load a DTB file with a different name (e.g., `rk3326-odroid-go2.dtb` or `rk3326-r35s-linux.dtb`), which does not exist on your SD card — hence the "dtb load fail".

The other issues are secondary but would cause failures even after fixing the magic string.

> [!CAUTION]
> Your `post-setup-modified-boot.ini` has a critically broken `booti` command:
> `booti ${kernel_addr_r} - ${ramdisk_addr_r} - ${fdt_addr_r}` — the extra `-` turns the FDT address into a 5th argument that U-Boot ignores, meaning **no DTB is ever loaded**. This is documented in [Issue #4](#issue-4-broken-booti-syntax-in-experimental-variants) below.

---

## Root Cause Analysis

### Issue #1: Wrong Magic Header String (PRIMARY CAUSE)

| | Your `boot.ini` | Every reference `boot.ini` |
|---|---|---|
| **First line** | `ODROIDGO3-UBOOT-CONFIG` | `odroidgoa-uboot-config` |
| **Case** | UPPERCASE | lowercase |
| **Device name** | `GO3` (ODROID Go 3 — does not exist) | `goa` (ODROID Go **Advance**) |

**Why this matters:**
The ArkOS U-Boot firmware for RK3326 devices checks the first line of `boot.ini` for an exact-match magic string before parsing the rest of the file as a U-Boot script. This magic string tells U-Boot "this file is a valid boot configuration, please execute it."

- The Hardkernel ODROID Go Advance (OGA) was the first RK3326 handheld. All subsequent RK3326 U-Boot forks (ArkOS, ROCKNIX, DarkOS) inherit this magic string: `odroidgoa-uboot-config`.
- Your file uses `ODROIDGO3-UBOOT-CONFIG` — a string that no known RK3326 U-Boot firmware recognises.
- When U-Boot sees an unrecognised first line, it **does not execute your boot.ini at all**. Instead, it runs its internal default boot sequence.
- The default sequence attempts to load a DTB with a hardcoded name that doesn't match your file, producing `dtb load fail`.

**Evidence:** All six of your reference files confirm the correct string:

```
# arkosmultipanel-boot.ini, line 1:
odroidgoa-uboot-config

# rocknix-boot.ini, line 1:
odroidgoa-uboot-config

# darkos-boot.ini, line 1:
odroidgoa-uboot-config

# android-boot.ini, line 1:
odroidgoa-uboot-config
```

> [!IMPORTANT]
> **Fix:** Change line 1 of `boot.ini` from `ODROIDGO3-UBOOT-CONFIG` to `odroidgoa-uboot-config`.

---

### Issue #2: Inconsistent Load Commands (`fatload` vs `load`)

Your `boot.ini` mixes two different U-Boot load commands:

```bash
# Lines 23-25 of your boot.ini:
fatload ${devtype} ${devnum}:1 ${kernel_addr_r} /Image       # fatload
fatload ${devtype} ${devnum}:1 ${ramdisk_addr_r} /uInitrd    # fatload
load ${devtype} ${devnum}:1 ${fdt_addr_r} ${fdtfile}         # load (different!)
```

**Why this matters:**
- `fatload` is an older U-Boot command that **only works on FAT filesystems**. Some U-Boot builds have removed it in favour of the generic `load`.
- `load` is the modern, generic U-Boot command that auto-detects the filesystem type (FAT, ext4, etc.). It is the universally recommended command.
- Every reference boot.ini uses `load` uniformly:

```bash
# darkos-boot.ini:
load mmc 1:1 ${loadaddr} Image
load mmc 1:1 ${initrd_loadaddr} uInitrd
load mmc 1:1 ${dtb_loadaddr} rk3326-r36s-linux.dtb
```

> [!IMPORTANT]
> **Fix:** Replace all `fatload` calls with `load`. Use consistent syntax throughout.

---

### Issue #3: Leading-Slash Path Inconsistency

```bash
fatload ... /Image          # ← leading slash
fatload ... /uInitrd        # ← leading slash
load ... ${fdtfile}         # ← NO leading slash (fdtfile = "rk3326-r36ultra-linux.dtb")
```

**Why this matters:**
- On most RK3326 U-Boot builds, filenames on the FAT partition can be specified with or without a leading `/`. Both work.
- However, **inconsistency is dangerous**: if a particular U-Boot build treats these differently, one will work and the other won't.
- Every reference boot.ini uses **no leading slash** for all filenames.
- This creates a silent discrepancy where Image and uInitrd load fine but the DTB fails.

> [!IMPORTANT]
> **Fix:** Remove leading slashes. Use bare filenames: `Image`, `uInitrd`, `rk3326-r36ultra-linux.dtb`.

---

### Issue #4: Broken `booti` Syntax in Experimental Variants

Your [post-setup-modified-boot.ini](file:///home/mrkitten/Desktop/alpha/example-boot-ini/post-setup-modified-boot.ini) contains:

```bash
booti ${kernel_addr_r} - ${ramdisk_addr_r} - ${fdt_addr_r}
#                      ^                   ^
#                      These dashes are WRONG
```

The correct `booti` syntax is:

```
booti <kernel_addr> <ramdisk_addr> <fdt_addr>
booti <kernel_addr> -              <fdt_addr>    ← dash means "no ramdisk"
```

**`booti` takes exactly 3 arguments.** The dashes in positions 2 and 4 turn this into a 5-argument call. U-Boot interprets this as:
- `arg1`: kernel at `${kernel_addr_r}` ✓
- `arg2`: `-` (no ramdisk) ← **ignores your uInitrd!**
- `arg3`: `${ramdisk_addr_r}` (treated as FDT address — wrong data, wrong format)

The real FDT address is pushed to argument 5, which `booti` ignores entirely.

> [!WARNING]
> This variant would never successfully boot even with the correct magic string — the kernel would receive garbage instead of a DTB, and no ramdisk at all.

---

### Issue #5: `devtype`/`devnum` Variable Risk

Your boot.ini uses:

```bash
if test -z "${devtype}"; then setenv devtype mmc; fi
if test -z "${devnum}"; then setenv devnum 1; fi
```

**Why this is risky:**
- Not all RK3326 U-Boot builds set `devtype` and `devnum` environment variables before running `boot.ini`.
- If `devnum` defaults incorrectly (e.g., `0` for internal eMMC instead of `1` for the SD card), all file loads will fail.
- Every reference boot.ini **hardcodes** `mmc 1:1`:

```bash
load mmc 1:1 ${loadaddr} Image
```

This is intentional: on RK3326 handhelds, the SD card is always `mmc 1` (the eMMC is `mmc 0`).

> [!TIP]
> **Fix:** Hardcode `mmc 1:1` for reliability on R36 Ultra. Environment variable detection is an unnecessary complexity that adds a failure mode.

---

## Corrected boot.ini

Here is the corrected `boot.ini` with educational comments:

```bash
odroidgoa-uboot-config

# =============================================================================
# R36 Ultra - Alpine Linux Boot Configuration
# =============================================================================
# 
# EDUCATIONAL: This file is a U-Boot boot script for the Powkiddy R36 Ultra.
# It is NOT a shell script — it uses U-Boot's command interpreter, which has
# similar but different syntax to bash/sh.
#
# The first line ("odroidgoa-uboot-config") is a magic identifier that the
# ArkOS-derived U-Boot firmware checks before parsing this file. Without it,
# U-Boot will ignore this file entirely and fall back to its internal defaults.
# The string derives from the ODROID Go Advance (OGA), the original RK3326
# handheld that all subsequent devices (R36S, R36 Ultra, RG351, etc.) are
# firmware-compatible with.
# =============================================================================

# --- Memory Addresses ---
# EDUCATIONAL: These addresses define WHERE in RAM each component is loaded.
# They must not overlap. The RK3326 has a 32-bit address space mapped to DDR.
#
#   0x01f00000  (31 MB) = Device Tree Blob (~76 KB, tiny)
#   0x02000000  (32 MB) = Kernel Image     (~25 MB)
#   0x04000000  (64 MB) = Ramdisk/initrd   (~6.4 MB)
#
# EDUCATIONAL: The addresses are chosen so that:
#   - The DTB sits just below the kernel (31 MB mark)
#   - The kernel occupies 32–57 MB
#   - The ramdisk starts at 64 MB, well clear of the kernel
#   - All three fit comfortably in the R36 Ultra's 1 GB DDR3
#
setenv loadaddr     "0x02000000"
setenv dtb_loadaddr "0x01f00000"
setenv initrd_loadaddr "0x04000000"

# --- Address Ceiling Guards ---
# EDUCATIONAL: fdt_high and initrd_high tell U-Boot "do not relocate these
# after loading." Setting them to 0xffffffff means "any address is fine, leave
# them where I loaded them." Without these, U-Boot may try to move the DTB or
# initrd to a "safer" address and corrupt them in the process.
#
setenv fdt_high     0xffffffff
setenv initrd_high  0xffffffff

# --- Kernel Command Line ---
# EDUCATIONAL: bootargs is passed to the Linux kernel as its command line.
# Each parameter controls a specific kernel subsystem:
#
#   root=PARTUUID=...     Which partition holds the root filesystem.
#                         PARTUUID is a hardware-independent identifier that
#                         survives device renaming (unlike /dev/mmcblk0p2).
#
#   rootwait              Wait for the root device to appear before mounting.
#                         SD cards take time to initialise; without this, the
#                         kernel may panic with "can't find root device."
#
#   rw                    Mount root filesystem read-write from the start.
#                         Alpine's OpenRC init expects this for /etc/fstab.
#
#   console=tty1          Send kernel logs to the first virtual terminal.
#                         On the R36 Ultra, tty1 maps to the 720x720 DSI panel.
#
#   loglevel=4            Show WARNING and above during boot (0=emergency,
#                         7=debug). Use loglevel=7 for debugging, 4 for normal.
#
#   video=DSI-1:720x720@60  Force the DSI display to 720x720 at 60 Hz.
#                            Prevents the kernel from auto-detecting a wrong
#                            resolution for the R36 Ultra's square panel.
#
setenv bootargs "root=PARTUUID=${root_uuid} rootwait rw console=tty1 loglevel=4 video=DSI-1:720x720@60"

# --- Load Kernel, Ramdisk, and Device Tree ---
# EDUCATIONAL: "load mmc 1:1" means:
#   - load     = U-Boot generic filesystem load command (works on FAT, ext4, etc.)
#   - mmc      = MMC/SD interface
#   - 1        = Device index 1 (SD card slot on R36 Ultra; eMMC is device 0)
#   - :1       = Partition 1 (the BOOT partition, formatted as FAT32)
#
# EDUCATIONAL: The load order matters. U-Boot sets ${filesize} to the number
# of bytes loaded by the LAST successful 'load' command. If we load the ramdisk
# last, ${filesize} contains the ramdisk size, which booti needs to know the
# extent of the initrd in memory.
#

echo "=== R36 Ultra: Loading Alpine Linux ==="

load mmc 1:1 ${dtb_loadaddr} rk3326-r36ultra-linux.dtb
# EDUCATIONAL: Load DTB first. If this fails, we get a clear error and stop.
# This is the file most likely to be missing or misnamed, so loading it first
# provides the clearest error message.

load mmc 1:1 ${loadaddr} Image
# EDUCATIONAL: Load the ArkOS kernel. "Image" is an uncompressed ARM64 kernel
# in the Linux boot executable format. The "file" command confirms:
# "Linux kernel ARM64 boot executable Image, little-endian, 4K pages"

load mmc 1:1 ${initrd_loadaddr} uInitrd
# EDUCATIONAL: Load the ArkOS initial ramdisk. This is a gzip-compressed cpio
# archive containing the early userspace (busybox, device setup, etc.).
# Loading it last means ${filesize} now holds the ramdisk size.

# --- Boot the Kernel ---
# EDUCATIONAL: booti is the U-Boot command for booting ARM64 (AArch64) kernels.
# Syntax: booti <kernel_addr> <ramdisk_addr>:<ramdisk_size> <fdt_addr>
#
#   - Use ${initrd_loadaddr}:${filesize} to tell the kernel exactly where the
#     ramdisk starts and how big it is. Without the size, the kernel might
#     read past the end of the ramdisk into uninitialised memory.
#   - If you had NO ramdisk, you would use a dash: booti ${loadaddr} - ${dtb_loadaddr}
#
echo "=== Starting Kernel ==="
booti ${loadaddr} ${initrd_loadaddr}:${filesize} ${dtb_loadaddr}

# EDUCATIONAL: If booti fails, U-Boot will print an error and drop to its
# command prompt (if interactive) or reset. Common failure modes:
#   - "Bad Linux ARM64 Image magic!" = Image file is corrupt or wrong format
#   - "FDT and target do not match" = DTB is for a different SoC
#   - "Ramdisk image is corrupt"    = uInitrd has wrong format or size
```

> [!NOTE]
> The `${root_uuid}` placeholder in the `bootargs` line is replaced by your `setup_r36ultra.sh` script using `sed` before writing to the SD card. This is correct — it is a **build-time** substitution, not a U-Boot variable.

---

## Setup Script Fixes

The [setup_r36ultra.sh](file:///home/mrkitten/Desktop/alpha/setup_r36ultra.sh) boot file deployment section (starting at line 654) needs two adjustments to match the corrected `boot.ini`:

### Fix 1: sed Pattern for Boot.ini Injection (Line 680)

The current sed pattern works correctly for the `${root_uuid}` placeholder, but the corrected boot.ini moves the placeholder into double-quoted bootargs. No change needed here — the existing sed command handles this properly:

```bash
sed "s/\${root_uuid}/${TARGET_UUID_ESCAPED}/g" \
    "$WORKING_DIR/boot.ini" > "$BOOTFS/boot.ini" && sync
```

### Fix 2: Verify DTB Filename Consistency

The script copies files to the BOOT partition on line 685:

```bash
for file in uInitrd Image rk3326-r36ultra-linux.dtb; do
```

This matches the DTB filename in the corrected `boot.ini` (`rk3326-r36ultra-linux.dtb`). No change needed.

### Fix 3: Add Post-Copy boot.ini Validation (NEW — Recommended)

Add a validation step after boot file deployment to catch the magic string issue at build time rather than at boot time. Add this after line 703 in [setup_r36ultra.sh](file:///home/mrkitten/Desktop/alpha/setup_r36ultra.sh#L703):

```bash
# LEARNING: Validate that the boot.ini on the SD card has the correct magic string.
# This catches the most common cause of "dtb load fail" at build time.
MAGIC_LINE=$(head -n 1 "$BOOTFS/boot.ini" | tr -d '[:space:]')
EXPECTED_MAGIC="odroidgoa-uboot-config"
if [ "$MAGIC_LINE" != "$EXPECTED_MAGIC" ]; then
    log_error "boot.ini magic string mismatch!"
    log_error "  Expected: $EXPECTED_MAGIC"
    log_error "  Got:      $MAGIC_LINE"
    log_error "  U-Boot will NOT parse this file."
    log_fatal "Fix the first line of boot.ini and re-run."
fi
log_info "✓ boot.ini magic string verified: $MAGIC_LINE"

# LEARNING: Verify DTB has valid FDT magic number (0xd00dfeed).
# A corrupt or zero-byte DTB will cause "dtb load fail" at boot.
DTB_MAGIC=$(hexdump -n 4 -e '4/1 "%02x"' "$BOOTFS/rk3326-r36ultra-linux.dtb" 2>/dev/null)
if [ "$DTB_MAGIC" != "d00dfeed" ]; then
    log_error "DTB file appears corrupt or invalid!"
    log_error "  Expected magic: d00dfeed"
    log_error "  Got:            $DTB_MAGIC"
    log_fatal "Re-compile or re-download rk3326-r36ultra-linux.dtb"
fi
log_info "✓ DTB magic number verified: 0x$DTB_MAGIC"
```

---

## Missing Files for Alpine Linux

Your current setup has the boot files needed to **start the kernel**, but Alpine Linux on an embedded device needs several additional configuration files to **complete the boot to a usable system**.

### Files You Have (✓)

| File | Source | Status |
|------|--------|--------|
| `Image` (25.8 MB) | ArkOS kernel | ✓ Valid ARM64 kernel |
| `uInitrd` (6.4 MB) | ArkOS initramfs | ✓ Valid gzip archive |
| `rk3326-r36ultra-linux.dtb` (75 KB) | Your custom DTB | ✓ Valid FDT v17, magic `d00dfeed` |
| `boot.ini` | Your custom script | ⚠️ Needs fixes (see above) |
| `idbloader.img` (8.4 MB) | ArkOS U-Boot SPL | ✓ |
| `u-boot.itb` (4.2 MB) | ArkOS U-Boot proper | ✓ |
| `alpine-minirootfs-3.23.4-aarch64.tar.gz` | Alpine Project | ✓ |

### Files/Configs You May Be Missing (⚠️)

> [!WARNING]
> The ArkOS `uInitrd` contains an ArkOS-specific init sequence that expects ArkOS's root filesystem layout. It will likely **not** pivot-root into a vanilla Alpine root filesystem correctly. This is the **biggest compatibility risk** in your entire setup.

#### 1. `/etc/fstab` on ROOT partition

Alpine needs an `fstab` to know how to mount its filesystems. Your setup script does not create one.

```bash
# Add to ROOT partition after extracting alpine-minirootfs:
cat > "$ROOTFS/etc/fstab" << 'EOF'
# <device>                              <mount>  <type>  <options>               <dump> <pass>
LABEL=ROOT                              /        ext4    defaults,noatime        0      1
LABEL=BOOT                              /boot    vfat    defaults,ro             0      2
tmpfs                                   /tmp     tmpfs   nosuid,nodev,size=64m   0      0
EOF
```

#### 2. `/etc/inittab` on ROOT partition

Alpine's OpenRC needs an inittab that matches your hardware's console:

```bash
cat > "$ROOTFS/etc/inittab" << 'EOF'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
tty1::respawn:/sbin/getty 38400 tty1
::shutdown:/sbin/openrc shutdown
::ctrlaltdel:/sbin/reboot
EOF
```

#### 3. `/etc/hostname` and `/etc/hosts`

```bash
echo "r36ultra" > "$ROOTFS/etc/hostname"

cat > "$ROOTFS/etc/hosts" << 'EOF'
127.0.0.1   localhost r36ultra
::1         localhost r36ultra
EOF
```

#### 4. Root Password

Alpine minirootfs ships with a locked root account. You need to set a password or the system will be inaccessible:

```bash
# In the chroot section of setup_r36ultra.sh:
chroot "$ROOTFS" sh -c 'echo "root:alpine" | chpasswd'
# Or for no password (less secure, fine for development):
chroot "$ROOTFS" passwd -d root
```

#### 5. OpenRC Services

Enable essential services so networking and display work on boot:

```bash
chroot "$ROOTFS" rc-update add devfs sysinit
chroot "$ROOTFS" rc-update add mdev sysinit
chroot "$ROOTFS" rc-update add hwdrivers sysinit
chroot "$ROOTFS" rc-update add networking boot
chroot "$ROOTFS" rc-update add hostname boot
```

#### 6. The ArkOS uInitrd Compatibility Problem

> [!CAUTION]
> **This is likely your next blocking issue after fixing the DTB load error.**

The ArkOS `uInitrd` is not a generic initramfs — it is built specifically for ArkOS and contains:
- ArkOS-specific partition detection logic (looks for `LABEL=GAMES`, `LABEL=STORAGE`, etc.)
- ArkOS-specific pivot-root logic (expects `/roms`, `/opt/system`, etc.)
- ArkOS-specific module loading (firmware for specific WiFi chips, etc.)

When this initramfs runs against your Alpine root filesystem, it will likely:
1. Fail to find the expected partition labels
2. Fail to pivot-root into Alpine's filesystem layout
3. Drop to a busybox emergency shell, or kernel panic

**Solutions (in order of recommendation):**

| Approach | Effort | Reliability |
|----------|--------|-------------|
| **A. Build your own initramfs** with `mkinitfs` from Alpine | Medium | High |
| **B. Boot without initramfs** (if kernel has SD card drivers built-in) | Low | Medium |
| **C. Extract and modify ArkOS's uInitrd** to work with Alpine | High | Low |

**Approach A — Build Alpine initramfs:**
```bash
# Inside chroot:
chroot "$ROOTFS" apk add mkinitfs
# Create initramfs features file:
mkdir -p "$ROOTFS/etc/mkinitfs"
echo 'features="ata base ext4 mmc usb"' > "$ROOTFS/etc/mkinitfs/mkinitfs.conf"
# Generate initramfs (requires the kernel's modules directory):
# NOTE: You need kernel modules from the ArkOS kernel for this to work
```

**Approach B — Boot without initramfs:**
Modify the `booti` line in `boot.ini` to skip the ramdisk:
```bash
# Use dash (-) instead of ramdisk address to boot without initramfs:
booti ${loadaddr} - ${dtb_loadaddr}
```
This only works if the ArkOS kernel has the SD card driver (`dw_mmc`) and ext4 filesystem compiled in (not as loadable modules).

---

## Recommended Folder Structure

Here is an improved folder structure that separates concerns clearly. **No filenames have been shortened.**

```
alpha/
│
├── boot-files/
│   │   # EDUCATIONAL: Everything in this folder goes to the FAT32 BOOT partition.
│   │   # These files are read by U-Boot and the kernel during early boot.
│   │
│   ├── boot.ini                           # U-Boot boot script (your authorship)
│   ├── Image                              # Linux kernel (from ArkOS)
│   ├── uInitrd                            # Initial ramdisk (from ArkOS)
│   └── rk3326-r36ultra-linux.dtb          # Device Tree Blob (your authorship)
│
├── bootloader/
│   │   # EDUCATIONAL: Raw binary blobs written to specific SD card sectors.
│   │   # These are NOT placed in any filesystem — they go to raw disk offsets.
│   │
│   ├── idbloader.img                      # U-Boot SPL, written to sector 64
│   └── u-boot.itb                         # U-Boot proper, written to sector 16384
│
├── rootfs/
│   │   # EDUCATIONAL: The Alpine Linux root filesystem archive.
│   │   # Extracted to the ext4 ROOT partition.
│   │
│   └── alpine-minirootfs-3.23.4-aarch64.tar.gz
│
├── device-tree-source/
│   │   # EDUCATIONAL: The human-readable source for the DTB.
│   │   # Not deployed to the SD card — used for development/debugging only.
│   │
│   └── rk3326-r36ultra-linux.dts
│
├── overlay/
│   │   # EDUCATIONAL: Files that are copied INTO the root filesystem after
│   │   # Alpine minirootfs is extracted. Organised to mirror the target
│   │   # filesystem layout.
│   │
│   ├── etc/
│   │   ├── fstab
│   │   ├── inittab
│   │   ├── hostname
│   │   ├── hosts
│   │   ├── X11/
│   │   │   └── xorg.conf.d/
│   │   │       └── 40-monitor.conf
│   │   └── apk/
│   │       └── repositories
│   │
│   └── usr/
│       └── local/
│           └── bin/
│               └── emulationstation-wrapper
│
├── assets/
│   │   # EDUCATIONAL: Application-level assets. Not part of system boot.
│   │   # Deployed after the system is running.
│   │
│   ├── bios/                              # RetroArch BIOS files
│   ├── ppsspp-assets/                     # PPSSPP emulator assets
│   └── triggerhappy/                      # TriggerHappy key daemon binary
│       └── thd
│
├── scripts/
│   │   # EDUCATIONAL: System management scripts deployed to the root filesystem.
│   │
│   ├── 00-network.start
│   ├── r36-control
│   ├── r36-input-monitor
│   ├── r36-led-daemon.sh
│   └── r36-led-util.sh
│
├── example-boot-ini/
│   │   # EDUCATIONAL: Reference boot.ini files from other operating systems.
│   │   # Used for comparison and debugging — not deployed.
│   │
│   ├── arkosmultipanel-boot.ini
│   ├── rocknix-boot.ini
│   ├── darkos-boot.ini
│   ├── android-boot.ini
│   ├── post-setup-modified-boot.ini
│   └── post-setup-script-boot-ini.ini
│
├── docs/
│   ├── MIGRATION_GUIDE.md
│   ├── PRODUCTION_READY.md
│   └── changelog.md
│
├── setup_r36ultra.sh                      # Main setup/flashing script
└── PRE_FLIGHT_CHECKS.sh                   # Pre-deployment validation
```

### Key Changes from Current Layout

| What Changed | Why |
|---|---|
| Boot files moved to `boot-files/` | Clearly separates "what goes to BOOT partition" from everything else |
| Bootloader blobs moved to `bootloader/` | These aren't filesystem files — they go to raw disk sectors |
| DTS moved to `device-tree-source/` | Source code ≠ deployment artifact; prevents accidental deployment of the 97 KB DTS instead of the 76 KB DTB |
| New `overlay/` directory | Files that go INTO the rootfs are organised to mirror the target layout, making deployment a simple `cp -a overlay/* "$ROOTFS/"` |
| Assets grouped under `assets/` | Makes it clear these are optional application data, not system-critical |
| Docs grouped under `docs/` | Keeps the root directory clean |

---

## Educational Reference: U-Boot Boot Flow on RK3326

Understanding the full boot sequence helps diagnose where failures occur:

```
┌─────────────────────────────────────────────────────┐
│  POWER ON                                           │
│                                                     │
│  1. RK3326 BootROM (in silicon, unchangeable)       │
│     ├── Reads sector 64 of SD card (or eMMC)        │
│     └── Loads idbloader.img into internal SRAM       │
│                                                     │
│  2. idbloader.img (U-Boot SPL + TPL)                │
│     ├── Initialises DDR memory                      │
│     ├── Initialises basic clocks                    │
│     └── Loads u-boot.itb from sector 16384 into DDR │
│                                                     │
│  3. u-boot.itb (U-Boot proper)                      │
│     ├── Initialises SD card controller fully         │
│     ├── Reads FAT32 partition 1 (BOOT)              │
│     ├── Looks for "boot.ini"                        │
│     ├── Checks first line for magic string ◄────────┤ YOUR ERROR IS HERE
│     │   ├── If match: parse as U-Boot script        │
│     │   └── If no match: use default boot sequence  │
│     ├── Executes load commands (DTB, kernel, initrd)│
│     └── Executes booti → hands off to kernel        │
│                                                     │
│  4. Linux Kernel (Image)                            │
│     ├── Receives DTB and bootargs from U-Boot       │
│     ├── Parses DTB to discover hardware             │
│     ├── Unpacks uInitrd into tmpfs                  │
│     └── Runs /init from the initramfs               │
│                                                     │
│  5. initramfs (/init)                               │
│     ├── Sets up /dev, /proc, /sys                   │
│     ├── Loads kernel modules (if needed)            │
│     ├── Mounts real root filesystem ◄───────────────┤ ArkOS vs Alpine mismatch
│     └── pivot_root + exec /sbin/init                │
│                                                     │
│  6. Alpine OpenRC (/sbin/init → /sbin/openrc)       │
│     ├── Runs sysinit scripts                        │
│     ├── Mounts filesystems from /etc/fstab          │
│     ├── Starts services (networking, sshd, etc.)    │
│     └── Spawns login getty on tty1                  │
└─────────────────────────────────────────────────────┘
```

### Where Each File Lives on the SD Card

```
SD Card Raw Layout:
┌──────────┬─────────────────┬──────────────────┬────────────────────┐
│ 0-512B   │ 32KB - ~9MB     │ 8MB - 12MB       │                    │
│ MBR      │ idbloader.img   │ u-boot.itb       │                    │
│ (part.   │ (sector 64)     │ (sector 16384)   │                    │
│  table)  │                 │                  │                    │
├──────────┴─────────────────┴──────────────────┤                    │
│ 32 MB mark                                    │                    │
├───────────────────────────────────────────────┼────────────────────┤
│ Partition 1: BOOT (FAT32)                     │ Partition 2: ROOT  │
│                                               │ (ext4)             │
│  boot.ini                                     │                    │
│  Image                                        │  /bin, /etc,       │
│  uInitrd                                      │  /usr, /var, ...   │
│  rk3326-r36ultra-linux.dtb                    │  (Alpine rootfs)   │
│                                               │                    │
└───────────────────────────────────────────────┴────────────────────┘
```

---

## Summary of All Required Changes

| Priority | File | Change | Impact |
|----------|------|--------|--------|
| 🔴 Critical | `boot.ini` line 1 | `ODROIDGO3-UBOOT-CONFIG` → `odroidgoa-uboot-config` | Fixes DTB load fail |
| 🔴 Critical | `boot.ini` load commands | `fatload` → `load`, remove leading `/` | Consistent reliable loading |
| 🔴 Critical | `boot.ini` load target | Hardcode `mmc 1:1` | Eliminates variable risk |
| 🟡 Important | `boot.ini` booti line | Use `${initrd_loadaddr}:${filesize}` syntax | Correct ramdisk size |
| 🟡 Important | Root filesystem | Add fstab, inittab, hostname, root password | System boots to usable state |
| 🟠 Future | `uInitrd` | Build Alpine-native initramfs or test booting without | Correct root pivot |
| 🟢 Nice-to-have | Folder structure | Reorganise as shown above | Clearer maintenance |
| 🟢 Nice-to-have | `setup_r36ultra.sh` | Add post-copy validation (magic string + DTB magic) | Catches errors at build time |

> [!NOTE]
> **About the PDF request:** Markdown artifacts like this one can be exported to PDF from your browser using `Ctrl+P` → "Save as PDF". This preserves the formatting, tables, code blocks, and diagrams. I recommend this approach since generating a native PDF would lose the syntax highlighting and interactive links.
