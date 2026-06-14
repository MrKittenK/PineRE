#!/bin/sh
# R36 Ultra LED Utility - Speed and Pattern Control - CORRECTED VERSION
# Provides interface for changing LED behavior at runtime
#
# LEARNING: This utility allows external processes (buttons, hotkeys, UI)
# to control LED patterns without stopping/restarting the daemon.
# It communicates via simple state files in /run.

# ============================================================================
# CONFIGURATION
# ============================================================================

# LEARNING: These files are written by r36-led-daemon, read/written by us
# Located in /run (tmpfs) for performance and transient storage
SPEED_FILE="/run/r36-led-speed"
PATTERN_FILE="/run/r36-led-pattern"

# ============================================================================
# MAIN CONTROL LOGIC
# ============================================================================

# LEARNING: Validate that state files exist, create with defaults if needed
if [ ! -f "$SPEED_FILE" ]; then
    echo "0.2" > "$SPEED_FILE"
fi

if [ ! -f "$PATTERN_FILE" ]; then
    echo "chase" > "$PATTERN_FILE"
fi

# LEARNING: Read current values for modification
CURRENT_SPEED=$(cat "$SPEED_FILE" 2>/dev/null || echo "0.2")
CURRENT_PATTERN=$(cat "$PATTERN_FILE" 2>/dev/null || echo "chase")

# ============================================================================
# COMMAND PROCESSING
# ============================================================================

case "${1:-help}" in
    speed_up)
        # LEARNING: Decrease sleep time = faster animations
        # bc -l enables floating point math
        # NEW_SPEED = CURRENT - 0.05
        NEW_SPEED=$(echo "$CURRENT_SPEED - 0.05" | bc)
        
        # LEARNING: Enforce minimum speed (0.05s = 50ms per frame)
        # Using bc: 1 if true, 0 if false
        if [ "$(echo "$NEW_SPEED < 0.05" | bc)" -eq 1 ]; then
            NEW_SPEED="0.05"
        fi
        echo "$NEW_SPEED" > "$SPEED_FILE"
        echo "LED Speed: UP (${NEW_SPEED}s per frame)"
        ;;
        
    speed_down)
        # LEARNING: Increase sleep time = slower animations
        # NEW_SPEED = CURRENT + 0.05
        NEW_SPEED=$(echo "$CURRENT_SPEED + 0.05" | bc)
        
        # LEARNING: Enforce maximum speed (1.0s = 1 second per frame)
        if [ "$(echo "$NEW_SPEED > 1.0" | bc)" -eq 1 ]; then
            NEW_SPEED="1.0"
        fi
        echo "$NEW_SPEED" > "$SPEED_FILE"
        echo "LED Speed: DOWN (${NEW_SPEED}s per frame)"
        ;;
        
    cycle_pattern|cycle)
        # LEARNING: Toggle between chase and rainbow patterns
        if [ "$CURRENT_PATTERN" = "chase" ]; then
            echo "rainbow" > "$PATTERN_FILE"
            echo "LED Pattern: rainbow"
        else
            echo "chase" > "$PATTERN_FILE"
            echo "LED Pattern: chase"
        fi
        ;;
        
    off)
        # LEARNING: Turn off pattern animations
        echo "off" > "$PATTERN_FILE"
        echo "LED Pattern: off (static, no animation)"
        ;;
        
    help|--help|-h)
        # LEARNING: Display usage information
        cat << 'EOF'
R36 Ultra LED Control Utility

Usage: r36-led-util.sh <command>

Commands:
  speed_up        Increase LED animation speed (minimum 0.05s)
  speed_down      Decrease LED animation speed (maximum 1.0s)
  cycle           Toggle between chase and rainbow patterns
  cycle_pattern   Same as cycle
  off             Disable LED animations (static off)
  help            Show this help message

Examples:
  # Speed up the current pattern
  r36-led-util.sh speed_up
  
  # Switch to rainbow pattern
  r36-led-util.sh cycle
  
  # Turn off LEDs
  r36-led-util.sh off

Notes:
  - Changes take effect immediately in the running daemon
  - Patterns: chase (cycle R→G→B), rainbow (cycle Y→C→M)
  - Speed range: 0.05s to 1.0s per animation frame
EOF
        ;;
        
    *)
        echo "ERROR: Unknown command '$1'" >&2
        echo "Use: $0 help" >&2
        exit 1
        ;;
esac

exit 0
