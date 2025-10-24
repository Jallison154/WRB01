# WRB Simple Button + Audio System

Robust ESP32 button control with professional audio playback system.

## Features
- **USB Audio Priority** - Automatically uses USB audio interface when available
- **Hot-swap Audio** - Can change audio files without restarting
- **LED Status** - GPIO 18 LED shows system status and activity
- **Robust Error Handling** - Continues working even with errors
- **Multiple Serial Ports** - Automatically detects ESP32 connection
- **Always-Active Audio** - Mixer stays ready for instant response
- **USB Drive Support** - Automatically detects audio files on USB drives

## Files
- `ESP32_Simple_Button.ino` - ESP32 code
- `simple_audio_player.py` - Robust Pi audio player
- `easy_install.sh` - One-command installation script
- `button1.wav`, `button2.wav` - Button press audio files
- `hold1.wav`, `hold2.wav` - Button hold audio files

## Quick Installation

### One-Command Install
```bash
curl -sSL https://raw.githubusercontent.com/Jallison154/WRB01/WRB01/Pi%20Zero/easy_install.sh | bash
```

### Manual Installation
```bash
git clone https://github.com/Jallison154/WRB01.git ~/WRB01
cd ~/WRB01/Pi\ Zero
chmod +x easy_install.sh
./easy_install.sh
```

## Hardware Setup

### ESP32
1. Upload `Receiver_ESP32_Working.ino` to receiver ESP32
2. Upload `Transmitter_ESP32_Working.ino` to transmitter ESP32
3. Connect receiver ESP32 to Pi via USB
4. Connect transmitter ESP32 to buttons

### Pi
1. Connect USB audio interface (optional - will use built-in if not available)
2. Connect LED to GPIO 18 (optional - for status indication)
3. Run installation script

## Audio File Support

### File Locations (in priority order):
1. **USB Drives** - Automatically detects audio files on mounted USB drives
2. **Local Directory** - `/home/wrb01/audio/` (fallback)

### Supported File Patterns:
- `button1*.wav` - Button 1 press sounds
- `button2*.wav` - Button 2 press sounds  
- `hold1*.wav` - Button 1 hold sounds
- `hold2*.wav` - Button 2 hold sounds

### Hot-swap Support:
- Insert USB drive with new audio files
- System automatically detects and uses new files
- No restart required

## How It Works
1. **ESP32 Transmitter** → Sends ESP-NOW to receiver
2. **ESP32 Receiver** → Outputs `BTN1`, `BTN2`, `HOLD1`, `HOLD2` via serial
3. **Pi Audio Player** → Reads serial, plays corresponding audio file
4. **Audio Output** → Plays through USB audio interface (or built-in)

## System Management

### Service Commands
```bash
# Check status
sudo systemctl status wrb-simple.service

# View logs
sudo journalctl -u wrb-simple.service -f

# Restart service
sudo systemctl restart wrb-simple.service

# Stop/start service
sudo systemctl stop wrb-simple.service
sudo systemctl start wrb-simple.service
```

### Testing
```bash
# Test button detection
python3 /home/wrb01/test_buttons.py

# Test audio files
aplay /home/wrb01/audio/button1.wav
```

## LED Status Indicator
- **GPIO 18** - System status LED
- **Off** - System not ready
- **On** - System ready and waiting
- **Flash** - Button pressed (activity indicator)

## Troubleshooting

### No Audio Output
```bash
# Check audio devices
aplay -l

# Test USB audio
aplay -D plughw:1,0 /home/wrb01/audio/button1.wav
```

### ESP32 Not Detected
```bash
# Check serial ports
ls /dev/ttyACM*

# Check service logs
sudo journalctl -u wrb-simple.service -f
```

### Service Not Starting
```bash
# Check service status
sudo systemctl status wrb-simple.service

# Check dependencies
sudo apt install python3-gpiozero
```

## Advanced Configuration

### Environment Variables
- `WRB_SERIAL` - Serial port (default: `/dev/ttyACM0`)
- `SDL_AUDIODRIVER` - Audio driver (default: `alsa`)
- `AUDIODEV` - Audio device (default: `plughw:1,0`)

### Audio Configuration
- **Primary**: USB audio interface (card 1, device 0)
- **Fallback**: Built-in audio (card 0, device 0)
- **Sample Rate**: 44100 Hz
- **Channels**: Stereo (2-channel)
- **Buffer Size**: 256 samples

**Professional wireless button system with robust audio handling!** 🎯
