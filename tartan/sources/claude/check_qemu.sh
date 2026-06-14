#!/usr/bin/env bash
set -euo pipefail

# Visual status helper
status_check() {
    if "$@"; then
        echo "   [✓] PASS"
        return 0
    else
        echo "   [✗] FAIL"
        return 1
    fi
}

echo "============================================="
echo "  MX Linux AArch64 QEMU Environment Checker  "
echo "============================================="

# 1. Check if the static binary helper exists
echo -n "1. Checking for qemu-aarch64-static binary..."
status_check which qemu-aarch64-static >/dev/null

# 2. Check if binfmt kernel registration is active
echo -n "2. Checking kernel binfmt_misc configuration..."
status_check grep -q "enabled" /proc/sys/fs/binfmt_misc/status 2>/dev/null

# 3. Check if aarch64 specifically is registered in the kernel
echo -n "3. Checking if system recognizes ARM64 binaries..."
status_check ls /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null

# 4. Live Execution Test
echo "4. Running live multi-arch container test..."
if ! command -v docker &> /dev/null; then
    echo "   [✗] FAIL: Docker is not installed on this host. Cannot complete live test."
    exit 1
fi

echo "   -> Pulling a tiny AArch64 container image to verify execution..."
# This forces Docker to download and execute an ARM64 image on your x86_64 CPU
ARCH_RESULT=$(docker run --rm --platform linux/arm64 alpine uname -m 2>/dev/null || echo "failed")

if [ "$ARCH_RESULT" = "aarch64" ]; then
    echo "   [✓] SUCCESS: Your laptop safely executed an AArch64 test command!"
    echo "============================================="
    echo " RESULT: Ready for cross-development in VSCode."
    echo "============================================="
else
    echo "   [✗] FAIL: System could not execute the ARM64 test container."
    echo "============================================="
    echo " RESULT: Environment NOT ready yet."
    echo "============================================="
fi
