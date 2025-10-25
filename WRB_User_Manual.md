# WRB01 User Manual
## Wireless Remote Button System

**Quick Start Guide for the WRB01 Professional Button + Audio System**

---

## 🎯 What is WRB01?

The WRB01 is a wireless button system that plays audio when you press buttons. It consists of:
- **2 ESP32 devices** (transmitter + receiver)
- **Raspberry Pi** (audio player)
- **2 buttons** (for triggering sounds)

**How it works:** Press button → ESP32 sends signal → Pi plays sound

---

## 📋 What You Need

### Hardware
- **2x Seeed Studio XIAO ESP32C3** boards
- **2x Push buttons**
- **2x LEDs** (for status)
- **2x 220Ω resistors**
- **Raspberry Pi Zero/3/4/5** with Raspberry Pi OS
- **MicroSD card** (8GB+)
- **Breadboard and jumper wires**
- **2x AA batteries** (for transmitter)

### Software
- Arduino IDE (for ESP32 programming)
- Internet connection (for installation)

---

## 🚀 Quick Installation

### Step 1: Install on Raspberry Pi
```bash
# One-command installation
curl -sSL https://raw.githubusercontent.com/Jallison154/WRB01/WRB01/Pi%20Zero/easy_install.sh | bash
```

**That's it!** The script installs everything automatically.

### Step 2: Upload ESP32 Code
1. Open Arduino IDE
2. Upload `Transmitter_ESP32_Working.ino` to transmitter ESP32
3. Upload `Receiver_ESP32_Working.ino` to receiver ESP32

### Step 3: Hardware Setup
**Transmitter ESP32:**
```
D1 (GPIO2)  ←→ Button 1 ←→ GND
D2 (GPIO3)  ←→ Button 2 ←→ GND  
D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
```

**Receiver ESP32:**
```
D10 (GPIO8) ←→ LED (220Ω) ←→ 3.3V
USB ←→ Raspberry Pi
```

**Raspberry Pi:**
```
USB ←→ ESP32 Receiver
Audio ←→ Speakers/Headphones
```

---

## 🔧 Configuration

### MAC Address Setup (Required)
1. Upload `MAC_Finder.ino` to your ESP32 devices
2. Open Serial Monitor to see MAC addresses
3. Update the MAC addresses in your ESP32 code:

**In Transmitter code:**
```cpp
uint8_t RX_MAC[] = { 0x58, 0x8C, 0x81, 0x9E, 0x30, 0x10 }; // Your receiver MAC
```

**In Receiver code:**
```cpp
uint8_t ALLOWED_TX_MACS[][6] = {
  { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAC }, // Your transmitter MAC
};
```

---

## 🎵 Audio Files

### Supported File Names
- `button1*.wav` - Button 1 press sounds
- `button2*.wav` - Button 2 press sounds  
- `hold1*.wav` - Button 1 hold sounds
- `hold2*.wav` - Button 2 hold sounds

### File Locations (Priority Order)
1. **USB Drives** - Insert USB drive with audio files
2. **Local Directory** - `/home/wrb01/audio/` (fallback)

### Audio Requirements
- **Format:** WAV files
- **Sample Rate:** 44.1kHz (recommended)
- **Channels:** Stereo (2-channel)
- **Bit Depth:** 16-bit

---

## 🎮 How to Use

### Button Actions
- **Quick Press** (< 800ms) → Plays button sound
- **Hold** (≥ 800ms) → Plays hold sound

### LED Status Indicators
**Transmitter LED:**
- **Off** - No connection
- **Breathing** - Searching for receiver
- **Dim** - Connected to receiver
- **Bright** - Button pressed

**Receiver LED:**
- **Off** - No transmitters connected
- **Breathing** - Waiting for transmitters
- **Dim** - Transmitters connected
- **Bright** - Button activity
- **Double Blink** - Hold command

---

## 🔧 System Management

### Check Status
```bash
sudo systemctl status wrb-simple.service
```

### View Logs
```bash
sudo journalctl -u wrb-simple.service -f
```

### Restart Service
```bash
sudo systemctl restart wrb-simple.service
```

### Test Buttons
```bash
python3 /home/wrb01/test_buttons.py
```

---

## 🛠️ Troubleshooting

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

# Install missing dependencies
sudo apt install python3-gpiozero
```

### No Button Response
1. Check ESP32 connections
2. Verify MAC addresses are correct
3. Check serial communication: `python3 /home/wrb01/test_buttons.py`
4. Check service logs: `sudo journalctl -u wrb-simple.service -f`

---

## 📊 System Specifications

### Performance
- **Button to Sound Latency:** < 100ms
- **Hold Detection:** 800ms ± 50ms
- **Audio Playback:** Immediate start
- **LED Feedback:** < 50ms

### Power Management
- **Battery Life:** 6+ months (2x AA batteries)
- **Sleep Modes:** Automatic power saving
- **Connection Monitoring:** Auto-reconnect

### Audio Features
- **USB Audio Priority** - Uses USB audio when available
- **Hot-swap Audio** - Change files without restart
- **4-channel Playback** - Simultaneous sounds
- **Fade-out** - Smooth transitions when same button pressed

---

## 🔒 Security Features

- **MAC Address Authentication** - Only authorized devices
- **Message Validation** - Rejects malformed messages
- **Connection Monitoring** - Ping/ack system
- **Unauthorized Device Logging** - Security monitoring

---

## 📁 File Structure

```
WRB01/
├── Transmitter/
│   └── Transmitter_ESP32_Working.ino    # Transmitter code
├── Receiver/
│   └── Receiver_ESP32_Working.ino       # Receiver code
├── Pi Zero/
│   ├── easy_install.sh                  # Installation script
│   ├── simple_audio_player.py           # Audio player
│   └── Default Sounds/                  # Default audio files
├── MAC_Finder.ino                       # MAC address utility
└── README.md                            # Detailed documentation
```

---

## 🆘 Support

### Quick Fixes
- **Service not starting:** `sudo systemctl restart wrb-simple.service`
- **No audio:** Check USB audio connection and run `aplay -l`
- **No button response:** Check ESP32 connections and MAC addresses
- **System slow:** Restart Pi and check service status

### Getting Help
- **Service Logs:** `sudo journalctl -u wrb-simple.service -f`
- **System Status:** `sudo systemctl status wrb-simple.service`
- **Test System:** `python3 /home/wrb01/test_buttons.py`

---

## ✅ Installation Checklist

- [ ] Raspberry Pi connected to internet
- [ ] Installation script completed successfully
- [ ] ESP32 transmitter code uploaded
- [ ] ESP32 receiver code uploaded
- [ ] MAC addresses configured correctly
- [ ] Hardware connections made
- [ ] Audio files in place
- [ ] Service running (`sudo systemctl status wrb-simple.service`)
- [ ] Test buttons working (`python3 /home/wrb01/test_buttons.py`)

---

**Your WRB01 system is ready! Press buttons to hear audio! 🎯**
