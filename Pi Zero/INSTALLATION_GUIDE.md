# WRB Enhanced Audio System - Installation Guide

This guide provides step-by-step instructions for installing and configuring the WRB Enhanced Audio System on your Raspberry Pi.

## 📋 Prerequisites

### Hardware Requirements
- **Raspberry Pi** (Zero, 3, 4, or 5)
- **MicroSD card** (8GB+ recommended)
- **ESP32 devices** (Seeed Studio XIAO ESP32C3)
- **Push buttons** and **LEDs** for ESP32 setup
- **USB drive** (optional, for custom sound files)

### Software Requirements
- **Raspberry Pi OS** (Lite or Desktop)
- **Internet connection** for installation
- **Arduino IDE** (for ESP32 programming)

## 🚀 Quick Installation

### One-Command Installation (Recommended)

```bash
# Install WRB system
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/Update-1.0/Pi%20Zero/install.sh | bash
```

This command will:
- Update your system packages
- Install all required dependencies
- Download and configure the WRB system
- Set up the systemd service
- Create default sound files
- Enable automatic startup

### Alternative Installation Methods

#### Method 1: Direct Download
```bash
# Download and run installation script
wget -O install.sh https://raw.githubusercontent.com/Jallison154/TheBigWRB/Update-1.0/Pi%20Zero/install.sh
chmod +x install.sh
./install.sh
```

#### Method 2: Git Clone
```bash
# Clone repository and install
git clone -b Update-1.0 https://github.com/Jallison154/TheBigWRB.git ~/TheBigWRB
cd ~/TheBigWRB/Pi\ Zero
chmod +x install.sh
./install.sh
```

## 🔧 Manual Installation

If you prefer to install manually or need to troubleshoot:

### Step 1: System Update
```bash
sudo apt update
sudo apt upgrade -y
```

### Step 2: Install Dependencies
```bash
# Install essential packages
sudo apt install -y python3 python3-pip python3-dev python3-pygame python3-serial python3-numpy git curl wget unzip

# Install audio packages
sudo apt install -y alsa-utils pulseaudio pulseaudio-utils libasound2-dev portaudio19-dev

# Install Python packages
pip3 install --user pygame pyserial numpy RPi.GPIO
```

### Step 3: Create Directories
```bash
# Create WRB directories
mkdir -p ~/WRB/{logs,sounds,default_sounds}
```

### Step 4: Download Files
```bash
# Clone repository
git clone -b Update-1.0 https://github.com/Jallison154/TheBigWRB.git ~/TheBigWRB

# Copy files
cp ~/TheBigWRB/Pi\ Zero/PiScript ~/WRB/
cp ~/TheBigWRB/Pi\ Zero/config.py ~/WRB/
chmod +x ~/WRB/PiScript
```

### Step 5: Setup Audio System
```bash
# Add user to audio group
sudo usermod -a -G audio $USER

# Configure ALSA
cat > ~/.asoundrc << EOF
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
EOF
```

### Step 6: Create Service
```bash
# Create systemd service file
sudo tee /etc/systemd/system/WRB-enhanced.service > /dev/null << EOF
[Unit]
Description=WRB Enhanced Audio System
After=network.target sound.target
Wants=network.target sound.target

[Service]
Type=simple
User=$USER
Group=audio
WorkingDirectory=$HOME/WRB
Environment=HOME=$HOME
Environment=USER=$USER
ExecStart=/usr/bin/python3 $HOME/WRB/PiScript
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable WRB-enhanced.service
sudo systemctl start WRB-enhanced.service
```

## 🔧 ESP32 Setup

### Step 1: Install Arduino IDE
1. Download Arduino IDE from https://www.arduino.cc/en/software
2. Install ESP32 board package:
   - Go to File → Preferences
   - Add this URL to Additional Board Manager URLs:
     `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Go to Tools → Board → Boards Manager
   - Search for "ESP32" and install "ESP32 by Espressif Systems"

### Step 2: Configure ESP32 Boards
1. Select your ESP32 board: Tools → Board → ESP32 Arduino → XIAO_ESP32C3
2. Set upload speed to 921600
3. Set CPU frequency to 160MHz

### Step 3: Find MAC Addresses
1. Upload `MAC_Finder.ino` to your ESP32 devices
2. Open Serial Monitor (115200 baud)
3. Note the MAC addresses displayed

### Step 4: Configure Transmitter
1. Open `Transmitter/Transmitter_ESP32.ino`
2. Update the receiver MAC address:
   ```cpp
   uint8_t RX_MAC[] = { 0x58, 0x8C, 0x81, 0x9E, 0x30, 0x10 }; // Your receiver MAC
   ```
3. Upload to your transmitter ESP32

### Step 5: Configure Receiver
1. Open `Receiver/Receiver_ESP32.ino`
2. Update the allowed transmitter MACs:
   ```cpp
   uint8_t ALLOWED_TX_MACS[][6] = {
     { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAC }, // Your transmitter MAC
   };
   ```
3. Upload to your receiver ESP32

## 🔧 Hardware Connections

### ESP32 Transmitter
```
ESP32 XIAO ESP32C3:
├── D1 (GPIO2)  ←→ Button 1 ←→ GND
├── D2 (GPIO3)  ←→ Button 2 ←→ GND
├── D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
└── USB ←→ Power/Programming
```

### ESP32 Receiver
```
ESP32 XIAO ESP32C3:
├── D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
├── USB ←→ Raspberry Pi (Serial)
└── Power ←→ USB or Battery
```

### Raspberry Pi GPIO
```
Raspberry Pi:
├── GPIO 23 ←→ Ready LED (220Ω) ←→ 3.3V
├── GPIO 24 ←→ USB LED (220Ω) ←→ 3.3V
├── USB ←→ ESP32 Receiver (Serial)
└── 3.3V/GND ←→ LED Power
```

## 🎵 Sound File Setup

### Default Sounds
The system comes with default test sounds. To use custom sounds:

1. **Create sound files** in WAV format (44.1kHz, 16-bit recommended)
2. **Name files** according to this convention:
   - `button1*.wav` - Button 1 quick press
   - `button2*.wav` - Button 2 quick press
   - `hold1*.wav` - Button 1 hold
   - `hold2*.wav` - Button 2 hold

### USB Drive Support
1. **Insert USB drive** with sound files
2. **System automatically detects** and loads sounds
3. **LED indicator** shows USB drive status

### Local Sound Files
Place custom sounds in `~/WRB/sounds/` directory.

## 🔧 Configuration

### System Configuration
Edit `~/WRB/config.py` to customize:
- Serial port settings
- GPIO pin assignments
- Audio settings
- Timing parameters

### Service Configuration
The systemd service runs automatically. To manage it:

```bash
# Check status
sudo systemctl status WRB-enhanced.service

# Start/stop service
sudo systemctl start WRB-enhanced.service
sudo systemctl stop WRB-enhanced.service

# Restart service
sudo systemctl restart WRB-enhanced.service

# View logs
sudo journalctl -u WRB-enhanced.service -f
```

## 🧪 Testing and Verification

### Run System Tests
```bash
# Test all components
python3 ~/WRB/test_system.py

# Test specific components
python3 ~/WRB/test_system.py audio
python3 ~/WRB/test_system.py gpio
python3 ~/WRB/test_system.py serial
```

### System Monitoring
```bash
# Generate system report
python3 ~/WRB/monitor_system.py report

# Check service status
python3 ~/WRB/monitor_system.py status
```

### Manual Testing
1. **Power on** your ESP32 devices
2. **Check LEDs** - should show connection status
3. **Press buttons** - should trigger audio playback
4. **Check logs** - should show button press events

## 🔧 Troubleshooting

### Common Issues

#### Installation Fails
```bash
# Check internet connection
ping google.com

# Update system first
sudo apt update && sudo apt upgrade -y

# Try manual installation steps
```

#### Service Won't Start
```bash
# Check service status
sudo systemctl status WRB-enhanced.service

# View service logs
sudo journalctl -u WRB-enhanced.service -f

# Check file permissions
ls -la ~/WRB/
```

#### No Audio Output
```bash
# Test audio system
python3 ~/WRB/test_system.py audio

# Check audio devices
aplay -l
pactl info

# Test with simple sound
speaker-test -t wav -c 2
```

#### ESP32 Not Connecting
```bash
# Check serial ports
python3 ~/WRB/monitor_system.py ports

# Test serial communication
python3 ~/WRB/test_system.py serial

# Check ESP32 power and connections
```

#### GPIO Issues
```bash
# Test GPIO system
python3 ~/WRB/test_system.py gpio

# Check user groups
groups $USER

# Check GPIO permissions
ls -la /dev/gpiomem
```

### Diagnostic Commands

```bash
# Full system report
python3 ~/WRB/monitor_system.py report

# Test all components
python3 ~/WRB/test_system.py

# Check service logs
sudo journalctl -u WRB-enhanced.service --since "1 hour ago"

# Check system resources
top
df -h
free -h
```

## 🔄 Updates

### Automatic Updates
```bash
# Update from repository
cd ~/WRB
git pull origin Update-1.0

# Restart service
sudo systemctl restart WRB-enhanced.service
```

### Manual Updates
```bash
# Re-run installation script
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/Update-1.0/Pi%20Zero/install.sh | bash
```

## 📞 Support

### Getting Help
1. **Check logs** for error messages
2. **Run diagnostics** to identify issues
3. **Review configuration** for incorrect settings
4. **Test components** individually

### Useful Commands
```bash
# System status
systemctl status WRB-enhanced.service

# Service logs
journalctl -u WRB-enhanced.service -f

# System report
python3 ~/WRB/monitor_system.py report

# Test system
python3 ~/WRB/test_system.py
```

### Documentation
- **Main README**: See `README.md`
- **Configuration**: See `config.py`
- **Troubleshooting**: See troubleshooting section above

---

**Installation Complete!** Your WRB Enhanced Audio System should now be running. Check the service status and test the system to ensure everything is working correctly.
