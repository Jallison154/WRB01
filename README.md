# ESP32 Wireless Button System (TheBigWRB)

A complete battery-efficient wireless button system using **Seeed Studio XIAO ESP32C3** devices with ESP-NOW protocol. Features release-based triggering, hold detection, audio feedback, and one-command Raspberry Pi installation.

## System Overview

- **Transmitters**: Seeed Studio XIAO ESP32C3 devices with buttons that send button press events wirelessly
- **Receiver**: Seeed Studio XIAO ESP32C3 device that receives button presses and can trigger actions
- **Protocol**: ESP-NOW for low-latency, direct communication
- **Power Management**: Advanced sleep modes for extended battery life
- **Security**: MAC address-based authentication to ensure devices only communicate with authorized partners
- **Hold Functionality**: Buttons can be held for extended actions without triggering normal press sounds
- **Audio Integration**: Raspberry Pi script for playing different sounds based on button actions

## Project Structure

```
TheBigWRB/
├── Transmitter/
│   └── Transmitter_ESP32.ino    # Main transmitter code with release-based triggering
├── Receiver/
│   └── Receiver ESP32           # Receiver code with hold detection
├── Pi Zero/
│   ├── PiScript                 # Main Raspberry Pi audio script
│   ├── config.py                # Configuration file
│   ├── install.sh               # One-command installation script
│   ├── default_sounds/          # Default audio files included
│   └── WRB-enhanced.service     # Systemd service configuration
├── MAC_Finder.ino               # Utility to find device MAC addresses
└── README.md                    # This file
```

## Key Improvements Made

### 1. **Proper System Architecture**
- Separated transmitter and receiver functionality
- Clear distinction between sending and receiving devices
- Proper message handling and acknowledgment system

### 2. **Enhanced Reliability**
- **Retry Mechanism**: Button presses are retried up to 3 times if transmission fails
- **Error Handling**: Better error reporting and handling of ESP-NOW failures
- **Link Monitoring**: Continuous ping/ack system to monitor connection health

### 3. **Improved Power Management**
- **Light Sleep**: Proper implementation of light sleep during breathing LED phase
- **Deep Sleep**: Automatic deep sleep after 15 minutes of inactivity
- **Wake-up Handling**: GPIO wake-up from both light and deep sleep modes

### 4. **Better LED Feedback**
- **Transmitter**: Shows connection status and button activity
- **Receiver**: Shows connected transmitters and received button presses
- **Breathing Effect**: Smooth LED breathing during low-power mode

### 5. **Multi-Transmitter Support**
- Receiver can handle up to 10 transmitters simultaneously
- Automatic transmitter discovery and management
- Individual link status tracking

### 6. **MAC Address Security**
- **Transmitter**: Only accepts responses from authorized receiver MAC
- **Receiver**: Only accepts messages from pre-configured transmitter MACs
- **Unauthorized Device Rejection**: Logs and ignores messages from unknown devices

### 7. **Release-Based Triggering** ⭐ **NEW**
- **No Double Triggers**: Only triggers on button release, not press
- **Hold Detection**: Measures hold duration to distinguish press vs hold (800ms threshold)
- **Instant Response**: Audio plays immediately on release without initialization delays
- **Smart Classification**: Automatically determines if it was a press or hold based on duration

### 8. **Enhanced Audio System** ⭐ **NEW**
- **Keep-Open Audio**: Mixer initialized once at startup, no audio cutoffs
- **4-Channel Audio**: Supports simultaneous playback of multiple sounds
- **Smart File Naming**: Clear naming convention for different button actions
- **USB Hot-Swapping**: Automatic detection and use of sound files from USB drives
- **Local Fallback**: Falls back to local storage if no USB drive is available
- **Default Sounds**: Sample audio files included for immediate testing

## Hardware Setup

### Transmitter
- **Board**: Seeed Studio XIAO ESP32C3
- **Buttons**: 2 buttons connected to D1 and D2 (to GND)
- **Status LED**: On D10
- **Power**: Battery recommended for portability (3.3V)

### Receiver
- **Board**: Seeed Studio XIAO ESP32C3
- **Status LED**: On D10
- **Power**: USB or battery (3.3V)

### Pin Connections
- `LED_PIN`: D10 (status LED)
- `BTN1_PIN`: D1 (button 1)
- `BTN2_PIN`: D2 (button 2)

**Note**: The XIAO ESP32C3 uses the Dx pin aliases which map to the actual GPIO pins on the board.

## Configuration

### MAC Address Security Setup

**IMPORTANT**: You must configure the correct MAC addresses for your devices to communicate.

#### Step 1: Find Your Device MAC Addresses
1. Use the included `MAC_Finder.ino` sketch to find your device MAC addresses:
   - Open `MAC_Finder.ino` in Arduino IDE
   - Select your board (XIAO_ESP32C3)
   - Upload the sketch
   - Open Serial Monitor (115200 baud)
   - The MAC address will be displayed in the correct format for copying to your code

Alternatively, you can use this simple sketch:
```cpp
#include <WiFi.h>
void setup() {
  Serial.begin(115200);
  Serial.printf("MAC Address: %s\n", WiFi.macAddress().c_str());
}
void loop() {}
```

#### Step 2: Configure the Receiver
In `Receiver ESP32`, update the allowed transmitter MACs:
```cpp
uint8_t ALLOWED_TX_MACS[][6] = {
  { 0x58,0x8C,0x81,0x9F,0x22,0xAC }, // Your transmitter MAC
  // Add more transmitters as needed
};
```

#### Step 3: Configure the Transmitter
In `Transmitter_ESP32.ino`, update the receiver MAC:
```cpp
uint8_t RX_MAC[] = { 0x58,0x8C,0x81,0x9E,0x30,0x10 }; // Your receiver MAC
```

### Pin Configuration
- `LED_PIN`: D10 (status LED)
- `BTN1_PIN`: D1 (button 1)
- `BTN2_PIN`: D2 (button 2)

### Power Settings
- Light sleep after 5 minutes of inactivity
- Deep sleep after 15 minutes of inactivity
- Breathing LED during light sleep phase

### Hold Configuration ⭐ **NEW**
- Hold delay: 800ms (0.8 seconds) - configurable in transmitter code
- Release-based triggering prevents double events
- Automatic classification of press vs hold actions

## Usage

### Arduino IDE Setup
1. **Install ESP32 Board Package**:
   - Open Arduino IDE
   - Go to File → Preferences
   - Add this URL to "Additional Board Manager URLs": `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Go to Tools → Board → Board Manager
   - Search for "ESP32" and install "ESP32 by Espressif Systems"

2. **Select Board**:
   - Tools → Board → ESP32 Arduino → XIAO_ESP32C3
   - Set Upload Speed to 921600
   - Set CPU Frequency to 160MHz
   - Set Flash Frequency to 80MHz
   - Set Flash Mode to QIO
   - Set Flash Size to 4MB

### Flashing the Code
1. **First**: Find your device MAC addresses using the `MAC_Finder.ino` sketch
2. **Second**: Update the MAC addresses in both files
3. **Third**: Flash `Transmitter_ESP32.ino` to your transmitter XIAO ESP32C3
4. **Fourth**: Flash `Receiver ESP32` to your receiver XIAO ESP32C3

### Operation
1. **Transmitter**: Press buttons to send events to receiver
2. **Receiver**: Receives button presses and can trigger actions
3. **LED Indicators**:
   - **Transmitter**: 
     - Solid 100%: Button held
     - 25%: Connected to receiver
     - Double blink: No connection
     - Breathing: Low-power mode
   - **Receiver**:
     - Solid 100%: Button press received
     - 25%: Transmitters connected
     - Double blink: No transmitters connected

### Button Actions ⭐ **NEW**
- **Quick Press and Release** (< 800ms): Triggers normal button action (BTN1/BTN2)
- **Hold Button** (≥ 800ms): Triggers hold action (BTN1 HOLD/BTN2 HOLD), prevents normal action on release
- **Release-Based**: Only triggers on button release, never on press
- **No Double Triggers**: Each button press/release cycle triggers exactly one action

### Serial Output
Both devices provide detailed serial output for debugging:
- Connection status
- Button press events
- Button hold events ⭐ **NEW**
- Error messages
- Power management events
- **Security events**: Rejected unauthorized MAC addresses

## Security Features

### MAC Address Validation
- **Transmitter**: Only processes ACK messages from the configured receiver MAC
- **Receiver**: Only processes messages from pre-configured transmitter MACs
- **Logging**: Both devices log rejected messages for debugging

### Unauthorized Device Protection
- Messages from unknown MAC addresses are ignored
- Serial output shows rejected MAC addresses
- No impact on authorized device communication

## Power Consumption

- **Active Mode**: ~50-100mA
- **Light Sleep**: ~5-10mA
- **Deep Sleep**: ~10-50μA
- **Breathing Mode**: ~20-30mA (with periodic light sleep)

## Troubleshooting

### Common Issues

1. **No Connection**
   - Check MAC addresses are correctly configured
   - Ensure both devices are on the same WiFi channel (default: 1)
   - Verify ESP-NOW initialization
   - Check serial output for rejected MAC addresses

2. **Button Not Responding**
   - Check button wiring (should be to GND with INPUT_PULLUP)
   - Verify pin definitions
   - Check serial output for error messages

3. **High Power Consumption**
   - Ensure sleep modes are enabled (`ENABLE_SLEEP = true`)
   - Check for stuck loops or delays
   - Verify LED configuration

4. **Missed Button Presses**
   - Increase retry count if needed
   - Check for interference on WiFi channel
   - Verify receiver is processing messages

5. **Security Issues**
   - Verify MAC addresses match between devices
   - Check serial output for "Rejected message from unauthorized MAC"
   - Ensure transmitter MAC is in receiver's allowed list

6. **Hold Functionality Not Working** ⭐ **NEW**
   - Verify hold delay is set correctly (default: 1000ms)
   - Check that hold sounds are properly named and located
   - Ensure Pi script is detecting hold messages correctly

### Debugging
- Monitor serial output on both devices
- Check LED indicators for status
- Use WiFi analyzer to check for channel conflicts
- Look for security rejection messages
- Check Pi script logs for hold message detection

## Customization

### Adding More Buttons
1. Define additional button pins
2. Add button debouncer structures
3. Update button handling in loop()
4. Add corresponding hold detection for new buttons

### Adding More Transmitters
1. Add transmitter MAC to `ALLOWED_TX_MACS` array in receiver
2. Update `NUM_ALLOWED_TXS` if needed
3. Flash updated receiver code

### Changing Power Settings
Modify these constants in the transmitter:
```cpp
const uint32_t IDLE_LIGHT_MS = 5UL * 60UL * 1000UL;  // Light sleep delay
const uint32_t IDLE_DEEP_MS = 15UL * 60UL * 1000UL;  // Deep sleep delay
```

### Changing Hold Timing
Modify the hold delay in the Pi script:
```python
HOLD_DELAY_MS = 1000  # Milliseconds to hold button before triggering hold sound
```

### Adding Actions
In the receiver, add your desired actions when button presses are received:
```cpp
case MSG_BTN:
  if (len >= 2) {
    uint8_t btnId = data[1];
    // Add your custom actions here
    if (btnId == 1) {
      // Handle button 1 press
    } else if (btnId == 2) {
      // Handle button 2 press
    }
  }
  break;

case MSG_BTN_HOLD:  // ⭐ NEW: Handle hold actions
  if (len >= 2) {
    uint8_t btnId = data[1];
    // Add your custom hold actions here
    if (btnId == 1) {
      // Handle button 1 hold
    } else if (btnId == 2) {
      // Handle button 2 hold
    }
  }
  break;
```

## Installation

This project is now **publicly available** on GitHub! 

### One-Command Installation

**Direct Install (Recommended)**
```bash
curl -sSL https://raw.githubusercontent.com/Jallison154/TheBigWRB/main/Pi%20Zero/install.sh | bash
```

**Clone and Install**
```bash
git clone https://github.com/Jallison154/TheBigWRB.git && cd TheBigWRB/Pi\ Zero && chmod +x install.sh && ./install.sh
```

**Manual Install**
```bash
# Copy files to Pi and run installation
scp -r Pi\ Zero/* pi@your-pi-ip:~/WRB/
ssh pi@your-pi-ip "cd ~/WRB && chmod +x install.sh && ./install.sh"
```

**Features:**
- ✅ One-command installation
- ✅ Default sound files included
- ✅ Automatic error handling
- ✅ Complete system setup
- ✅ Anti-reboot loop protection
- ✅ Auto-start on boot

For detailed installation instructions, see the [Complete Installation Guide](Pi%20Zero/INSTALLATION_GUIDE.md).

## Current Status

✅ **Production Ready**: All core functionality implemented and tested
✅ **Clean Codebase**: Removed all temporary files and debugging scripts  
✅ **One-Command Install**: Complete system setup with single command
✅ **Release-Based Triggering**: No more double triggers, proper hold detection
✅ **Audio Cutoff Fixed**: Keep-open audio system prevents audio cutoffs
✅ **Auto-Start**: System automatically starts on boot with reliability features
✅ **Default Sounds**: Sample audio files included for immediate testing

## License

This project is open source. Feel free to modify and distribute as needed.

## Raspberry Pi Integration

### Enhanced Pi Script

The system includes an enhanced Raspberry Pi script that works seamlessly with the ESP32 receiver to play sound effects based on button presses and holds.

#### Features:
- **ESP32 Message Parsing**: Automatically detects and parses ESP32 button messages
- **Hold Detection**: Supports both quick press and hold button actions
- **4-Channel Audio**: Plays different sounds simultaneously for different actions
- **Smart File Naming**: Clear naming convention for easy organization
- **USB Hot-Swapping**: Automatically detects and uses sound files from USB drives
- **USB LED Indicator**: Visual indicator showing when USB drives are mounted
- **Logging**: Comprehensive logging of all button presses, holds, and system events
- **LED Feedback**: Visual feedback when buttons are pressed or held
- **Auto-Restart**: Automatically restarts if the ESP32 connection is lost
- **Systemd Service**: Runs as a system service that starts on boot

#### Sound File Organization ⭐ **NEW**

The system now uses a clear, logical naming convention:

- **`button1*.wav`** - Sound files for Button 1 quick press actions
- **`button2*.wav`** - Sound files for Button 2 quick press actions  
- **`hold1*.wav`** - Sound files for Button 1 hold actions
- **`hold2*.wav`** - Sound files for Button 2 hold actions

**File Examples:**
```
button1_correct.wav    # Button 1 quick press sound
button2_incorrect.wav  # Button 2 quick press sound
hold1_extended.wav     # Button 1 hold sound
hold2_special.wav      # Button 2 hold sound
```

#### Button Actions ⭐ **NEW**

- **Button 1 Quick Press** → Plays `button1*.wav` file
- **Button 1 Hold (1 second)** → Plays `hold1*.wav` file (prevents normal button1 sound on release)
- **Button 2 Quick Press** → Plays `button2*.wav` file
- **Button 2 Hold (1 second)** → Plays `hold2*.wav` file (prevents normal button2 sound on release)

#### Complete Pi Zero Setup Guide:

##### **Step 1: Initial Pi Zero Setup**
1. **Flash Raspberry Pi OS** to your microSD card using Raspberry Pi Imager
2. **Enable SSH** during imaging or create an empty file named `ssh` in the boot partition
3. **Configure WiFi** (if using WiFi) by creating `wpa_supplicant.conf` in the boot partition:
   ```
   country=US
   ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
   update_config=1
   network={
       ssid="YourWiFiName"
       psk="YourWiFiPassword"
   }
   ```
4. **Insert microSD card** into Pi Zero and power it on
5. **Wait 2-3 minutes** for first boot to complete

##### **Step 2: Connect to Your Pi Zero**
1. **Find your Pi's IP address** (if using WiFi):
   ```bash
   # On your computer, scan for the Pi:
   nmap -sn 192.168.1.0/24 | grep -B2 -A2 "Raspberry Pi"
   ```
2. **Connect via SSH:**
   ```bash
   ssh pi@WRB01.local
   # OR if .local doesn't work:
   ssh pi@192.168.1.XXX  # Replace with actual IP
   # Username: WRB01
   # Password: wrongright
   ```

##### **Step 3: Update System and Install Dependencies**
```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3-pip python3-pygame python3-serial python3-gpiozero git

# Install pygame (if not already installed)
pip3 install pygame
```

##### **Step 4: Transfer WRB Files to Pi**
1. **From your computer, copy files to Pi:**
   ```bash
   # Using SCP (replace with actual IP if needed):
   scp "Pi Script" pi@WRB01.local:~/
   scp WRB-enhanced.service pi@WRB01.local:~/
   scp install_enhanced.sh pi@WRB01.local:~/
   scp config.py pi@WRB01.local:~/
   scp test_esp32_connection.py pi@WRB01.local:~/
   ```

2. **Or manually create the files on the Pi:**
   ```bash
   # Create the main script
   nano ~/Pi_Script_Enhanced.py
   # Copy and paste the contents of "Pi Script" file
   
   # Create the service file
   sudo nano /etc/systemd/system/WRB-enhanced.service
   # Copy and paste the contents of WRB-enhanced.service
   ```

##### **Step 5: Run Installation Script**
```bash
# Make installation script executable
chmod +x install_enhanced.sh

# Run the installation
./install_enhanced.sh
```

##### **Step 6: Verify Installation**
```bash
# Check if service is running
sudo systemctl status WRB-enhanced.service

# Check if directories were created
ls -la ~/WRB/

# Check if sample sound files were created
ls -la ~/WRB/sounds/
```

##### **Step 7: Connect ESP32 Receiver**
1. **Connect ESP32 receiver** to Pi Zero via USB cable
2. **Check if ESP32 is detected:**
   ```bash
   # List USB devices
   lsusb
   
   # Check serial ports
   ls /dev/ttyACM* /dev/ttyUSB*
   ```

##### **Step 8: Test the System**
```bash
# Test ESP32 connection
python3 ~/WRB/test_esp32_connection.py

# Test system integration
python3 ~/WRB/test_system_integration.py

# Monitor system logs
sudo journalctl -u WRB-enhanced.service -f
```

##### **Step 9: Add Your Sound Files**
1. **Create sound files** with these names:
   - `button1.wav` - Button 1 quick press sound
   - `button2.wav` - Button 2 quick press sound  
   - `hold1.wav` - Button 1 hold sound
   - `hold2.wav` - Button 2 hold sound

2. **Copy to Pi:**
   ```bash
   # Copy via SCP
   scp button1.wav pi@WRB01.local:~/WRB/sounds/
   scp button2.wav pi@WRB01.local:~/WRB/sounds/
   scp hold1.wav pi@WRB01.local:~/WRB/sounds/
   scp hold2.wav pi@WRB01.local:~/WRB/sounds/
   ```

##### **Step 10: Final Verification**
```bash
# Check service status
sudo systemctl status WRB-enhanced.service

# View button press logs
tail -f ~/WRB/button_log.txt

# Test button presses on your ESP32 transmitter
# You should see log entries and hear sounds
```

#### Usage:

1. **Sound Files**: Place your sound files in `~/WRB/` or on a USB drive
   - **Quick Press Sounds**: `button1*.wav`, `button2*.wav`
   - **Hold Sounds**: `hold1*.wav`, `hold2*.wav`
   - **USB Drive**: Place files in root directory of USB drive

2. **Button Mapping**:
   - **Button 1 Quick Press** → Plays `button1*.wav` sound
   - **Button 1 Hold (1s)** → Plays `hold1*.wav` sound
   - **Button 2 Quick Press** → Plays `button2*.wav` sound
   - **Button 2 Hold (1s)** → Plays `hold2*.wav` sound

3. **Monitoring**:
   ```bash
   # Check service status
   sudo systemctl status WRB-enhanced.service
   
   # View real-time logs
   sudo journalctl -u WRB-enhanced.service -f
   
   # View button press history
   tail -f ~/WRB/button_log.txt
   ```

#### Configuration:

The script automatically detects:
- ESP32 serial connection (tries multiple ports)
- Sound files from USB drives or local storage
- LED feedback on GPIO pin 23 (ready status)
- USB drive status on GPIO pin 24

You can customize the configuration by editing the variables at the top of the Pi script:
```python
BAUD = 115200                    # Serial baud rate
SERIAL = "/dev/ttyACM0"          # Default serial port
READY_PIN = 23                   # Ready LED pin
USB_LED_PIN = 24                 # USB drive LED pin
HOLD_DELAY_MS = 1000             # Hold delay in milliseconds
LOG_FILE = "/home/pi/WRB/button_log.txt"  # Log file location
```

#### LED Indicators:

The system uses two LEDs for status indication:

1. **Ready LED (GPIO 23)**: 
   - **ON**: System ready and connected to ESP32
   - **OFF**: System starting up or disconnected
   - **Blink**: Button press or hold detected

2. **USB LED (GPIO 24)**:
   - **ON**: USB drive is mounted
   - **OFF**: No USB drive mounted
   - **Blink**: USB drive with sound files detected

#### Testing USB LED:

You can test the USB LED functionality independently using the test script:

```bash
# Run the USB LED test script
python3 test_usb_led.py
```

This script will:
- Check for mounted USB drives
- Control the USB LED based on mount status
- Test sound file detection
- Provide feedback in simulation mode if gpiozero is not available

#### Troubleshooting:

1. **No Sound**: Check audio permissions and pygame installation
2. **No Serial Connection**: Verify ESP32 is connected and check serial port
3. **Service Won't Start**: Check logs with `sudo journalctl -u WRB-enhanced.service`
4. **Permission Errors**: Ensure pi user is in the audio group
5. **USB LED Not Working**: Check GPIO pin 24 connections and run test script
6. **Hold Sounds Not Playing**: Verify hold sound files are properly named and located
7. **Wrong Sound Playing**: Check file naming convention matches expected pattern

The enhanced Pi script provides a complete, production-ready solution for integrating your ESP32 wireless button system with advanced audio feedback, including the new hold functionality, on a Raspberry Pi.
