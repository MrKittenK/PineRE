#!/bin/sh
# R36 Ultra LED Pattern Daemon - CORRECTED VERSION
# Manages RGB LED patterns based on system state and battery level
#
# LEARNING: This daemon runs continuously, checking battery state and user
# preferences to display appropriate LED patterns. It integrates with the
# battery subsystem for low-battery warnings.

# ============================================================================
# CONFIGURATION
# ============================================================================

# LEARNING: Use /run instead of /tmp for runtime state files
# /run is backed by tmpfs (RAM) and persists only during runtime
# These files communicate state between processes
STATE_FILE="/run/r36-led-pattern"
SPEED_FILE="/run/r36-led-speed"

# LEARNING: These paths come from the Linux kernel's power supply subsystem
# They expose real-time battery information
BATTERY_CAPACITY="/sys/class/power_supply/battery/capacity"
BATTERY_STATUS="/sys/class/power_supply/battery/status"

# LED paths using the Linux LED subsystem (/sys/class/leds/)
# Each brightness file accepts values 0 (off) or 1 (on)
LED_RED="/sys/class/leds/joystick:red/brightness"
LED_GREEN="/sys/class/leds/joystick:green/brightness"
LED_BLUE="/sys/class/leds/joystick:blue/brightness"

# ============================================================================
# INITIALIZATION
# ============================================================================

# LEARNING: Initialize state files with defaults if they don't exist
# This allows other processes to control LED behavior via these files
[ ! -f "$STATE_FILE" ] && echo "chase" > "$STATE_FILE"
[ ! -f "$SPEED_FILE" ] && echo "0.2" > "$SPEED_FILE"

# LEARNING: Initialize LEDs to off at startup
# This prevents unpredictable LED states if the daemon restarted
if [ -f "$LED_RED" ]; then
    echo 0 > "$LED_RED"
fi
if [ -f "$LED_GREEN" ]; then
    echo 0 > "$LED_GREEN"
fi
if [ -f "$LED_BLUE" ]; then
    echo 0 > "$LED_BLUE"
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# LEARNING: Function to set LED colors
# Parameters: $1=red (0/1), $2=green (0/1), $3=blue (0/1)
# Uses compound operations to minimize LED writes
set_leds() {
    local red="$1" green="$2" blue="$3"
    
    # LEARNING: Only write to LED files if they exist
    # This prevents error messages if LEDs aren't available
    [ -f "$LED_RED" ] && echo "$red" > "$LED_RED"
    [ -f "$LED_GREEN" ] && echo "$green" > "$LED_GREEN"
    [ -f "$LED_BLUE" ] && echo "$blue" > "$LED_BLUE"
}

# LEARNING: Get current battery percentage
# Returns 100 if battery file not available
get_battery_capacity() {
    if [ -f "$BATTERY_CAPACITY" ]; then
        cat "$BATTERY_CAPACITY"
    else
        echo "100"  # Assume fully charged if no battery subsystem
    fi
}

# LEARNING: Get charging status (Charging, Discharging, Full, NotCharging)
get_battery_status() {
    if [ -f "$BATTERY_STATUS" ]; then
        cat "$BATTERY_STATUS"
    else
        echo "Unknown"
    fi
}

# LEARNING: Pattern implementations
# Each pattern uses specific LED combinations and timing
run_chase_pattern() {
    local speed="$1"
    
    # Cycle through: Red -> Green -> Blue
    set_leds 1 0 0; sleep "$speed"
    set_leds 0 1 0; sleep "$speed"
    set_leds 0 0 1; sleep "$speed"
}

run_rainbow_pattern() {
    local speed="$1"
    
    # Cycle through secondary colors
    set_leds 1 1 0; sleep "$speed"  # Yellow
    set_leds 0 1 1; sleep "$speed"  # Cyan
    set_leds 1 0 1; sleep "$speed"  # Magenta
}

run_off_pattern() {
    set_leds 0 0 0
    sleep 1
}

# ============================================================================
# BATTERY MONITORING
# ============================================================================

# LEARNING: Tracks consecutive low-battery iterations
# Used to trigger poweroff after sustained low battery
low_battery_count=0

# ============================================================================
# MAIN DAEMON LOOP
# ============================================================================

while true; do
    # LEARNING: Read current pattern and speed from state files
    # This allows external processes (like button handlers) to change patterns
    # without restarting the daemon
    pattern=$(cat "$STATE_FILE" 2>/dev/null)
    speed=$(cat "$SPEED_FILE" 2>/dev/null)
    
    # LEARNING: Set safe defaults if files don't exist or are empty
    pattern="${pattern:-chase}"
    speed="${speed:-0.2}"
    
    # Read battery information
    battery_capacity=$(get_battery_capacity)
    battery_status=$(get_battery_status)
    
    # ========================================================================
    # CRITICAL BATTERY HANDLING
    # ========================================================================
    
    # LEARNING: At <=2% battery, enter critical state
    # Stay in solid red, count down, and power off if not resolved
    if [ "$battery_capacity" -le 2 ]; then
        set_leds 1 0 0
        low_battery_count=$((low_battery_count + 1))
        
        # LEARNING: Shutdown after 30 seconds of critical battery
        # This protects against data loss from sudden power loss
        if [ "$low_battery_count" -ge 30 ]; then
            poweroff
        fi
        sleep 1
        continue
    fi
    
    # LEARNING: Reset counter when battery recovers
    low_battery_count=0
    
    # ========================================================================
    # LOW BATTERY WARNING
    # ========================================================================
    
    if [ "$battery_capacity" -le 5 ]; then
        # Red blink pattern: ON 0.8s, OFF 0.8s
        set_leds 1 0 0
        sleep 0.8
        set_leds 0 0 0
        sleep 0.8
        continue
    fi
    
    # ========================================================================
    # VERY LOW BATTERY BREATHING
    # ========================================================================
    
    if [ "$battery_capacity" -le 10 ]; then
        # LEARNING: Breathing pattern (fading LED)
        # Creates a pulse effect from 1-9 and back down
        # Gives visual indication of system still running
        for i in 1 2 3 4 5 6 7 8 9 8 7 6 5 4 3 2; do
            # LEARNING: Refresh battery status during pattern
            # In case charging started mid-pattern
            battery_status=$(get_battery_status)
            
            # LEARNING: Use fractional sleep: 0.0N means N/100 seconds
            # Creates smooth breathing effect (10ms increments)
            set_leds 1 0 0
            sleep "0.0${i}"
            set_leds 0 0 0
            sleep "0.0$((10 - i))"
        done
        continue
    fi
    
    # ========================================================================
    # NORMAL OPERATION - USE SELECTED PATTERN
    # ========================================================================
    
    case "$pattern" in
        chase)
            run_chase_pattern "$speed"
            ;;
        rainbow)
            run_rainbow_pattern "$speed"
            ;;
        off)
            run_off_pattern
            ;;
        *)
            # LEARNING: Unknown pattern - default to off
            run_off_pattern
            ;;
    esac
done
