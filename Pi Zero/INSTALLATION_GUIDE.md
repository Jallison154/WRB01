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
# Clone repository and run installation
git clone https://github.com/Jallison154/WRB01.git ~/WRB01
cd ~/WRB01/Pi\ Zero
chmod +x install.sh
./install.sh
```

**OR for offline installation (if you have network issues):**
```bash
# Copy the Pi Zero folder to your Pi, then:
cd /path/to/Pi\ Zero
chmod +x install.sh
./install.sh --skip-repo
```

This command will automatically:
- ✅ Create `wrb01` user and set up home directory
- ✅ Update system packages and install all dependencies
- ✅ Handle 2024 Python environment issues
- ✅ Clone repository (or use local files with `--skip-repo`)
- ✅ Copy all files to `/home/wrb01/WRB/`
- ✅ Set up audio system (PulseAudio + ALSA)
- ✅ Create and enable systemd service
- ✅ Start the service immediately
- ✅ Set up monitoring and watchdog services
- ✅ Configure automatic startup on boot

### Alternative Installation Methods

#### Method 1: Direct Git Clone
```bash
# Clone repository and install
git clone https://github.com/Jallison154/WRB01.git ~/WRB01
cd ~/WRB01/Pi\ Zero
chmod +x install.sh
./install.sh
```

#### Method 2: Manual Installation
Follow the manual installation steps below for complete control over the process.

## 🔧 Manual Installation

**Note:** The automated install script handles all of this automatically. Only use manual installation for troubleshooting or if you need custom configuration.

### Step 1: Create User and Directories
```bash
# Create wrb01 user
sudo useradd -m -s /bin/bash wrb01
sudo usermod -a -G audio,gpio,dialout,spi,i2c,plugdev,render,input wrb01

# Create directories
sudo mkdir -p /home/wrb01/WRB/{logs,sounds,default_sounds}
sudo chown -R wrb01:wrb01 /home/wrb01
sudo chmod 755 /home/wrb01
```

### Step 2: System Update and Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y python3 python3-pip python3-dev python3-pygame python3-serial python3-numpy git curl wget unzip

# Install audio packages
sudo apt install -y alsa-utils pulseaudio pulseaudio-utils libasound2-dev portaudio19-dev sox libsox-fmt-all

# Install Python packages (2024 method)
pip3 install --user --break-system-packages pygame pyserial numpy RPi.GPIO psutil
```

### Step 3: Download and Copy Files
```bash
# Clone repository
git clone https://github.com/Jallison154/WRB01.git /home/wrb01/WRB01

# Copy files to WRB directory
sudo cp /home/wrb01/WRB01/Pi\ Zero/PiScript /home/wrb01/WRB/
sudo cp /home/wrb01/WRB01/Pi\ Zero/config.py /home/wrb01/WRB/
sudo cp -r /home/wrb01/WRB01/Pi\ Zero/Default\ Sounds/* /home/wrb01/WRB/default_sounds/

# Set permissions
sudo chown -R wrb01:wrb01 /home/wrb01/WRB
sudo chmod +x /home/wrb01/WRB/PiScript
sudo chmod 755 /home/wrb01/WRB
```

### Step 4: Setup Audio System
```bash
# Configure PulseAudio
mkdir -p /home/wrb01/.config/pulse
cat > /home/wrb01/.config/pulse/daemon.conf << EOF
default-sample-rate = 44100
default-sample-format = s16le
default-sample-channels = 2
EOF

# Configure ALSA
sudo tee /etc/asound.conf > /dev/null << EOF
pcm.!default { type pulse }
ctl.!default { type pulse }
EOF
```

### Step 5: Create and Start Service
```bash
# Create service file
sudo tee /etc/systemd/system/WRB-enhanced.service > /dev/null << EOF
[Unit]
Description=WRB Enhanced Audio System
After=network.target
Wants=network.target
StartLimitInterval=300
StartLimitBurst=3

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01/WRB
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:0,0
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/python3 /home/wrb01/WRB/PiScript
Restart=on-failure
RestartSec=5
RestartPreventExitStatus=1
StandardOutput=journal
StandardError=journal
TimeoutStartSec=30
TimeoutStopSec=5

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
1. Upload `~/WRB01/MAC_Finder.ino` to your ESP32 devices
2. Open Serial Monitor (115200 baud)
3. Note the MAC addresses displayed

### Step 4: Configure Transmitter
1. Open `~/WRB01/Transmitter/Transmitter_ESP32_Working.ino`
2. Update the receiver MAC address:
   ```cpp
   uint8_t RX_MAC[] = { 0x58, 0x8C, 0x81, 0x9E, 0x30, 0x10 }; // Your receiver MAC
   ```
3. Upload to your transmitter ESP32

### Step 5: Configure Receiver
1. Open `~/WRB01/Receiver/Receiver_ESP32_Working.ino`
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

### Audio Features
- **Fade-out support**: Same button pressed again fades out current sound over 1 second
- **Multi-channel audio**: Up to 4 simultaneous sounds
- **Smooth transitions**: No audio glitches when switching sounds
- **Automatic cleanup**: Finished sounds are automatically cleaned up

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

# Try offline installation if network issues
cd /path/to/Pi\ Zero
./install.sh --skip-repo

# Check for specific errors
sudo journalctl -u WRB-enhanced.service -f

# Verify user and directory setup
id wrb01
ls -la /home/wrb01/WRB/
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

# Check ALSA configuration
cat ~/.asoundrc

# Test ALSA directly
aplay /usr/share/sounds/alsa/Front_Left.wav
```

#### PulseAudio Issues
```bash
# Check PulseAudio status
pulseaudio --check -v

# Restart PulseAudio
pulseaudio --kill
pulseaudio --start

# Check audio environment
echo $SDL_AUDIODRIVER
echo $AUDIODEV
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
cd ~/WRB01
git pull origin WRB01

# Restart service
sudo systemctl restart WRB-enhanced.service
```

### Manual Updates
```bash
# Update repository and re-run installation
cd ~/WRB01
git pull origin WRB01
cd Pi\ Zero
./install.sh
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
