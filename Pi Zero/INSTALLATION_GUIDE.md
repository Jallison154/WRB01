# ESP32 Wireless Button System - Complete Installation Guide

This guide will help you set up the ESP32 Wireless Button System on a new Raspberry Pi from scratch using the GitHub repository.

## 🚀 One-Command Installation

Choose your preferred installation method:

### Option 1: Direct Download and Install (Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/main/Pi%20Zero/install.sh | bash
```

### Option 2: Quick Install Script
```bash
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/main/Pi%20Zero/quick_install.sh | bash
```

### Option 3: Clone and Install
```bash
# Download and run in one command
git clone https://github.com/Jallison154/TheBigWRB.git ~/TheBigWRB && cd ~/TheBigWRB/Pi\ Zero && chmod +x install.sh && ./install.sh
```

**That's it!** The automated installation script will handle everything else including:
- System updates and package installation
- File copying and permissions
- Audio setup and user group configuration
- Default sound file installation (included with the system)
- Systemd service installation and startup
- Automatic error handling (Python environment, audio device access)

**Note**: If you encounter any errors during installation, the script will automatically handle common issues like "externally-managed-environment" and audio device access problems.

Continue reading for detailed manual installation steps if needed.

## 📋 Prerequisites

### Hardware Required
- **Raspberry Pi** (Pi Zero, Pi 3, Pi 4, or Pi 5)
- **2x Seeed Studio XIAO ESP32C3** boards
- **2x Push buttons** (for transmitter)
- **2x LEDs** (for status indicators)
- **Resistors** (220Ω for LEDs)
- **USB drive** (optional, for custom sound files)
- **MicroSD card** (8GB+ for Raspberry Pi)

### Software Required
- **Raspberry Pi OS** (Lite or Desktop)
- **Arduino IDE** with ESP32 board package
- **Python 3.7+**
- **Git** (for cloning the repository)

## 🔧 Hardware Setup

### ESP32 Transmitter
```
D1 (GPIO2)  ←→ Button 1 ←→ GND
D2 (GPIO3)  ←→ Button 2 ←→ GND  
D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
```

### ESP32 Receiver
```
D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
USB         ←→ Raspberry Pi
```

### Raspberry Pi
```
GPIO 23 ←→ Ready LED (220Ω) ←→ 3.3V
GPIO 24 ←→ USB LED (220Ω) ←→ 3.3V
USB     ←→ ESP32 Receiver
```

**Ready LED Behavior (GPIO 23):**
- **Breathing (0-100%)**: System starting up or not ready
- **25% Brightness**: Service running and ready
- **100% Blink**: Button command received (returns to 25%)

## 💻 Software Installation

### Step 1: Raspberry Pi Setup

#### 1.1 Flash Raspberry Pi OS
1. Download **Raspberry Pi Imager**
2. Flash **Raspberry Pi OS Lite** to microSD card
3. Enable SSH and set up WiFi (if needed)
4. Boot the Pi

#### 1.2 Initial System Update
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

#### 1.3 Install System Dependencies
```bash
# Install required system packages
sudo apt install -y python3-pip python3-pygame python3-serial python3-gpiozero sox git

# Install Python packages
pip3 install pygame pyserial gpiozero
```

#### 1.4 Set Audio Permissions
```bash
# Add pi user to audio group
sudo usermod -a -G audio pi

# Test audio (optional)
speaker-test -t wav -c 2
```

### Step 2: ESP32 Setup

#### 2.1 Install Arduino IDE
1. Download Arduino IDE from [arduino.cc](https://arduino.cc)
2. Install ESP32 board package:
   - File → Preferences → Additional Board Manager URLs
   - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Tools → Board → Boards Manager → Search "ESP32" → Install

#### 2.2 Configure ESP32 Boards
1. **Tools → Board → esp32 → XIAO_ESP32C3**
2. **Tools → Port → Select your ESP32 port**
3. **Tools → Upload Speed → 115200**

#### 2.3 Find MAC Addresses
1. Upload the `MAC_Finder.ino` sketch (from the repository root) to both ESP32 boards
2. Open Serial Monitor (115200 baud)
3. Note the MAC addresses displayed

#### 2.4 Flash ESP32 Code
After cloning the repository, upload the ESP32 code:
1. **Transmitter**: Upload `Transmitter/Transmitter ESP32.c`
2. **Receiver**: Upload `Receiver/Receiver ESP32`

## 📁 File Installation

### Step 3: Clone and Install from GitHub

#### 3.1 Clone the Repository
```bash
# Clone the public repository
git clone https://github.com/Jallison154/TheBigWRB.git ~/TheBigWRB

# Navigate to the project directory
cd ~/TheBigWRB
```

**Note**: This is a public repository, so no authentication is required for cloning.

#### 3.2 Create Working Directory
```bash
# Create the working directory for the system
mkdir -p ~/WRB
mkdir -p ~/WRB/sounds
```

#### 3.3 Copy Pi Zero Files
```bash
# Copy all Pi Zero files to working directory
cp Pi\ Zero/PiScript ~/WRB/
cp Pi\ Zero/config.py ~/WRB/
cp Pi\ Zero/monitor_system.py ~/WRB/
cp Pi\ Zero/test_esp32_connection.py ~/WRB/
cp Pi\ Zero/test_system_integration.py ~/WRB/
cp Pi\ Zero/requirements.txt ~/WRB/

# Make scripts executable
chmod +x ~/WRB/PiScript
chmod +x ~/WRB/*.py
```

#### 3.4 Install Python Dependencies
```bash
# Install Python requirements
pip3 install -r ~/WRB/requirements.txt
```

#### 3.5 Copy Service File
```bash
# Copy and install the systemd service
sudo cp "Pi Zero/WRB-enhanced.service" /etc/systemd/system/
sudo systemctl daemon-reload
```

### Alternative: Automated Installation Script

Use the single, comprehensive installation script:

```bash
# Make the installation script executable and run it
chmod +x "Pi Zero/install.sh"
cd "Pi Zero"
./install.sh
```

This script handles everything automatically:
- System updates and package installation
- File copying and permissions
- Audio setup and user group configuration
- Sample sound file creation
- Systemd service installation and startup

### Step 4: Sound Files

#### 4.1 Default Sound Files (Included)
The system comes with default sound files that are automatically installed:
- `button1.wav` - Button 1 quick press sound
- `button2.wav` - Button 2 quick press sound  
- `hold1.wav` - Button 1 hold sound
- `hold2.wav` - Button 2 hold sound

These files are copied to `~/WRB/sounds/` during installation.

#### 4.2 Custom Sound Files (Optional)
You can replace the default files with your own:
- `button1*.wav` - Button 1 quick press sounds
- `button2*.wav` - Button 2 quick press sounds  
- `hold1*.wav` - Button 1 hold sounds
- `hold2*.wav` - Button 2 hold sounds

**File Requirements:**
- Format: WAV files
- Sample Rate: 44100 Hz (recommended)
- Channels: Mono or Stereo
- Bit Depth: 16-bit (recommended)

## ⚙️ Configuration

### Step 5: Configure MAC Addresses

#### 5.1 Update Receiver Code
In `Receiver/Receiver ESP32`, update line 12-15:
```cpp
uint8_t ALLOWED_TX_MACS[][6] = {
  { 0x58,0x8C,0x81,0x9F,0x22,0xAC }, // Your transmitter MAC
  // Add more transmitters as needed
};
```

#### 5.2 Update Transmitter Code  
In `Transmitter/Transmitter ESP32.c`, update line 17:
```cpp
uint8_t RX_MAC[] = { 0x58,0x8C,0x81,0x9E,0x30,0x10 }; // Your receiver MAC
```

#### 5.3 Re-flash ESP32 Boards
After updating MAC addresses, re-upload the code to both boards.

## 🚀 System Startup

### Step 6: Enable and Start Service

#### 6.1 Enable Service
```bash
sudo systemctl enable WRB-enhanced.service
sudo systemctl start WRB-enhanced.service
```

#### 6.2 Check Service Status
```bash
sudo systemctl status WRB-enhanced.service
```

#### 6.3 View Logs
```bash
# Real-time logs
sudo journalctl -u WRB-enhanced.service -f

# Recent logs
sudo journalctl -u WRB-enhanced.service --no-pager
```

## 🧪 Testing

### Step 7: System Testing

#### 7.1 Run Integration Tests
```bash
cd ~/WRB
python3 test_system_integration.py
```

#### 7.2 Test ESP32 Connection
```bash
python3 test_esp32_connection.py
```

#### 7.3 Test USB LED
```bash
python3 test_usb_led.py
```

#### 7.4 Verify Configuration
```bash
python3 verify_configuration.py
```

#### 7.5 Monitor System
```bash
python3 monitor_system.py
```

## 📊 Usage

### Step 8: Using the System

#### 8.1 Manual Testing
```bash
# Run script manually for testing
cd ~/WRB
python3 PiScript
```

#### 8.2 Service Management
```bash
# Start service
sudo systemctl start WRB-enhanced.service

# Stop service  
sudo systemctl stop WRB-enhanced.service

# Restart service
sudo systemctl restart WRB-enhanced.service

# Check status
sudo systemctl status WRB-enhanced.service
```

#### 8.3 Button Operations
- **Quick Press**: Plays button sound
- **Hold (500ms+)**: Plays hold sound
- **LED Feedback**: Visual confirmation of button presses

## 🔧 Troubleshooting

### Common Issues

#### ESP32 Connection Problems
```bash
# Check serial ports
ls /dev/ttyACM* /dev/ttyUSB*

# Test connection
python3 ~/WRB/test_esp32_connection.py
```

#### Audio Issues
```bash
# Test audio system
speaker-test -t wav -c 2

# Check audio devices
aplay -l

# Test with pygame
python3 -c "import pygame; pygame.mixer.init(); print('Audio OK')"
```

#### Service Issues
```bash
# Check service logs
sudo journalctl -u WRB-enhanced.service --no-pager

# Restart service
sudo systemctl restart WRB-enhanced.service
```

#### GPIO Issues
```bash
# Test GPIO
python3 -c "from gpiozero import LED; print('GPIO OK')"

# Check permissions
groups pi
```

## 📁 File Structure

After installation, your system should have this structure:
```
~/WRB/
├── PiScript                    # Main audio script
├── config.py                   # Configuration file
├── monitor_system.py           # System monitoring
├── test_esp32_connection.py    # ESP32 connection test
├── test_system_integration.py  # Integration tests
├── requirements.txt            # Python dependencies
└── sounds/                    # Sound files directory
    ├── button1.wav
    ├── button2.wav
    ├── hold1.wav
    └── hold2.wav
```

### Pi Zero Directory (Source Files)
```
Pi Zero/
├── install.sh                  # Single installation script
├── PiScript                    # Main application
├── config.py                   # Configuration
├── monitor_system.py           # System monitoring
├── test_esp32_connection.py    # ESP32 test
├── test_system_integration.py  # Integration test
├── requirements.txt            # Dependencies
├── WRB-enhanced.service        # Systemd service
├── default_sounds/             # Default audio files
│   ├── button1.wav
│   ├── button2.wav
│   ├── hold1.wav
│   └── hold2.wav
└── INSTALLATION_GUIDE.md       # This guide
```

## 🔄 Updates and Maintenance

### Updating from GitHub
```bash
# Stop service
sudo systemctl stop WRB-enhanced.service

# Update repository
cd ~/TheBigWRB
git pull origin main

# Update working files
cp "Pi Zero/PiScript" ~/WRB/
cp "Pi Zero/config.py" ~/WRB/
cp "Pi Zero/monitor_system.py" ~/WRB/
cp "Pi Zero/test_esp32_connection.py" ~/WRB/
cp "Pi Zero/test_system_integration.py" ~/WRB/
cp "Pi Zero/requirements.txt" ~/WRB/

# Update Python dependencies if needed
pip3 install -r ~/WRB/requirements.txt --upgrade

# Restart service
sudo systemctl start WRB-enhanced.service
```

### Quick Update Script
```bash
# Create a simple update script
cat > ~/WRB/update_system.sh << 'EOF'
#!/bin/bash
echo "Updating ESP32 Wireless Button System..."

# Stop service
sudo systemctl stop WRB-enhanced.service

# Update repository
cd ~/TheBigWRB
git pull origin main

# Update files
cp "Pi Zero/PiScript" ~/WRB/
cp "Pi Zero/config.py" ~/WRB/
cp "Pi Zero/monitor_system.py" ~/WRB/
cp "Pi Zero/test_esp32_connection.py" ~/WRB/
cp "Pi Zero/test_system_integration.py" ~/WRB/
cp "Pi Zero/test_usb_led.py" ~/WRB/
cp "Pi Zero/verify_configuration.py" ~/WRB/
cp "Pi Zero/requirements.txt" ~/WRB/

# Update dependencies
pip3 install -r ~/WRB/requirements.txt --upgrade

# Restart service
sudo systemctl start WRB-enhanced.service

echo "System updated successfully!"
EOF

# Make it executable
chmod +x ~/WRB/update_system.sh

# Run updates with:
# ~/WRB/update_system.sh
```

### Log Management
```bash
# View button logs
tail -f ~/WRB/button_log.txt

# View health logs  
tail -f ~/WRB/health_log.txt

# Clear old logs
sudo journalctl --vacuum-time=7d
```

## 📞 Support

### Useful Commands
```bash
# Service status
sudo systemctl status WRB-enhanced.service

# Real-time logs
sudo journalctl -u WRB-enhanced.service -f

# System monitor
python3 ~/WRB/monitor_system.py

# Integration test
python3 ~/WRB/test_system_integration.py
```

### Configuration Files
- **Systemd Service**: `/etc/systemd/system/WRB-enhanced.service`
- **Main Script**: `~/WRB/PiScript`
- **Configuration**: `~/WRB/config.py`
- **Logs**: `~/WRB/*.txt`

---

## 🔧 Troubleshooting

### Python "Externally Managed Environment" Error

If you encounter this error during installation:
```
error: externally-managed-environment
```

**Solution**: The installation script automatically handles this, but if you need to fix it manually:

```bash
# Run the Python environment fix script
chmod +x fix_python_environment.sh
./fix_python_environment.sh
```

**Or manually install packages via apt:**
```bash
sudo apt install -y python3-pygame python3-serial python3-gpiozero
```

### Service Not Starting

If the WRB-enhanced.service fails to start:

```bash
# Check service status
sudo systemctl status WRB-enhanced.service

# View detailed logs
sudo journalctl -u WRB-enhanced.service -f

# Check if files exist and have correct permissions
ls -la ~/WRB/PiScript
```

### Audio Issues

If you don't hear sounds:

```bash
# Check if user is in audio group
groups $USER

# Test audio device
aplay -l

# Test with a simple sound
speaker-test -t wav -c 2
```

### ESP32 Connection Issues

If the ESP32 receiver isn't detected:

```bash
# Check USB devices
lsusb

# Check serial ports
ls /dev/ttyACM* /dev/ttyUSB*

# Test ESP32 connection
python3 ~/WRB/test_esp32_connection.py
```

---

## ✅ Installation Complete!

Your ESP32 Wireless Button System is now ready to use. The system will automatically start on boot and provide audio feedback for button presses from your ESP32 transmitters.

**Next Steps:**
1. Test button presses on your ESP32 transmitters
2. Monitor the system with `python3 ~/WRB/monitor_system.py`
3. Customize sound files in `~/WRB/sounds/`
4. Add additional transmitters by updating MAC addresses

**Need Help?** Check the troubleshooting section or run the integration tests to diagnose any issues.
