#!/bin/bash
# Easy Install Script for WRB01 Simple Button + Audio System
# Pulls from GitHub repository and sets up everything automatically

echo "=== WRB01 Simple Button + Audio System ==="
echo "Easy Installation Script"
echo "================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root"
    print_info "Please run as a regular user (pi or wrb01)"
    exit 1
fi

# Check internet connectivity
print_step "Checking internet connectivity..."
if ! ping -c 1 google.com >/dev/null 2>&1; then
    print_error "No internet connection detected"
    print_info "Please ensure your Raspberry Pi is connected to the internet"
    exit 1
fi
print_success "Internet connection verified"

# Update system
print_step "Updating system packages..."
sudo apt update -y
sudo apt upgrade -y
print_success "System packages updated"

# Install required packages
print_step "Installing required packages..."
sudo apt install -y python3-pygame python3-serial python3-numpy python3-gpiozero alsa-utils git
print_success "Required packages installed"

# Remove old installation and clone fresh repository
print_step "Removing old installation and cloning fresh repository..."

# Stop and disable old service if it exists
if systemctl is-active --quiet wrb-simple.service 2>/dev/null; then
    print_info "Stopping old service..."
    sudo systemctl stop wrb-simple.service
    sudo systemctl disable wrb-simple.service
fi

# Remove old service file
if [ -f "/etc/systemd/system/wrb-simple.service" ]; then
    print_info "Removing old service file..."
    sudo rm -f /etc/systemd/system/wrb-simple.service
    sudo systemctl daemon-reload
fi

# Remove old WRB01 directory
if [ -d "WRB01" ]; then
    print_info "Removing old repository..."
    rm -rf WRB01
fi

# Clone fresh repository
print_info "Cloning fresh repository..."
git clone https://github.com/Jallison154/WRB01.git
cd WRB01
git checkout WRB01
cd ..
print_success "Fresh repository cloned"

# Create wrb01 user if it doesn't exist
print_step "Setting up user environment..."
if ! id "wrb01" &>/dev/null; then
    print_info "Creating wrb01 user..."
    sudo useradd -m -s /bin/bash wrb01
    print_success "wrb01 user created"
else
    print_info "wrb01 user already exists"
fi

# Add wrb01 to necessary groups
sudo usermod -a -G audio,gpio,dialout,spi,i2c,plugdev,render,input wrb01
print_success "User groups configured"

# Clean up old files and create fresh audio directory
print_step "Cleaning up old files and setting up fresh audio directory..."

# Remove old audio files
if [ -d "/home/wrb01/audio" ]; then
    print_info "Removing old audio files..."
    sudo rm -rf /home/wrb01/audio
fi

# Remove old Python script
if [ -f "/home/wrb01/simple_audio_player.py" ]; then
    print_info "Removing old Python script..."
    sudo rm -f /home/wrb01/simple_audio_player.py
fi

# Remove old test script
if [ -f "/home/wrb01/test_buttons.py" ]; then
    print_info "Removing old test script..."
    sudo rm -f /home/wrb01/test_buttons.py
fi

# Create fresh audio directory
sudo mkdir -p /home/wrb01/audio
sudo chown wrb01:wrb01 /home/wrb01/audio
print_success "Fresh audio directory created"

# Configure USB audio interface as default
print_step "Configuring USB audio interface as default..."
sudo tee /etc/asound.conf > /dev/null << EOF
# USB Audio Configuration - USB as default
pcm.!default {
    type hw
    card 1
    device 0
}
ctl.!default {
    type hw
    card 1
}

# Built-in audio fallback
pcm.builtin {
    type hw
    card 0
    device 0
}
ctl.builtin {
    type hw
    card 0
}
EOF
print_success "USB audio configured as default"

# Copy audio files from repository
print_step "Copying audio files..."
if [ -d "WRB01/Pi Zero/Default Sounds" ]; then
    sudo cp "WRB01/Pi Zero/Default Sounds/button1.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ button1.wav copied" || echo "⚠ button1.wav not found"
    sudo cp "WRB01/Pi Zero/Default Sounds/button2.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ button2.wav copied" || echo "⚠ button2.wav not found"
    sudo cp "WRB01/Pi Zero/Default Sounds/hold1.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ hold1.wav copied" || echo "⚠ hold1.wav not found"
    sudo cp "WRB01/Pi Zero/Default Sounds/hold2.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ hold2.wav copied" || echo "⚠ hold2.wav not found"
    
    # Set proper ownership
    sudo chown wrb01:wrb01 /home/wrb01/audio/*.wav 2>/dev/null || true
    print_success "Audio files copied"
else
    print_error "Default Sounds directory not found in repository"
    print_info "Please add your audio files manually to /home/wrb01/audio/"
fi

# Copy Python scripts
print_step "Installing Python scripts..."
sudo cp "WRB01/Pi Zero/simple_audio_player.py" /home/wrb01/
sudo chown wrb01:wrb01 /home/wrb01/simple_audio_player.py
sudo chmod +x /home/wrb01/simple_audio_player.py

# Update Python script with robust audio handling
print_info "Installing robust Python script..."
sudo tee /home/wrb01/simple_audio_player.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""
WRB Simple Audio Player for ESP32 Button System
Based on working mattsfx code with proper audio handling
"""

import os, glob, time, random, sys, serial

# ALSA device configuration
os.environ.setdefault("SDL_AUDIODRIVER", "alsa")
os.environ.setdefault("AUDIODEV", "plughw:1,0")  # USB audio device

BAUD = 115200
SERIAL = os.getenv("WRB_SERIAL", "/dev/ttyACM0")
READY_PIN = 18
READY_ACTIVE_LOW = True
MIX_FREQ = 44100
MIX_BUF = 256
RESCAN_SEC = 1.0
IDLE_SHUTOFF_SEC = 1.0   # close audio device this long after last cue

# --- LED (simple on/off, active-low wiring) ---
from gpiozero import LED
led = LED(READY_PIN, active_high=(not READY_ACTIVE_LOW))

def usb_mount_dirs():
    base = "/media"
    return [os.path.join(base, d) for d in sorted(os.listdir(base))
            if os.path.isdir(os.path.join(base, d)) and os.path.ismount(os.path.join(base, d))] if os.path.isdir(base) else []

def pick_source():
    # Check USB drives first
    for mnt in usb_mount_dirs():
        button1 = sorted(glob.glob(os.path.join(mnt, "button1*.wav")))
        button2 = sorted(glob.glob(os.path.join(mnt, "button2*.wav")))
        hold1 = sorted(glob.glob(os.path.join(mnt, "hold1*.wav")))
        hold2 = sorted(glob.glob(os.path.join(mnt, "hold2*.wav")))
        if button1 or button2 or hold1 or hold2:
            return (f"USB:{mnt}", button1[:1], button2[:1], hold1[:1], hold2[:1])
    
    # Fallback to local directory
    local = "/home/wrb01/audio"
    os.makedirs(local, exist_ok=True)
    button1 = sorted(glob.glob(os.path.join(local, "button1*.wav")))
    button2 = sorted(glob.glob(os.path.join(local, "button2*.wav")))
    hold1 = sorted(glob.glob(os.path.join(local, "hold1*.wav")))
    hold2 = sorted(glob.glob(os.path.join(local, "hold2*.wav")))
    return ("LOCAL", button1[:1], button2[:1], hold1[:1], hold2[:1])

def classify(s):
    u = s.strip().upper()
    if "BTN1" in u or "BUTTON1" in u: return 'BTN1'
    if "BTN2" in u or "BUTTON2" in u: return 'BTN2'
    if "HOLD1" in u: return 'HOLD1'
    if "HOLD2" in u: return 'HOLD2'
    return None

# --- on-demand audio helpers (no background output) ---
_mixer_ready = False
_last_play = 0
_button1_paths = []
_button2_paths = []
_hold1_paths = []
_hold2_paths = []

def set_paths(btn1, btn2, h1, h2):
    global _button1_paths, _button2_paths, _hold1_paths, _hold2_paths
    _button1_paths, _button2_paths, _hold1_paths, _hold2_paths = btn1, btn2, h1, h2

def ensure_mixer():
    global _mixer_ready
    if _mixer_ready: return
    import pygame
    for i in range(8):
        try:
            pygame.mixer.init(frequency=MIX_FREQ, size=-16, channels=2, buffer=MIX_BUF)
            _mixer_ready = True
            print("[wrb] audio: mixer ready", flush=True)
            return
        except Exception as e:
            print(f"[wrb] audio init retry {i+1}: {e}", flush=True)
            time.sleep(0.2)
    raise SystemExit("audio init failed")

def shutdown_mixer_if_idle():
    global _mixer_ready
    if not _mixer_ready: return
    import pygame
    if (time.time() - _last_play) > IDLE_SHUTOFF_SEC and not pygame.mixer.get_busy():
        pygame.mixer.quit()
        _mixer_ready = False
        print("[wrb] audio: mixer closed (idle)", flush=True)

def play_button1():
    global _last_play
    if not _button1_paths:
        print("[wrb] BUTTON1 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_button1_paths[0])
    pygame.mixer.Channel(0).play(s)
    _last_play = time.time()

def play_button2():
    global _last_play
    if not _button2_paths:
        print("[wrb] BUTTON2 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_button2_paths[0])
    pygame.mixer.Channel(1).play(s)
    _last_play = time.time()

def play_hold1():
    global _last_play
    if not _hold1_paths:
        print("[wrb] HOLD1 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_hold1_paths[0])
    pygame.mixer.Channel(2).play(s)
    _last_play = time.time()

def play_hold2():
    global _last_play
    if not _hold2_paths:
        print("[wrb] HOLD2 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_hold2_paths[0])
    pygame.mixer.Channel(3).play(s)
    _last_play = time.time()

def wait_serial():
    print("[wrb] waiting for serial…", flush=True)
    prefs = [SERIAL, "/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"]
    while True:
        for p in prefs:
            try:
                return serial.Serial(p, BAUD, timeout=0.1)
            except:
                pass
        time.sleep(0.3)

def main():
    led.off()  # OFF until ready

    # source scan + initial paths (no mixer init yet)
    tag, btn1, btn2, h1, h2 = pick_source()
    set_paths(btn1, btn2, h1, h2)
    print(f"[wrb] source={tag} btn1={btn1} btn2={btn2} hold1={h1} hold2={h2}", flush=True)

    ser = wait_serial()
    print(f"[wrb] serial: {ser.port}", flush=True)

    led.on()
    print("[wrb] READY", flush=True)
    last_scan = time.time()

    while True:
        # hot-swap (update file paths only)
        if time.time() - last_scan > RESCAN_SEC:
            ntag, nbtn1, nbtn2, nh1, nh2 = pick_source()
            if (ntag != tag) or (nbtn1 != btn1) or (nbtn2 != btn2) or (nh1 != h1) or (nh2 != h2):
                tag, btn1, btn2, h1, h2 = ntag, nbtn1, nbtn2, nh1, nh2
                set_paths(btn1, btn2, h1, h2)
                print(f"[wrb] reloaded: source={tag} btn1={btn1} btn2={btn2} hold1={h1} hold2={h2}", flush=True)
            last_scan = time.time()

        # read serial and play
        try:
            line = ser.readline().decode(errors="ignore")
        except Exception:
            time.sleep(0.05)
            continue
        if not line:
            shutdown_mixer_if_idle()
            continue

        t = classify(line)
        if t == 'BTN1':
            print("[wrb] BUTTON1", flush=True)
            play_button1()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass
        elif t == 'BTN2':
            print("[wrb] BUTTON2", flush=True)
            play_button2()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass
        elif t == 'HOLD1':
            print("[wrb] HOLD1", flush=True)
            play_hold1()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass
        elif t == 'HOLD2':
            print("[wrb] HOLD2", flush=True)
            play_hold2()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass

        shutdown_mixer_if_idle()

if __name__ == "__main__":
    main()
EOF

# Copy test script if it exists, otherwise create it
if [ -f "WRB01/Pi Zero/test_buttons.py" ]; then
    sudo cp "WRB01/Pi Zero/test_buttons.py" /home/wrb01/
    sudo chown wrb01:wrb01 /home/wrb01/test_buttons.py
    sudo chmod +x /home/wrb01/test_buttons.py
    print_info "Test script copied from repository"
else
    print_info "Creating test script locally..."
    sudo tee /home/wrb01/test_buttons.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""
Test script for button triggers
Helps debug serial communication and audio playback
"""

import serial
import time
import os

def test_serial_connection():
    """Test serial connection to ESP32"""
    print("Testing serial connection...")
    
    try:
        ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)
        print("✓ Serial connection established")
        
        # Wait for data
        print("Waiting for button presses (press Ctrl+C to stop)...")
        while True:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8').strip()
                print(f"Received: '{line}' (length: {len(line)})")
                
                # Test button parsing
                if line.startswith("BTN"):
                    button_num = line[3:]
                    print(f"  → Button press detected: {button_num}")
                elif line.startswith("HOLD"):
                    button_num = line[4:]
                    print(f"  → Button hold detected: {button_num}")
                else:
                    print(f"  → Unknown command: {line}")
            
            time.sleep(0.01)
            
    except KeyboardInterrupt:
        print("\nStopping test...")
    except Exception as e:
        print(f"✗ Serial connection failed: {e}")
        print("Make sure ESP32 is connected to /dev/ttyACM0")

def test_audio_files():
    """Test if audio files exist"""
    print("Testing audio files...")
    
    audio_dir = "/home/wrb01/audio"
    files = ["button1.wav", "button2.wav", "hold1.wav", "hold2.wav"]
    
    for file in files:
        file_path = os.path.join(audio_dir, file)
        if os.path.exists(file_path):
            print(f"✓ {file} exists")
        else:
            print(f"✗ {file} not found")

def main():
    print("=== Button Trigger Test ===")
    print()
    
    # Test audio files
    test_audio_files()
    print()
    
    # Test serial connection
    test_serial_connection()

if __name__ == "__main__":
    main()
EOF
    sudo chown wrb01:wrb01 /home/wrb01/test_buttons.py
    sudo chmod +x /home/wrb01/test_buttons.py
    print_info "Test script created locally"
fi

print_success "Python scripts installed"

# Create systemd service
print_step "Creating systemd service..."
sudo tee /etc/systemd/system/wrb-simple.service > /dev/null << EOF
[Unit]
Description=WRB Simple Audio Player
After=network.target
Wants=network.target

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:1,0
ExecStart=/usr/bin/python3 /home/wrb01/simple_audio_player.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable wrb-simple.service
sudo systemctl start wrb-simple.service
print_success "Systemd service created and started"

# Final verification
print_step "Performing final verification..."
if [ -f "/home/wrb01/simple_audio_player.py" ]; then
    print_success "✓ Python script installed"
else
    print_error "✗ Python script not found"
fi

if [ -f "/home/wrb01/audio/button1.wav" ]; then
    print_success "✓ Audio files installed"
else
    print_warning "⚠ Audio files not found"
fi

if systemctl is-active --quiet wrb-simple.service; then
    print_success "✓ Service is running"
else
    print_warning "⚠ Service may not be running"
fi

# Clean up repository
print_step "Cleaning up installation files..."
if [ -d "WRB01" ]; then
    rm -rf WRB01
    print_info "Repository directory removed"
fi

echo
print_success "=== INSTALLATION COMPLETE ==="
echo
print_info "=== USEFUL COMMANDS ==="
print_info "Check service status: sudo systemctl status wrb-simple.service"
print_info "View service logs: sudo journalctl -u wrb-simple.service -f"
print_info "Restart service: sudo systemctl restart wrb-simple.service"
print_info "Stop service: sudo systemctl stop wrb-simple.service"
print_info "Start service: sudo systemctl start wrb-simple.service"
print_info "Test buttons: python3 /home/wrb01/test_buttons.py"
echo
print_info "=== SYSTEM READY ==="
print_info "✓ ESP32 receiver should be connected to /dev/ttyACM0"
print_info "✓ USB audio interface configured"
print_info "✓ Audio files ready"
print_info "✓ Service running automatically"
print_info "✓ Test script available for debugging"
echo
print_info "Your WRB01 Simple Button + Audio System is ready!"
print_info "Press buttons on your ESP32 transmitter to hear audio!"
