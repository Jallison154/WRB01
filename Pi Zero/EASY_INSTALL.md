# 🚀 Easy Installation - WRB01 Professional Button + Audio System

## One-Command Installation

```bash
# Download and run the easy install script
curl -sSL https://raw.githubusercontent.com/Jallison154/WRB01/WRB01/Pi%20Zero/easy_install.sh | bash
```

**OR if you prefer to download first:**

```bash
# Download the script
wget https://raw.githubusercontent.com/Jallison154/WRB01/WRB01/Pi%20Zero/easy_install.sh
chmod +x easy_install.sh
./easy_install.sh
```

## What the script does:

✅ **Updates system packages**  
✅ **Installs required dependencies** (python3-pygame, python3-serial, python3-numpy, python3-gpiozero, alsa-utils, exfatprogs, ntfs-3g, raspi-gpio)  
✅ **Clones WRB01 repository** from GitHub  
✅ **Creates wrb01 user** with proper permissions  
✅ **Configures USB audio interface** as default  
✅ **Copies audio files** from repository  
✅ **Installs robust Python audio player** with error handling  
✅ **Creates systemd service** for automatic startup  
✅ **Sets up USB auto-mounting** with LED status indicator  
✅ **Starts the service** automatically  

## Key Features Installed:

🎵 **USB Audio Priority** - Automatically uses USB audio interface  
🔄 **Hot-swap Audio** - Change audio files without restart  
💡 **LED Status** - GPIO 18 LED shows system status  
🛡️ **Robust Error Handling** - Continues working even with errors  
🔌 **Multiple Serial Ports** - Automatically detects ESP32  
⚡ **Always-Active Audio** - Mixer stays ready for instant response  
💾 **USB Drive Support** - Automatically detects audio files on USB drives  
🔌 **USB Auto-mounting** - Automatic USB drive mounting with LED status on GPIO 24  
📁 **Multiple Filesystems** - Support for FAT, exFAT, NTFS, and ext* filesystems  

## After Installation:

### Check Status:
```bash
sudo systemctl status wrb-simple.service
```

### View Logs:
```bash
sudo journalctl -u wrb-simple.service -f
```

### Test Button Detection:
```bash
python3 /home/wrb01/test_buttons.py
```

### Check USB Auto-mounting:
```bash
# View USB mount logs
tail -f /var/log/usb-automount.log

# Test USB mounting manually
sudo /usr/local/bin/usb-automount.sh add /dev/sda1
```

### Restart Service:
```bash
sudo systemctl restart wrb-simple.service
```

## Hardware Setup:

1. **Connect ESP32 receiver** to Pi via USB (should appear as `/dev/ttyACM0`)
2. **Connect USB audio interface** to Pi (optional - will use built-in if not available)
3. **Connect LED to GPIO 18** (optional - for system status indication)
4. **Connect LED to GPIO 24** (optional - for USB mount status indication)
5. **Upload ESP32 code** to your transmitter and receiver
6. **Press buttons** to hear audio!

## Audio Files:

The system automatically detects these audio files:
- `button1*.wav` - Button 1 press sounds
- `button2*.wav` - Button 2 press sounds  
- `hold1*.wav` - Button 1 hold sounds
- `hold2*.wav` - Button 2 hold sounds

### File Locations (in priority order):
1. **USB Drives** - Automatically detects audio files on mounted USB drives
2. **Local Directory** - `/home/wrb01/audio/` (fallback)

## LED Status Indicators:

**System Status LED (GPIO 18):**
- **Off** - System not ready
- **On** - System ready and waiting
- **Flash** - Button pressed (activity indicator)

**USB Mount Status LED (GPIO 24):**
- **Off** - No USB drives mounted
- **On** - USB drive mounted and ready
- **Changes automatically** when USB drives are inserted/removed

## Troubleshooting:

### Service not starting:
```bash
sudo journalctl -u wrb-simple.service -f
```

### No audio output:
```bash
# Check audio devices
aplay -l

# Test USB audio
aplay -D plughw:1,0 /home/wrb01/audio/button1.wav
```

### ESP32 not detected:
```bash
# Check serial ports
ls /dev/ttyACM*

# Test button detection
python3 /home/wrb01/test_buttons.py
```

### Missing dependencies:
```bash
sudo apt install python3-gpiozero
```

### USB Auto-mounting Issues:
```bash
# Check USB mount logs
tail -f /var/log/usb-automount.log

# Test USB mounting manually
sudo /usr/local/bin/usb-automount.sh add /dev/sda1

# Check if udev rules are loaded
sudo udevadm control --reload

# Check mounted USB drives
ls -la /media/
```

## Advanced Features:

### Hot-swap Audio:
- Insert USB drive with new audio files
- System automatically detects and uses new files
- No restart required

### Multiple Audio Sources:
- USB drives (priority)
- Local directory (fallback)
- Automatic file pattern matching

### Robust Error Handling:
- Continues working even with audio errors
- Automatic serial port detection
- Idle power saving

### USB Auto-mounting:
- **Automatic Detection** - USB drives mounted automatically when inserted
- **LED Status** - GPIO 24 LED shows mount status (ON=mounted, OFF=unmounted)
- **Multiple Filesystems** - Support for FAT, exFAT, NTFS, and ext* filesystems
- **Hot-swap Support** - Change USB drives without restarting system
- **Audio File Detection** - Automatically finds audio files on mounted USB drives
- **Permission Management** - USB drives mounted with proper user permissions

## That's it! 🎯

Your WRB01 Professional Button + Audio System with USB auto-mounting will be running automatically with robust error handling, professional audio features, and automatic USB drive support!
