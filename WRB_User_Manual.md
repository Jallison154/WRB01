# WRB01 User Manual
## Wireless Remote Button System

**Professional wireless button system with instant audio feedback**

---

## 🎯 What is WRB01?

The WRB01 is a wireless button system that plays custom audio when you press buttons. Perfect for:
- **Podcasters** - Sound effects and transitions
- **Streamers** - Alert sounds and notifications  
- **Presenters** - Audio cues and effects
- **Content Creators** - Custom sound triggers

**How it works:** Press button → Hear your custom sound instantly

---

## 📋 What You Need

### Complete WRB01 Kit
- **Wireless Transmitter** - Battery-powered button unit
- **Receiver Unit** - Connects to your computer
- **Raspberry Pi** - Audio processing unit
- **Audio System** - Plays your custom sounds
- **Setup Software** - One-command installation

### Your Computer Requirements
- **Raspberry Pi Zero/3/4/5** (included in kit)
- **MicroSD card** (8GB+)
- **Internet connection** (for setup only)
- **Speakers or headphones** (for audio output)

---

## 🚀 Quick Setup

### Step 1: Install Software
```bash
# One-command installation
curl -sSL https://raw.githubusercontent.com/Jallison154/WRB01/WRB01/Pi%20Zero/easy_install.sh | bash
```

**That's it!** The system installs everything automatically.

### Step 2: Connect Hardware
1. **Connect Receiver** to Raspberry Pi via USB
2. **Connect Audio** to speakers or headphones
3. **Power On** the transmitter (battery-powered)

### Step 3: Test System
- Press buttons on transmitter
- You should hear audio from your speakers
- LED indicators show system status

---

## 🔧 Configuration

### Device Pairing (One-time setup)
The transmitter and receiver need to be paired together:

1. **Find Device IDs** - Run the MAC finder utility
2. **Update Configuration** - Enter the device IDs in the system
3. **Test Connection** - Verify buttons work with audio

**Note:** This is a one-time setup process. The system will remember your devices.

---

## 🎵 Adding Your Audio

### How to Add Custom Sounds
1. **Prepare Audio Files** - Use WAV format (44.1kHz recommended)
2. **Name Files Correctly:**
   - `button1.wav` - Button 1 press sound
   - `button2.wav` - Button 2 press sound  
   - `hold1.wav` - Button 1 hold sound
   - `hold2.wav` - Button 2 hold sound

### Where to Put Audio Files
- **USB Drive** - Insert USB with audio files (automatic detection)
- **Local Folder** - Copy files to the audio directory
- **Hot-swap** - Change files without restarting system

### Audio Features
- **Instant Playback** - No delay when pressing buttons
- **Multiple Sounds** - Play different sounds simultaneously
- **Fade Effects** - Smooth transitions when same button pressed
- **USB Priority** - Automatically uses USB audio when available

---

## 🎮 How to Use

### Button Actions
- **Quick Press** - Plays your button sound
- **Hold Button** - Plays your hold sound (after 1 second)

### Status Lights
**Transmitter (Wireless Unit):**
- **Off** - No connection to receiver
- **Breathing** - Searching for receiver
- **Steady Dim** - Connected and ready
- **Bright** - Button pressed

**Receiver (Connected Unit):**
- **Off** - No transmitter connected
- **Breathing** - Waiting for transmitter
- **Steady Dim** - Transmitter connected
- **Bright** - Button activity detected
- **Double Blink** - Hold command received

---

## 🔧 System Management

### Check if System is Running
```bash
sudo systemctl status wrb-simple.service
```

### View System Activity
```bash
sudo journalctl -u wrb-simple.service -f
```

### Restart System
```bash
sudo systemctl restart wrb-simple.service
```

### Test Your Buttons
```bash
python3 /home/wrb01/test_buttons.py
```

---

## 🛠️ Troubleshooting

### No Audio Output
```bash
# Check audio devices
aplay -l

# Test audio system
aplay -D plughw:1,0 /home/wrb01/audio/button1.wav
```

### Buttons Not Working
```bash
# Check if receiver is connected
ls /dev/ttyACM*

# Test button detection
python3 /home/wrb01/test_buttons.py
```

### System Not Starting
```bash
# Check system status
sudo systemctl status wrb-simple.service

# Install missing components
sudo apt install python3-gpiozero
```

### Quick Fixes
1. **No Sound** - Check audio connections and run audio test
2. **No Button Response** - Check receiver connection and run button test
3. **System Slow** - Restart system and check status
4. **Connection Issues** - Verify device pairing and check logs

---

## 📊 System Specifications

### Performance
- **Instant Response** - Less than 100ms from button press to sound
- **Hold Detection** - 1 second hold time for hold sounds
- **Audio Quality** - Professional audio playback
- **LED Feedback** - Immediate visual confirmation

### Power Management
- **Battery Life** - 6+ months on 2 AA batteries
- **Auto-Sleep** - Powers down when not in use
- **Auto-Reconnect** - Reconnects automatically when powered on

### Audio Features
- **USB Audio Priority** - Automatically uses best available audio
- **Hot-swap Audio** - Change sounds without restarting
- **Multiple Sounds** - Play different sounds at the same time
- **Fade Effects** - Smooth transitions between sounds

### Security
- **Device Pairing** - Only your devices can control the system
- **Secure Communication** - Encrypted wireless transmission
- **Connection Monitoring** - Automatic reconnection if connection lost

---

## 🆘 Support

### Quick Fixes
- **System not starting:** `sudo systemctl restart wrb-simple.service`
- **No audio:** Check audio connections and run `aplay -l`
- **No button response:** Check receiver connection and run button test
- **System slow:** Restart system and check status

### Getting Help
- **System Logs:** `sudo journalctl -u wrb-simple.service -f`
- **System Status:** `sudo systemctl status wrb-simple.service`
- **Test Buttons:** `python3 /home/wrb01/test_buttons.py`

---

## ✅ Setup Checklist

- [ ] Raspberry Pi connected to internet
- [ ] Installation script completed successfully
- [ ] Transmitter and receiver paired
- [ ] Hardware connections made
- [ ] Audio files in place
- [ ] System running (`sudo systemctl status wrb-simple.service`)
- [ ] Test buttons working (`python3 /home/wrb01/test_buttons.py`)

---

**Your WRB01 system is ready! Press buttons to hear your custom audio! 🎯**
