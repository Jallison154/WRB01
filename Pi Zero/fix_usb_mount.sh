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
set -e
ACTION="$1"; DEV="$2"
PI_USER="wrb01"; PI_UID="$(id -u $PI_USER)"; PI_GID="$(id -g $PI_USER)"

# LED Control (GPIO 24, active-low)
MOUNT_LED_PIN=24
led_control() {
    local state=$1
    # Use sysfs for better compatibility and reliability
    if [ ! -d "/sys/class/gpio/gpio${MOUNT_LED_PIN}" ]; then
        echo "${MOUNT_LED_PIN}" > /sys/class/gpio/export 2>/dev/null || true
        sleep 0.1
        echo "out" > /sys/class/gpio/gpio${MOUNT_LED_PIN}/direction 2>/dev/null || true
    fi
    
    if [ "$state" = "on" ]; then
        # Active low = 0 for ON
        echo 0 > /sys/class/gpio/gpio${MOUNT_LED_PIN}/value 2>/dev/null || true
    else
        # Active low = 1 for OFF
        echo 1 > /sys/class/gpio/gpio${MOUNT_LED_PIN}/value 2>/dev/null || true
    fi
}

[ -z "$DEV" ] && exit 0

case "$ACTION" in
  add)
    LABEL="$(blkid -o value -s LABEL "$DEV" 2>/dev/null || true)"
    [ -z "$LABEL" ] && LABEL="usb-$(basename $DEV)"
    FSTYPE="$(blkid -o value -s TYPE "$DEV" 2>/dev/null || true)"
    MNT="/media/$LABEL"
    
    # Clean up any existing mount or stale mount point
    if mountpoint -q "$MNT" 2>/dev/null; then
        umount -l "$MNT" 2>/dev/null || true
        sleep 0.2
    fi
    rmdir "$MNT" 2>/dev/null || true
    
    # Create fresh mount point
    mkdir -p "$MNT"
    chown "$PI_USER:$PI_USER" "$MNT"
    
    # Mount with appropriate options
    OPTS="uid=$PI_UID,gid=$PI_GID,umask=002,noatime,nosuid,nodev"
    if [ "$FSTYPE" = "ntfs" ] && command -v ntfs-3g >/dev/null; then
        mount -t ntfs-3g -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
    elif [ "$FSTYPE" = "exfat" ] && command -v mount.exfat >/dev/null; then
        mount -t exfat -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
    else
        mount -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
    fi
    
    # Turn on LED
    led_control on
    
    echo "[usb-automount] $(date): Mounted $DEV at $MNT (LED ON)" >> /var/log/usb-automount.log
    ;;
    
  remove)
    # Find and unmount all partitions of this device
    for MP in $(awk -v dev="$DEV" '$1==dev {print $2}' /proc/mounts); do
        umount -l "$MP" 2>/dev/null || true
        rmdir "$MP" 2>/dev/null || true
    done
    
    # Also check for matching device base (for unpartitioned drives)
    BASE_DEV=$(echo $DEV | sed 's/[0-9]*$//')
    for MP in $(awk -v base="$BASE_DEV" '$1~base {print $2}' /proc/mounts); do
        umount -l "$MP" 2>/dev/null || true
        rmdir "$MP" 2>/dev/null || true
    done
    
    # Turn off LED
    led_control off
    
    echo "[usb-automount] $(date): Unmounted $DEV (LED OFF)" >> /var/log/usb-automount.log
    ;;
esac
EOF
chmod +x /usr/local/bin/usb-automount.sh
echo "   ✓ USB auto-mount script updated"

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
