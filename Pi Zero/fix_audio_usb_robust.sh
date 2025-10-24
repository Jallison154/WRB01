#!/bin/bash
# Robust USB Audio Configuration for WRB01
# Handles USB audio cards with proper fallback

echo "=== WRB01 Robust USB Audio Configuration ==="
echo "============================================="
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

# 1. Detect available audio devices
print_step "Detecting available audio devices..."
echo "Available audio cards:"
aplay -l 2>/dev/null || echo "No audio devices found"
echo

# 2. Check if USB audio is available
print_step "Checking USB audio availability..."
USB_AUDIO_AVAILABLE=false
if aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    USB_AUDIO_AVAILABLE=true
    print_success "✓ USB audio (card 1) is working"
else
    print_warning "⚠ USB audio (card 1) not available"
fi

# 3. Check built-in audio
print_step "Checking built-in audio..."
BUILTIN_AUDIO_AVAILABLE=false
if aplay -D plughw:0,0 /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    BUILTIN_AUDIO_AVAILABLE=true
    print_success "✓ Built-in audio (card 0) is working"
else
    print_warning "⚠ Built-in audio (card 0) not available"
fi

# 4. Create appropriate ALSA configuration
print_step "Creating ALSA configuration..."

if [ "$USB_AUDIO_AVAILABLE" = true ]; then
    print_info "Configuring USB audio as primary with built-in fallback..."
    sudo tee /etc/asound.conf > /dev/null << EOF
# WRB01 Audio Configuration - USB Primary, Built-in Fallback
pcm.!default {
    type hw
    card 1
    device 0
}

ctl.!default {
    type hw
    card 1
}

# USB audio device
pcm.usb {
    type hw
    card 1
    device 0
}

ctl.usb {
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

# Fallback configuration
pcm.fallback {
    type hw
    card 0
    device 0
}

ctl.fallback {
    type hw
    card 0
}
EOF
    print_success "USB audio configured as primary"
    
elif [ "$BUILTIN_AUDIO_AVAILABLE" = true ]; then
    print_info "Configuring built-in audio as primary (USB not available)..."
    sudo tee /etc/asound.conf > /dev/null << EOF
# WRB01 Audio Configuration - Built-in Primary
pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}

# Built-in audio device
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
    print_success "Built-in audio configured as primary"
    
else
    print_error "No audio devices available!"
    exit 1
fi

# 5. Test the configuration
print_step "Testing audio configuration..."
if aplay -D default /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    print_success "✓ Default audio configuration works"
else
    print_error "✗ Default audio configuration failed"
fi

# 6. Update Python script with better audio handling
print_step "Updating Python script with robust audio handling..."
sudo tee /home/wrb01/simple_audio_player.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""
WRB Simple Audio Player for ESP32 Button System
Robust audio handling with USB audio priority and fallback
"""

import os, glob, time, random, sys, serial

# ALSA device configuration - try USB first, fallback to built-in
os.environ.setdefault("SDL_AUDIODRIVER", "alsa")

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
    
    # Try different audio devices in order of preference
    audio_devices = [
        "plughw:1,0",  # USB audio
        "plughw:0,0",  # Built-in audio
        "default"      # System default
    ]
    
    for device in audio_devices:
        for i in range(3):  # Try each device 3 times
            try:
                os.environ['AUDIODEV'] = device
                pygame.mixer.init(frequency=MIX_FREQ, size=-16, channels=2, buffer=MIX_BUF)
                _mixer_ready = True
                print(f"[wrb] audio: mixer ready on {device}", flush=True)
                return
            except Exception as e:
                print(f"[wrb] audio init retry {i+1} on {device}: {e}", flush=True)
                time.sleep(0.2)
    
    raise SystemExit("audio init failed on all devices")

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

# 7. Restart the service
print_step "Restarting WRB service..."
sudo systemctl daemon-reload
sudo systemctl restart wrb-simple.service

# 8. Test the service
print_step "Testing service..."
sleep 2
if systemctl is-active --quiet wrb-simple.service; then
    print_success "✓ Service is running"
    echo "Service logs (last 5 lines):"
    sudo journalctl -u wrb-simple.service -n 5 --no-pager
else
    print_error "✗ Service failed to start"
    echo "Service status:"
    sudo systemctl status wrb-simple.service --no-pager
fi

echo
print_success "=== AUDIO CONFIGURATION COMPLETE ==="
print_info "Your USB audio card should now work properly"
print_info "If you're still having issues, run: ./audio_diagnostic.sh"
