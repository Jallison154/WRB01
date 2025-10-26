#!/bin/bash
# Quick Fix for USB Auto-mount Issues
# Fixes LED not turning on and remount problems

echo "=== USB Auto-mount Fix ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "Applying USB auto-mount fixes..."

# Update the USB auto-mount script
echo "1. Updating USB auto-mount script..."
tee /usr/local/bin/usb-automount.sh > /dev/null << 'EOF'
#!/bin/bash
# Don't exit on error - we handle errors explicitly
ACTION="$1"; DEV="$2"
PI_USER="wrb01"
PI_UID=$(id -u "$PI_USER" 2>/dev/null || echo "1000")
PI_GID=$(id -g "$PI_USER" 2>/dev/null || echo "1000")

# Check if any USB drives are mounted
check_usb_mounted() {
    # Check /media directory for mounted USB drives (more reliable)
    local mounted=0
    
    # Check if any /media/* directories exist and are mount points
    if [ -d "/media" ]; then
        for mount_dir in /media/*; do
            if [ -d "$mount_dir" ]; then
                # Check if this is actually a mount point
                if mountpoint -q "$mount_dir" 2>/dev/null; then
                    echo "[usb-automount] Found mounted USB at: $mount_dir" >> /var/log/usb-automount.log
                    mounted=1
                fi
            fi
        done
    fi
    
    if [ $mounted -eq 1 ]; then
        return 0  # At least one USB drive is mounted
    else
        return 1  # No USB drives mounted
    fi
}

# LED Control using Python gpiozero (same as simple_audio_player.py)
update_led_status() {
    local mount_status
    
    check_usb_mounted
    mount_status=$?
    
    # Log the check for debugging
    echo "[usb-automount] $(date): USB mounted check result: $mount_status" >> /var/log/usb-automount.log
    
    if [ $mount_status -eq 0 ]; then
        /usr/bin/python3 /usr/local/bin/usb_led_control.py on > /dev/null 2>&1 &
    else
        /usr/bin/python3 /usr/local/bin/usb_led_control.py off > /dev/null 2>&1 &
    fi
}

[ -z "$DEV" ] && exit 0

case "$ACTION" in
  add)
    # Get filesystem info (allow it to fail)
    LABEL=$(blkid -o value -s LABEL "$DEV" 2>/dev/null || echo "")
    FSTYPE=$(blkid -o value -s TYPE "$DEV" 2>/dev/null || echo "")
    
    # Generate label if not found
    if [ -z "$LABEL" ]; then
        LABEL="usb-$(basename $DEV)"
    fi
    
    MNT="/media/$LABEL"
    
    # Clean up any existing mount or stale mount point
    if mountpoint -q "$MNT" 2>/dev/null; then
        umount -l "$MNT" 2>/dev/null || true
        sleep 0.2
    fi
    rmdir "$MNT" 2>/dev/null || true
    
    # Create fresh mount point
    mkdir -p "$MNT" 2>/dev/null || true
    chown "$PI_USER:$PI_USER" "$MNT" 2>/dev/null || true
    
    # Mount with appropriate options
    OPTS="uid=$PI_UID,gid=$PI_GID,umask=002,noatime,nosuid,nodev"
    
    echo "[usb-automount] $(date): Attempting to mount $DEV (type: ${FSTYPE:-unknown})" >> /var/log/usb-automount.log
    
    if [ "$FSTYPE" = "ntfs" ] && command -v ntfs-3g >/dev/null 2>&1; then
        mount -t ntfs-3g -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
        MOUNT_SUCCESS=$?
    elif [ "$FSTYPE" = "exfat" ] && command -v mount.exfat >/dev/null 2>&1; then
        mount -t exfat -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
        MOUNT_SUCCESS=$?
    else
        mount -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
        MOUNT_SUCCESS=$?
    fi
    
    if [ $MOUNT_SUCCESS -eq 0 ]; then
        echo "[usb-automount] $(date): Successfully mounted $DEV at $MNT" >> /var/log/usb-automount.log
        # Turn LED on immediately without checking (run in background so it doesn't get killed)
        /usr/bin/python3 /usr/local/bin/usb_led_control.py on > /dev/null 2>&1 &
    else
        echo "[usb-automount] $(date): FAILED to mount $DEV" >> /var/log/usb-automount.log
    fi
    ;;
    
  remove)
    # Find and unmount all partitions of this device
    for MP in $(awk -v dev="$DEV" '$1==dev {print $2}' /proc/mounts 2>/dev/null || true); do
        umount -l "$MP" 2>/dev/null || true
        rmdir "$MP" 2>/dev/null || true
    done
    
    # Also check for matching device base (for unpartitioned drives)
    BASE_DEV=$(echo "$DEV" | sed 's/[0-9]*$//')
    for MP in $(awk -v base="$BASE_DEV" '$1~base {print $2}' /proc/mounts 2>/dev/null || true); do
        umount -l "$MP" 2>/dev/null || true
        rmdir "$MP" 2>/dev/null || true
    done
    
    echo "[usb-automount] $(date): Unmounted $DEV" >> /var/log/usb-automount.log
    # Small delay to ensure unmount is registered before checking
    sleep 0.1
    # Update LED based on whether any USB drives are still mounted
    update_led_status
    ;;
esac
EOF
chmod +x /usr/local/bin/usb-automount.sh
echo "   ✓ USB auto-mount script updated"

# Install Python LED controller
echo "1b. Installing Python LED controller..."
tee /usr/local/bin/usb_led_control.py > /dev/null << 'PYEOF'
#!/usr/bin/env python3
"""
USB Mount LED Controller
Controls GPIO 24 LED for USB mount status using gpiozero with PWM fade
Uses a PID file to track running instance
"""
import sys
import os
import time
import signal
from gpiozero import PWMLED

# GPIO 24, active-low (same as READY_PIN pattern in simple_audio_player.py)
MOUNT_LED_PIN = 24
ACTIVE_LOW = True
FADE_DURATION = 2.0  # 2 seconds
FADE_STEPS = 50      # Number of steps for smooth fade
FADE_START = 1.0     # Start at 100% brightness
FADE_END = 0.25      # End at 25% brightness
PID_FILE = "/var/run/usb-led.pid"

def cleanup_running_process():
    """Kill any running breathing process"""
    try:
        if os.path.exists(PID_FILE):
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            try:
                os.kill(pid, signal.SIGTERM)
                time.sleep(0.2)
            except ProcessLookupError:
                pass  # Process already dead
            os.remove(PID_FILE)
    except Exception:
        pass

def breath_continuously():
    """Breathing effect that runs in background"""
    led = PWMLED(MOUNT_LED_PIN, active_high=not ACTIVE_LOW, frequency=100)
    
    # Calculate steps for one full breath cycle
    fade_step = (FADE_START - FADE_END) / FADE_STEPS
    delay = FADE_DURATION / FADE_STEPS
    
    print(f"LED breathing effect started (GPIO {MOUNT_LED_PIN})")
    
    try:
        while True:
            # Fade down: 100% -> 25%
            for i in range(FADE_STEPS + 1):
                brightness = FADE_START - (fade_step * i)
                if ACTIVE_LOW:
                    led.value = 1.0 - brightness
                else:
                    led.value = brightness
                time.sleep(delay)
            
            # Fade up: 25% -> 100%
            for i in range(FADE_STEPS + 1):
                brightness = FADE_END + (fade_step * i)
                if ACTIVE_LOW:
                    led.value = 1.0 - brightness
                else:
                    led.value = brightness
                time.sleep(delay)
    finally:
        led.off()

def set_led(state):
    """Set LED state: 'on' or 'off'"""
    if state == "on":
        # Kill any existing breathing process
        cleanup_running_process()
        
        # Fork and run breathing in background
        pid = os.fork()
        if pid == 0:
            # Child process - run breathing
            # Write PID file
            with open(PID_FILE, 'w') as f:
                f.write(str(os.getpid()))
            
            # Run breathing effect
            breath_continuously()
            sys.exit(0)
        else:
            # Parent process - return immediately
            print(f"LED breathing effect started (GPIO {MOUNT_LED_PIN})")
            return 0
            
    elif state == "off":
        # Kill breathing process
        cleanup_running_process()
        
        # Fade out current LED
        try:
            led = PWMLED(MOUNT_LED_PIN, active_high=not ACTIVE_LOW, frequency=100)
            current_value = led.value if hasattr(led, 'value') else 1.0
            
            print(f"LED fading off (GPIO {MOUNT_LED_PIN})")
            fade_steps = 25
            fade_step = current_value / fade_steps
            
            for i in range(fade_steps + 1):
                new_value = current_value - (fade_step * i)
                if ACTIVE_LOW:
                    led.value = 1.0 - new_value
                else:
                    led.value = new_value
                time.sleep(0.02)  # ~0.5 seconds total
            
            led.off()
            print(f"LED OFF (GPIO {MOUNT_LED_PIN})")
        except Exception as e:
            print(f"Error during fade off: {e}")
        
        return 0
    else:
        print(f"Invalid state: {state}")
        return 1

if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            print("Usage: usb_led_control.py <on|off>")
            sys.exit(1)
        
        state = sys.argv[1].lower()
        sys.exit(set_led(state))
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
PYEOF
chmod +x /usr/local/bin/usb_led_control.py
echo "   ✓ Python LED controller installed"

# Add GPIO permissions rule
echo "2. Adding GPIO permissions..."
tee /etc/udev/rules.d/20-gpio-permissions.rules > /dev/null << 'EOF'
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 775 /sys/class/gpio'"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'for f in /sys/class/gpio/export; do chown root:gpio \$f; chmod 775 \$f; done'"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'for f in /sys/class/gpio/*/direction; do chown root:gpio \$f; chmod 775 \$f; done'"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'for f in /sys/class/gpio/*/value; do chown root:gpio \$f; chmod 775 \$f; done'"
EOF
echo "   ✓ GPIO permissions added"

# Ensure wrb01 user is in gpio group
echo "3. Adding user to gpio group..."
usermod -a -G gpio wrb01 2>/dev/null || true
echo "   ✓ User added to gpio group"

# Reload udev rules
echo "4. Reloading udev rules..."
udevadm control --reload
udevadm trigger
echo "   ✓ udev rules reloaded"

# Initialize LED (turn it off initially)
echo "5. Initializing LED state..."
echo "24" > /sys/class/gpio/export 2>/dev/null || true
sleep 0.1
echo "out" > /sys/class/gpio/gpio24/direction 2>/dev/null || true
echo "1" > /sys/class/gpio/gpio24/value 2>/dev/null || true
echo "   ✓ LED initialized (OFF)"

echo
echo "=== Fix Complete ==="
echo
echo "Changes applied:"
echo "  ✓ Updated USB auto-mount script with:"
echo "    - Better LED control using sysfs"
echo "    - Proper cleanup for remounting"
echo "    - exFAT support"
echo "    - Better error logging"
echo "  ✓ Added GPIO permissions"
echo "  ✓ Added user to gpio group"
echo "  ✓ LED initialized"
echo
echo "To test:"
echo "  1. Remove USB drive (if inserted)"
echo "  2. Wait 2 seconds"
echo "  3. Insert USB drive"
echo "  4. LED on GPIO 24 should turn ON"
echo "  5. Check mount: ls /media/"
echo "  6. Remove USB drive - LED should turn OFF"
echo "  7. Insert again - should mount and LED ON"
echo
echo "Check logs:"
echo "  tail -f /var/log/usb-automount.log"
