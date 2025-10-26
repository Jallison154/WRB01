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
    # Check /proc/mounts directly for any sda, sdb, etc. mounts
    if grep -qE '\b/dev/sd[a-z][0-9]+' /proc/mounts 2>/dev/null; then
        return 0  # At least one USB drive is mounted
    else
        return 1  # No USB drives mounted
    fi
}

# LED Control using Python gpiozero (same as simple_audio_player.py)
update_led_status() {
    local mount_status
    local delay=0.5
    
    # Longer delay to ensure mount/unmount is fully complete
    sleep $delay
    
    check_usb_mounted
    mount_status=$?
    
    # Log the check for debugging
    echo "[usb-automount] $(date): USB mounted check result: $mount_status" >> /var/log/usb-automount.log
    grep -E '\b/dev/sd[a-z][0-9]+' /proc/mounts 2>/dev/null >> /var/log/usb-automount.log || true
    
    if [ $mount_status -eq 0 ]; then
        /usr/bin/python3 /usr/local/bin/usb_led_control.py on 2>&1 | tee -a /var/log/usb-automount.log
    else
        /usr/bin/python3 /usr/local/bin/usb_led_control.py off 2>&1 | tee -a /var/log/usb-automount.log
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
        # Update LED based on whether any USB drives are mounted (includes delay)
        update_led_status
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
    # Update LED based on whether any USB drives are still mounted (includes delay)
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
Controls GPIO 24 LED for USB mount status using gpiozero
Matches the pattern used in simple_audio_player.py
"""
import sys
from gpiozero import LED

# GPIO 24, active-low (same as READY_PIN pattern in simple_audio_player.py)
MOUNT_LED_PIN = 24
ACTIVE_LOW = True

def set_led(state):
    """Set LED state: 'on' or 'off'"""
    try:
        # Create LED object each call (gpiozero handles cleanup)
        led = LED(MOUNT_LED_PIN, active_high=not ACTIVE_LOW)
        
        if state == "on":
            led.on()
            print(f"LED ON (GPIO {MOUNT_LED_PIN})")
        elif state == "off":
            led.off()
            print(f"LED OFF (GPIO {MOUNT_LED_PIN})")
        else:
            print(f"Invalid state: {state}")
            return 1
        
        # Keep LED object alive briefly to ensure command is processed
        import time
        time.sleep(0.1)
        return 0
    except Exception as e:
        print(f"Error controlling LED: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: usb_led_control.py <on|off>")
        sys.exit(1)
    
    state = sys.argv[1].lower()
    sys.exit(set_led(state))
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
