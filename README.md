# WRB Enhanced Audio System

**ESP32 Wireless Button System (WRB)** - A complete battery-efficient wireless button system using Seeed Studio XIAO ESP32C3 devices with ESP-NOW protocol, featuring release-based triggering, hold detection, audio feedback, and one-command Raspberry Pi installation.

## 🎯 Project Overview

The WRB system provides a professional wireless button solution with:
- **Release-based triggering** (no double triggers)
- **Hold detection** (800ms threshold)
- **Audio feedback** with customizable sounds
- **LED status indicators** for connection and activity
- **Power management** for extended battery life
- **One-command installation** for easy setup

## 🚀 Quick Start

### One-Command Installation

```bash
# Install WRB system (recommended)
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/Update-1.0/Pi%20Zero/install.sh | bash

# Alternative installation method
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/main/Pi%20Zero/install.sh | bash
```

### Manual Installation

```bash
# Clone repository
git clone -b Update-1.0 https://github.com/Jallison154/TheBigWRB.git ~/TheBigWRB
cd ~/TheBigWRB/Pi\ Zero
chmod +x install.sh
./install.sh
```

## 📋 Hardware Requirements

### ESP32 Devices
- **2x Seeed Studio XIAO ESP32C3** boards (transmitter + receiver)
- **2x Push buttons** (for transmitter)
- **2x LEDs** (for status indicators)
- **2x Resistors** (220Ω for LEDs)

### Raspberry Pi
- **Raspberry Pi Zero/3/4/5** with Raspberry Pi OS
- **MicroSD card** (8GB+ recommended)
- **USB drive** (optional, for custom sound files)

### Additional Components
- **Breadboard and jumper wires** (for prototyping)
- **2x AA batteries** (for transmitter power)

## 🔧 Hardware Setup

### ESP32 Pin Configuration

#### Transmitter ESP32:
```
├── D1 (GPIO2)  ←→ Button 1 ←→ GND
├── D2 (GPIO3)  ←→ Button 2 ←→ GND  
├── D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
└── USB ←→ Power/Programming
```

#### Receiver ESP32:
```
├── D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
├── USB ←→ Raspberry Pi (Serial)
└── Power ←→ USB or Battery
```

### Raspberry Pi GPIO Configuration
```
├── GPIO 23 ←→ Ready LED (220Ω) ←→ 3.3V
├── GPIO 24 ←→ USB LED (220Ω) ←→ 3.3V
├── USB ←→ ESP32 Receiver (Serial)
└── 3.3V/GND ←→ LED Power
```

## 📁 Project Structure

```
TheBigWRB/
├── Transmitter/
│   └── Transmitter_ESP32.ino    # Transmitter code
├── Receiver/
│   └── Receiver_ESP32.ino       # Receiver code
├── Pi Zero/
│   ├── install.sh               # Main installation script
│   ├── PiScript                 # Main Python application
│   ├── config.py                # Configuration file
│   ├── monitor_system.py        # System monitoring
│   ├── test_system.py           # System testing
│   ├── create_test_sounds.py    # Test sound generator
│   ├── requirements.txt         # Python dependencies
│   ├── WRB-enhanced.service     # Systemd service
│   └── default_sounds/          # Default sound files
├── MAC_Finder.ino               # MAC address utility
└── README.md                    # This file
```

## 🔧 Configuration

### MAC Address Setup

1. Upload `MAC_Finder.ino` to your ESP32 devices
2. Open Serial Monitor to see MAC addresses
3. Update MAC addresses in the ESP32 code:

#### Transmitter Configuration:
```cpp
// Receiver MAC Address
uint8_t RX_MAC[] = { 0x58, 0x8C, 0x81, 0x9E, 0x30, 0x10 };
```

#### Receiver Configuration:
```cpp
// Allowed Transmitter MACs
uint8_t ALLOWED_TX_MACS[][6] = {
  { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAC }, // Transmitter 1
  { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAD }, // Transmitter 2
};
```

### Sound File Configuration

Place custom sound files in `~/WRB/sounds/` with these naming conventions:
- `button1*.wav` - Button 1 quick press
- `button2*.wav` - Button 2 quick press
- `hold1*.wav` - Button 1 hold
- `hold2*.wav` - Button 2 hold

## 🎵 Audio System

### Supported Formats
- **WAV files** (44.1kHz, 16-bit recommended)
- **USB drive support** for custom sounds
- **4-channel simultaneous playback**
- **Automatic fallback** to default sounds

### Audio Configuration
- **Primary**: PulseAudio (recommended)
- **Fallback**: ALSA
- **Sample Rate**: 44100 Hz
- **Channels**: Stereo (2-channel)
- **Bit Depth**: 16-bit

## 🔒 Security Features

- **MAC address authentication** (only authorized devices)
- **Message validation** (malformed message rejection)
- **Unauthorized device logging** (security monitoring)
- **Connection monitoring** (ping/ack system)

## 📊 System Monitoring

### Service Management
```bash
# Check service status
sudo systemctl status WRB-enhanced.service

# Start/stop service
sudo systemctl start WRB-enhanced.service
sudo systemctl stop WRB-enhanced.service

# View logs
sudo journalctl -u WRB-enhanced.service -f
```

### System Testing
```bash
# Run all tests
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

## 🔧 Troubleshooting

### Common Issues

#### Service Not Starting
```bash
# Check service logs
sudo journalctl -u WRB-enhanced.service -f

# Restart service
sudo systemctl restart WRB-enhanced.service
```

#### No Audio Output
```bash
# Test audio system
python3 ~/WRB/test_system.py audio

# Check audio devices
aplay -l
pactl info
```

#### ESP32 Not Connecting
```bash
# Check serial ports
python3 ~/WRB/monitor_system.py ports

# Test serial communication
python3 ~/WRB/test_system.py serial
```

#### GPIO Issues
```bash
# Test GPIO system
python3 ~/WRB/test_system.py gpio

# Check permissions
groups $USER
```

### Diagnostic Commands

```bash
# Full system report
python3 ~/WRB/monitor_system.py report

# Test all components
python3 ~/WRB/test_system.py

# Check service status
systemctl status WRB-enhanced.service

# View recent logs
journalctl -u WRB-enhanced.service --since "1 hour ago"
```

## 🔄 Updates

### Automatic Updates
The system can be updated using git:

```bash
# Update from Update-1.0 branch
cd ~/WRB
git pull origin Update-1.0

# Update from main branch
cd ~/WRB
git pull origin main

# Restart service after update
sudo systemctl restart WRB-enhanced.service
```

### Manual Updates
```bash
# Download latest version
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/Update-1.0/Pi%20Zero/install.sh | bash
```

## 📈 Performance Specifications

### Latency Requirements
- **Button press to sound**: < 100ms
- **Hold detection**: 800ms ± 50ms
- **Audio playback**: Immediate start
- **LED feedback**: < 50ms
- **ESP-NOW transmission**: < 5ms

### Reliability Requirements
- **Uptime**: 99%+ (with auto-restart)
- **Error recovery**: Automatic restart on failure
- **Connection stability**: Auto-reconnect ESP32
- **Audio stability**: No cutoffs or glitches
- **Transmission success**: > 95% (with retries)

## ⚡ Power Management

### ESP32 Power Consumption
- **Active Mode**: 50-100mA (button press/transmission)
- **Light Sleep**: 5-10mA (idle with breathing LED)
- **Deep Sleep**: 10-50μA (extended idle)
- **Battery Life**: 6+ months (with 2x AA batteries)

### Sleep Timers
- **Light sleep**: 5 minutes of inactivity
- **Deep sleep**: 15 minutes of inactivity

## 🔧 Development

### Code Structure
- **Modular design** with separate concerns
- **Comprehensive error handling**
- **Configuration management** via external files
- **Logging system** for debugging and monitoring

### Testing
- **Unit tests** for individual components
- **Integration tests** for full system
- **Hardware tests** for real device testing
- **Performance tests** for latency and reliability

## 📞 Support

### Documentation
- **Installation Guide**: See `Pi Zero/INSTALLATION_GUIDE.md`
- **Configuration Examples**: See `Pi Zero/config.py`
- **Troubleshooting Guide**: See troubleshooting section above

### Issues and Bug Reports
Please report issues and bugs through the GitHub repository:
- **Repository**: https://github.com/Jallison154/TheBigWRB
- **Issues**: https://github.com/Jallison154/TheBigWRB/issues

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 Changelog

### Version 1.0 (Current)
- Initial release with complete WRB system
- ESP32 transmitter and receiver code
- Raspberry Pi audio system
- One-command installation
- Comprehensive testing and monitoring tools

---

**WRB Enhanced Audio System** - Professional wireless button solution with audio feedback and easy installation.
