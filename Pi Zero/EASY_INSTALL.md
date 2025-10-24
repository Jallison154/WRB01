# 🚀 Easy Installation - WRB01 Simple Button + Audio System

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
✅ **Installs required dependencies** (python3-pygame, python3-serial, python3-numpy, alsa-utils)  
✅ **Clones WRB01 repository** from GitHub  
✅ **Creates wrb01 user** with proper permissions  
✅ **Configures USB audio interface**  
✅ **Copies audio files** from repository  
✅ **Installs Python audio player**  
✅ **Creates systemd service** for automatic startup  
✅ **Starts the service** automatically  

## After Installation:

### Check Status:
```bash
sudo systemctl status wrb-simple.service
```

### View Logs:
```bash
sudo journalctl -u wrb-simple.service -f
```

### Restart Service:
```bash
sudo systemctl restart wrb-simple.service
```

## Hardware Setup:

1. **Connect ESP32 receiver** to Pi via USB (should appear as `/dev/ttyACM0`)
2. **Connect USB audio interface** to Pi
3. **Upload ESP32 code** to your transmitter and receiver
4. **Press buttons** to hear audio!

## Audio Files:

The system uses these audio files from the repository:
- `button1.wav` - Button 1 press sound
- `button2.wav` - Button 2 press sound  
- `hold1.wav` - Button 1 hold sound
- `hold2.wav` - Button 2 hold sound

## Troubleshooting:

### Service not starting:
```bash
sudo journalctl -u wrb-simple.service -f
```

### No audio output:
```bash
# Check USB audio device
aplay -l
```

### ESP32 not detected:
```bash
# Check serial ports
ls /dev/ttyACM*
```

## That's it! 🎯

Your WRB01 Simple Button + Audio System will be running automatically after installation!
