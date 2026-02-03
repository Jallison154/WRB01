#!/bin/bash
# Install USB auto-mount script and udev rules
# This fixes the missing USB auto-mount components

echo "=== Installing USB Auto-mount Components ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Create USB auto-mount script
echo "1. Creating USB auto-mount script..."
mkdir -p /usr/local/bin
tee /usr/local/bin/usb-automount.sh > /dev/null << 'EOF'
#!/bin/bash
ACTION="$1"
DEV="$2"
PI_USER="wrb01"
PI_UID=$(id -u "$PI_USER" 2>/dev/null || echo "1000")
PI_GID=$(id -g "$PI_USER" 2>/dev/null || echo "1000")

[ -z "$DEV" ] && exit 0

# Create log file
mkdir -p /var/log
LOG="/var/log/usb-automount.log"

case "$ACTION" in
  add)
    # Get filesystem info
    LABEL=$(blkid -o value -s LABEL "$DEV" 2>/dev/null || echo "")
    FSTYPE=$(blkid -o value -s TYPE "$DEV" 2>/dev/null || echo "")
    
    # Generate label if not found
    if [ -z "$LABEL" ]; then
        LABEL="usb-$(basename $DEV)"
    fi
    
    MNT="/media/$LABEL"
    
    # Clean up any existing mount
    if mountpoint -q "$MNT" 2>/dev/null; then
        umount -l "$MNT" 2>/dev/null || true
        sleep 0.2
    fi
    rmdir "$MNT" 2>/dev/null || true
    
    # Create mount point
    mkdir -p "$MNT" 2>/dev/null || true
    chown "$PI_USER:$PI_USER" "$MNT" 2>/dev/null || true
    
    # Mount with appropriate options
    OPTS="uid=$PI_UID,gid=$PI_GID,umask=002,noatime,nosuid,nodev"
    
    echo "$(date): Attempting to mount $DEV (type: ${FSTYPE:-unknown})" >> "$LOG"
    
    if [ "$FSTYPE" = "ntfs" ] && command -v ntfs-3g >/dev/null 2>&1; then
        mount -t ntfs-3g -o "$OPTS" "$DEV" "$MNT" >> "$LOG" 2>&1
        MOUNT_SUCCESS=$?
    elif [ "$FSTYPE" = "exfat" ] && command -v mount.exfat >/dev/null 2>&1; then
        mount -t exfat -o "$OPTS" "$DEV" "$MNT" >> "$LOG" 2>&1
        MOUNT_SUCCESS=$?
    else
        mount -o "$OPTS" "$DEV" "$MNT" >> "$LOG" 2>&1
        MOUNT_SUCCESS=$?
    fi
    
    if [ $MOUNT_SUCCESS -eq 0 ]; then
        echo "$(date): Successfully mounted $DEV at $MNT" >> "$LOG"
    else
        echo "$(date): FAILED to mount $DEV" >> "$LOG"
    fi
    ;;
    
  remove)
    # Find and unmount all partitions of this device
    for mnt in /media/*; do
        if mountpoint -q "$mnt" 2>/dev/null; then
            dev=$(mount | grep "$mnt" | awk '{print $1}')
            if echo "$dev" | grep -q "$(basename $DEV)"; then
                echo "$(date): Unmounting $mnt" >> "$LOG"
                umount -l "$mnt" 2>/dev/null || true
                rmdir "$mnt" 2>/dev/null || true
            fi
        fi
    done
    ;;
esac

exit 0
EOF

chmod +x /usr/local/bin/usb-automount.sh
echo "   ✓ USB auto-mount script installed"

# Create udev rule
echo "2. Creating udev rule..."
mkdir -p /etc/udev/rules.d
tee /etc/udev/rules.d/99-usb-automount.rules > /dev/null << 'EOF'
# USB Auto-mount rule for WRB system
# Mount USB drives automatically when inserted

# Match USB block devices (not partitions)
KERNEL=="sd[a-z]", ACTION=="add", RUN+="/usr/local/bin/usb-automount.sh add /dev/%k"
KERNEL=="sd[a-z][0-9]*", ACTION=="add", RUN+="/usr/local/bin/usb-automount.sh add /dev/%k"

# Unmount when removed
KERNEL=="sd[a-z]", ACTION=="remove", RUN+="/usr/local/bin/usb-automount.sh remove /dev/%k"
KERNEL=="sd[a-z][0-9]*", ACTION=="remove", RUN+="/usr/local/bin/usb-automount.sh remove /dev/%k"
EOF

echo "   ✓ udev rule installed"

# Create log file
echo "3. Creating log file..."
mkdir -p /var/log
touch /var/log/usb-automount.log
chmod 644 /var/log/usb-automount.log
echo "   ✓ Log file created"

# Reload udev rules
echo "4. Reloading udev rules..."
udevadm control --reload
udevadm trigger
echo "   ✓ udev rules reloaded"

echo
echo "=== USB Auto-mount Installation Complete ==="
echo
echo "Components installed:"
echo "  ✓ /usr/local/bin/usb-automount.sh"
echo "  ✓ /etc/udev/rules.d/99-usb-automount.rules"
echo "  ✓ /var/log/usb-automount.log"
echo
echo "USB drives will now be automatically mounted to /media/<label>"
echo "View logs: tail -f /var/log/usb-automount.log"
