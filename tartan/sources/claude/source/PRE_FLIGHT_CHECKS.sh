#!/bin/bash
# PRE-FLIGHT CHECKS FOR R36 ULTRA SD CARD SETUP
# Validates system readiness before running setup_r36ultra.sh
#
# LEARNING: Pre-flight checks prevent data loss and wasted time by validating
# all prerequisites before performing destructive operations

set -euo pipefail

echo "================================================================================"
echo "R36 Ultra Pre-Flight Checks - $(date)"
echo "================================================================================"
echo ""

# Track pass/fail counts
PASS=0
FAIL=0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

check_pass() {
    echo "  ✓ $*"
    PASS=$((PASS + 1))
}

check_fail() {
    echo "  ✗ $*"
    FAIL=$((FAIL + 1))
}

check_warn() {
    echo "  ⚠ $*"
}

# ============================================================================
# PERMISSION CHECKS
# ============================================================================

echo "[1/8] Checking User Permissions..."
if [ "$(id -u)" -eq 0 ]; then
    check_pass "Running as root"
else
    check_fail "Not running as root (required for mount/dd operations)"
    echo "       Re-run with: sudo $0"
    FAIL=$((FAIL + 1))
fi

# ============================================================================
# REQUIRED COMMANDS
# ============================================================================

echo "[2/8] Checking Required Commands..."
MISSING_CMDS=()

for cmd in mkimage dd find grep sed bc parted mkfs.vfat mkfs.ext4 md5sum blkid mount umount; do
    if command -v "$cmd" &>/dev/null; then
        check_pass "Command available: $cmd"
    else
        MISSING_CMDS+=("$cmd")
        check_fail "Command missing: $cmd"
    fi
done

if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
    echo ""
    echo "To install missing commands, try:"
    if command -v apt-get &>/dev/null; then
        echo "  sudo apt-get install e2fsprogs parted dosfstools util-linux"
    elif command -v yum &>/dev/null; then
        echo "  sudo yum install e2fsprogs parted dosfstools util-linux"
    elif command -v pacman &>/dev/null; then
        echo "  sudo pacman -S e2fsprogs parted dosfstools util-linux"
    fi
fi

# ============================================================================
# WORKING DIRECTORY
# ============================================================================

echo "[3/8] Checking Working Directory..."

WORK_DIR="${1:-.}"

if [ ! -d "$WORK_DIR" ]; then
    check_fail "Working directory not found: $WORK_DIR"
else
    check_pass "Working directory exists: $WORK_DIR"
fi

REQUIRED_FILES=("boot.ini" "Image" "uInitrd" "rk3326-r36ultra-linux.dtb")

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$WORK_DIR/$file" ]; then
        check_pass "Found: $file"
    else
        check_fail "Missing: $file"
    fi
done

# ============================================================================
# DISK SPACE
# ============================================================================

echo "[4/8] Checking Disk Space..."

# Calculate required space (100MB for build artifacts)
REQUIRED_KB=$((100 * 1024))
AVAILABLE_KB=$(df "$WORK_DIR" | tail -1 | awk '{print $4}')

if [ "$AVAILABLE_KB" -gt "$REQUIRED_KB" ]; then
    check_pass "Sufficient disk space: $(echo "scale=1; $AVAILABLE_KB / 1024 / 1024" | bc)GB available"
else
    check_fail "Insufficient disk space: only $(echo "scale=1; $AVAILABLE_KB / 1024" | bc)MB available"
fi

# ============================================================================
# TARGET DEVICE
# ============================================================================

echo "[5/8] Checking Target Device..."

# Scan for suitable SD cards
echo "  Available block devices:"
lsblk -d -n -o NAME,SIZE,TYPE | while read -r name size type; do
    if [ "$type" = "disk" ]; then
        echo "    /dev/$name ($size)"
    fi
done

# ============================================================================
# MOUNTED FILESYSTEMS CHECK
# ============================================================================

echo "[6/8] Checking for Already-Mounted Partitions..."

if grep -q /mnt/r36ultra /proc/mounts 2>/dev/null; then
    check_warn "R36 Ultra partitions already mounted (may be from previous run)"
    echo "       Run: sudo umount /mnt/r36ultra_*"
else
    check_pass "No R36 Ultra partitions currently mounted"
fi

# ============================================================================
# NETWORK CONNECTIVITY (for APK downloads)
# ============================================================================

echo "[7/8] Checking Network Connectivity..."

if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    check_pass "Internet connectivity available (Alpine packages can be downloaded)"
else
    check_warn "No internet connectivity detected"
    check_warn "Package installation will fail - ensure network available during setup"
fi

# ============================================================================
# PYTHON & EVDEV (for r36-input-monitor)
# ============================================================================

echo "[8/8] Checking Python Dependencies..."

if command -v python3 &>/dev/null; then
    check_pass "Python 3 available"
    
    if python3 -c "import evdev" 2>/dev/null; then
        check_pass "evdev module installed"
    else
        check_warn "evdev module not installed"
        check_warn "Install with: pip3 install evdev"
    fi
else
    check_warn "Python 3 not found (needed for r36-input-monitor)"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "================================================================================"
echo "Summary: $PASS passed, $FAIL failed"
echo "================================================================================"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "✓ All checks passed! Ready to run setup_r36ultra.sh"
    exit 0
else
    echo "✗ Some checks failed. Please fix the issues above before proceeding."
    exit 1
fi
