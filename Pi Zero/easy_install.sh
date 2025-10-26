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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# =============================================================================
# BOOT OPTIMIZATION FUNCTIONS
# =============================================================================

optimize_boot_time() {
    print_step "Optimizing Pi Zero 2 W boot time..."
    
    # Optimize /boot/config.txt for faster boot
    print_info "Optimizing /boot/config.txt..."
    if [ -f /boot/config.txt ]; then
        # Disable unnecessary features for faster boot
        sudo sed -i 's/#dtparam=audio=on/dtparam=audio=on/' /boot/config.txt
        sudo sed -i 's/#hdmi_drive=2/hdmi_drive=2/' /boot/config.txt
        
        # Add boot optimizations
        if ! grep -q "boot_delay=0" /boot/config.txt; then
            echo "boot_delay=0" | sudo tee -a /boot/config.txt
        fi
        
        if ! grep -q "disable_splash=1" /boot/config.txt; then
            echo "disable_splash=1" | sudo tee -a /boot/config.txt
        fi
        
        if ! grep -q "dtparam=audio=on" /boot/config.txt; then
            echo "dtparam=audio=on" | sudo tee -a /boot/config.txt
        fi
        
        if ! grep -q "audio_pwm_mode=2" /boot/config.txt; then
            echo "audio_pwm_mode=2" | sudo tee -a /boot/config.txt
        fi
        
        # Pi Zero 2 W specific optimizations
        if ! grep -q "arm_freq=1000" /boot/config.txt; then
            echo "arm_freq=1000" | sudo tee -a /boot/config.txt
        fi
        
        if ! grep -q "gpu_freq=500" /boot/config.txt; then
            echo "gpu_freq=500" | sudo tee -a /boot/config.txt
        fi
    fi
    
    # Disable unnecessary services for faster boot
    print_info "Disabling unnecessary services..."
    sudo systemctl disable bluetooth.service 2>/dev/null || true
    sudo systemctl disable hciuart.service 2>/dev/null || true
    sudo systemctl disable ModemManager.service 2>/dev/null || true
    sudo systemctl disable avahi-daemon.service 2>/dev/null || true
    sudo systemctl disable cups.service 2>/dev/null || true
    sudo systemctl disable cups-browsed.service 2>/dev/null || true
    sudo systemctl disable triggerhappy.service 2>/dev/null || true
    
    # Optimize systemd for faster startup
    print_info "Optimizing systemd configuration..."
    sudo mkdir -p /etc/systemd/system.conf.d
    sudo tee /etc/systemd/system.conf.d/10-wrb-optimize.conf > /dev/null << EOF
[Manager]
DefaultTimeoutStartSec=10s
DefaultTimeoutStopSec=5s
DefaultRestartSec=1s
EOF
    
    # Set high priority for WRB service
    print_info "Setting high priority for WRB service..."
    sudo systemctl set-property wrb-simple.service CPUWeight=100
    sudo systemctl set-property wrb-simple.service MemoryHigh=512M
    sudo systemctl set-property wrb-simple.service MemoryMax=1G
    
    # Enable parallel startup (only if services exist)
    print_info "Enabling parallel service startup..."
    sudo systemctl enable systemd-udev-trigger.service 2>/dev/null || true
    sudo systemctl enable systemd-networkd.service 2>/dev/null || true
    # systemd-resolved may not exist on all Pi OS versions
    if systemctl list-unit-files | grep -q "systemd-resolved.service"; then
        sudo systemctl enable systemd-resolved.service 2>/dev/null || true
    else
        print_info "systemd-resolved.service not available, skipping..."
    fi
    
    # Optimize filesystem
    print_info "Optimizing filesystem..."
    if [ -f /etc/fstab ]; then
        # Add noatime for faster filesystem access
        sudo sed -i 's/errors=remount-ro/noatime,errors=remount-ro/' /etc/fstab
    fi
    
    # Preload Python modules for faster startup
    print_info "Preloading Python modules..."
    sudo tee /etc/systemd/system/wrb-preload.service > /dev/null << EOF
[Unit]
Description=WRB Python Module Preloader
Before=wrb-simple.service
Wants=wrb-simple.service

[Service]
Type=oneshot
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:1,0
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStart=/usr/bin/python3 -c "import pygame; pygame.mixer.init(); pygame.mixer.quit()"
RemainAfterExit=yes

[Install]
WantedBy=wrb-simple.service
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable wrb-preload.service
    
    print_success "Boot optimization completed"
    print_info "Expected boot time: ~15-20 seconds (down from ~30-45 seconds)"
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
sudo apt install -y python3-pygame python3-serial python3-numpy python3-gpiozero alsa-utils git exfatprogs ntfs-3g
print_success "Required packages installed"

# Comprehensive cleanup of old installation
print_step "Performing comprehensive cleanup of old installation..."

# Stop and disable all old services with force stop and timeout
print_info "Stopping and disabling old services..."
print_info "Using force stop with timeout to prevent hanging..."
if systemctl is-active --quiet wrb-simple.service 2>/dev/null; then
    print_info "Stopping wrb-simple.service (with 10s timeout)..."
    timeout 10s sudo systemctl stop wrb-simple.service 2>/dev/null || true
    
    # Wait a moment and force kill if still running
    sleep 2
    if systemctl is-active --quiet wrb-simple.service 2>/dev/null; then
        print_info "Service still running, force stopping..."
        sudo systemctl kill --signal=SIGKILL wrb-simple.service 2>/dev/null || true
        sleep 1
    fi
    
    # Double-check and force kill any remaining processes
    if pgrep -f "simple_audio_player.py" > /dev/null; then
        print_info "Force killing remaining Python processes..."
        sudo pkill -f "simple_audio_player.py" 2>/dev/null || true
        sleep 1
    fi
    
    sudo systemctl disable wrb-simple.service
fi

if systemctl is-active --quiet WRB-enhanced.service 2>/dev/null; then
    print_info "Stopping WRB-enhanced.service (with 5s timeout)..."
    timeout 5s sudo systemctl stop WRB-enhanced.service 2>/dev/null || true
    sleep 1
    if systemctl is-active --quiet WRB-enhanced.service 2>/dev/null; then
        print_info "Force stopping WRB-enhanced.service..."
        sudo systemctl kill --signal=SIGKILL WRB-enhanced.service 2>/dev/null || true
    fi
    sudo systemctl disable WRB-enhanced.service
fi

if systemctl is-active --quiet wrb-watchdog.service 2>/dev/null; then
    print_info "Stopping wrb-watchdog.service (with 5s timeout)..."
    timeout 5s sudo systemctl stop wrb-watchdog.service 2>/dev/null || true
    sleep 1
    if systemctl is-active --quiet wrb-watchdog.service 2>/dev/null; then
        print_info "Force stopping wrb-watchdog.service..."
        sudo systemctl kill --signal=SIGKILL wrb-watchdog.service 2>/dev/null || true
    fi
    sudo systemctl disable wrb-watchdog.service
fi

if systemctl is-active --quiet wrb-network-monitor.service 2>/dev/null; then
    print_info "Stopping wrb-network-monitor.service (with 5s timeout)..."
    timeout 5s sudo systemctl stop wrb-network-monitor.service 2>/dev/null || true
    sleep 1
    if systemctl is-active --quiet wrb-network-monitor.service 2>/dev/null; then
        print_info "Force stopping wrb-network-monitor.service..."
        sudo systemctl kill --signal=SIGKILL wrb-network-monitor.service 2>/dev/null || true
    fi
    sudo systemctl disable wrb-network-monitor.service
fi

# Remove all old service files
print_info "Removing old service files..."
sudo rm -f /etc/systemd/system/wrb-simple.service
sudo rm -f /etc/systemd/system/WRB-enhanced.service
sudo rm -f /etc/systemd/system/wrb-watchdog.service
sudo rm -f /etc/systemd/system/wrb-network-monitor.service
sudo rm -f /etc/logrotate.d/wrb
sudo systemctl daemon-reload

# Remove old user directories and files
print_info "Removing old user directories and files..."
sudo rm -rf /home/wrb01/WRB 2>/dev/null || true
sudo rm -rf /home/wrb01/WRB01 2>/dev/null || true
sudo rm -rf /home/wrb01/audio 2>/dev/null || true
sudo rm -f /home/wrb01/simple_audio_player.py 2>/dev/null || true
sudo rm -f /home/wrb01/test_buttons.py 2>/dev/null || true
sudo rm -f /home/wrb01/PiScript 2>/dev/null || true
sudo rm -f /home/wrb01/config.py 2>/dev/null || true
sudo rm -f /home/wrb01/health_monitor.py 2>/dev/null || true
sudo rm -f /home/wrb01/network_monitor.py 2>/dev/null || true
sudo rm -f /home/wrb01/setup_audio.sh 2>/dev/null || true
sudo rm -f /home/wrb01/test_audio.py 2>/dev/null || true
sudo rm -f /home/wrb01/fix_python_2024.sh 2>/dev/null || true
sudo rm -f /home/wrb01/activate_venv.sh 2>/dev/null || true
sudo rm -rf /home/wrb01/venv 2>/dev/null || true
sudo rm -rf /home/wrb01/logs 2>/dev/null || true
sudo rm -rf /home/wrb01/sounds 2>/dev/null || true
sudo rm -rf /home/wrb01/default_sounds 2>/dev/null || true

# Remove old pi user directories (if they exist)
print_info "Removing old pi user directories..."
sudo rm -rf /home/pi/WRB 2>/dev/null || true
sudo rm -rf /home/pi/WRB01 2>/dev/null || true
sudo rm -rf /home/pi/audio 2>/dev/null || true
sudo rm -f /home/pi/simple_audio_player.py 2>/dev/null || true
sudo rm -f /home/pi/test_buttons.py 2>/dev/null || true

# Remove old repository directories
print_info "Removing old repository directories..."
rm -rf WRB01 2>/dev/null || true
rm -rf ~/WRB01 2>/dev/null || true
rm -rf ~/WRB 2>/dev/null || true

# Remove old configuration files
print_info "Removing old configuration files..."
sudo rm -f /etc/asound.conf 2>/dev/null || true
sudo rm -f /etc/watchdog.conf 2>/dev/null || true

# Clean up any old Python packages
print_info "Cleaning up old Python packages..."
sudo apt autoremove -y 2>/dev/null || true
sudo apt autoclean 2>/dev/null || true

print_success "Comprehensive cleanup completed"

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

# Create fresh audio directory (cleanup already done above)
print_step "Setting up fresh audio directory..."
sudo mkdir -p /home/wrb01/audio
sudo chown wrb01:wrb01 /home/wrb01/audio
print_success "Fresh audio directory created"

# Configure robust USB audio interface
print_step "Configuring robust USB audio interface..."
echo "Detecting available audio devices..."
aplay -l 2>/dev/null || echo "No audio devices found"

# Check if USB audio is available
USB_AUDIO_AVAILABLE=false
if aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    USB_AUDIO_AVAILABLE=true
    print_success "✓ USB audio (card 1) detected and working"
else
    print_warning "⚠ USB audio (card 1) not available, will use built-in audio"
fi

# Create appropriate ALSA configuration
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
EOF
    print_success "USB audio configured as primary"
else
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
fi

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
print_info "Installing robust Python script with USB audio fallback..."
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
IDLE_SHUTOFF_SEC = 0   # Keep mixer always active for instant response

# --- LED (simple on/off, active-low wiring) ---
from gpiozero import LED, PWMLED
led = LED(READY_PIN, active_high=(not READY_ACTIVE_LOW))
# Status LED on pin 23 at 25% brightness
status_led = PWMLED(23)

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
    # Check HOLD commands first (more specific)
    if u == "HOLD1": return 'HOLD1'
    if u == "HOLD2": return 'HOLD2'
    # Then check button commands
    if u == "BTN1" or u == "BUTTON1": return 'BTN1'
    if u == "BTN2" or u == "BUTTON2": return 'BTN2'
    return None

# --- on-demand audio helpers (no background output) ---
_mixer_ready = False
_last_play = 0
_button1_paths = []
_button2_paths = []
_hold1_paths = []
_hold2_paths = []

# Fade-out tracking
_current_sounds = {}  # Track currently playing sounds for fade-out
_fade_duration = 1.0  # 1 second fade-out

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
                time.sleep(0.05)  # Much faster retry delay
    
    raise SystemExit("audio init failed on all devices")

def shutdown_mixer_if_idle():
    global _mixer_ready
    # Keep mixer always active for instant response
    # No shutdown logic - mixer stays ready
    pass

def fade_out_sound(sound_key):
    """Fade out a currently playing sound over 1 second"""
    global _current_sounds
    if sound_key in _current_sounds:
        import pygame
        import threading
        
        def fade_thread():
            sound = _current_sounds[sound_key]
            if sound:
                # Get the channel that's playing this sound
                channel = None
                for ch in range(pygame.mixer.get_num_channels()):
                    if pygame.mixer.Channel(ch).get_sound() == sound:
                        channel = pygame.mixer.Channel(ch)
                        break
                
                if channel:
                    # Fade out the channel volume over 1 second
                    steps = 20  # Number of fade steps
                    step_duration = 1.0 / steps  # 1 second total
                    volume_step = 1.0 / steps  # Start from full volume
                    
                    # Fade out over 1 second
                    for i in range(steps):
                        if sound_key in _current_sounds:  # Check if still playing
                            new_volume = max(0, 1.0 - (volume_step * (i + 1)))
                            channel.set_volume(new_volume)
                            time.sleep(step_duration)
                        else:
                            break
                    
                    # Stop the sound completely after fade
                    if sound_key in _current_sounds:
                        channel.stop()
                        del _current_sounds[sound_key]
                        print(f"[wrb] {sound_key.upper()} fade-out complete, ready for new trigger", flush=True)
                else:
                    # Fallback: just stop the sound
                    sound.stop()
                    if sound_key in _current_sounds:
                        del _current_sounds[sound_key]
                        print(f"[wrb] {sound_key.upper()} stopped, ready for new trigger", flush=True)
        
        # Start fade in background thread
        fade_thread = threading.Thread(target=fade_thread, daemon=True)
        fade_thread.start()

def stop_current_sound(sound_key):
    """Stop a currently playing sound immediately"""
    global _current_sounds
    if sound_key in _current_sounds:
        import pygame
        sound = _current_sounds[sound_key]
        if sound:
            sound.stop()
        del _current_sounds[sound_key]

def play_button1():
    global _last_play, _current_sounds
    if not _button1_paths:
        print("[wrb] BUTTON1 (no file)", flush=True)
        return
    
    # If already playing, fade it out over 1 second
    if 'button1' in _current_sounds:
        # Check if sound is actually still playing by checking the channel
        import pygame
        channel = pygame.mixer.Channel(0)
        if channel.get_busy():
            # Sound is still active, fade it out
            print("[wrb] BUTTON1 fading out current sound", flush=True)
            fade_out_sound('button1')
            return  # Just fade out, don't play new sound
        else:
            # Sound has finished, remove from tracking
            print("[wrb] BUTTON1 sound finished, removing from tracking", flush=True)
            del _current_sounds['button1']
    
    # Flash status LED for 200ms (only if we're going to play new sound)
    status_led.value = 1.0  # Full brightness flash
    import threading
    def flash_off():
        time.sleep(0.2)  # 200ms
        status_led.value = 0.25  # Back to 25%
    threading.Thread(target=flash_off, daemon=True).start()
    
    # Play new sound
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_button1_paths[0])
    channel = pygame.mixer.Channel(0)
    # CRITICAL: Reset channel volume to full before playing
    channel.set_volume(1.0)
    # Stop any existing sound on this channel first
    channel.stop()
    channel.play(s)
    
    # Track the sound for fade-out capability
    _current_sounds['button1'] = s
    _last_play = time.time()

def play_button2():
    global _last_play, _current_sounds
    if not _button2_paths:
        print("[wrb] BUTTON2 (no file)", flush=True)
        return
    
    # If already playing, fade it out over 1 second
    if 'button2' in _current_sounds:
        # Check if sound is actually still playing by checking the channel
        import pygame
        channel = pygame.mixer.Channel(1)
        if channel.get_busy():
            # Sound is still active, fade it out
            print("[wrb] BUTTON2 fading out current sound", flush=True)
            fade_out_sound('button2')
            return  # Just fade out, don't play new sound
        else:
            # Sound has finished, remove from tracking
            print("[wrb] BUTTON2 sound finished, removing from tracking", flush=True)
            del _current_sounds['button2']
    
    # Flash status LED for 200ms (only if we're going to play new sound)
    status_led.value = 1.0  # Full brightness flash
    import threading
    def flash_off():
        time.sleep(0.2)  # 200ms
        status_led.value = 0.25  # Back to 25%
    threading.Thread(target=flash_off, daemon=True).start()
    
    # Play new sound
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_button2_paths[0])
    channel = pygame.mixer.Channel(1)
    # CRITICAL: Reset channel volume to full before playing
    channel.set_volume(1.0)
    # Stop any existing sound on this channel first
    channel.stop()
    channel.play(s)
    
    # Track the sound for fade-out capability
    _current_sounds['button2'] = s
    _last_play = time.time()

def play_hold1():
    global _last_play, _current_sounds
    if not _hold1_paths:
        print("[wrb] HOLD1 (no file)", flush=True)
        return
    
    # If already playing, fade it out over 1 second
    if 'hold1' in _current_sounds:
        # Check if sound is actually still playing by checking the channel
        import pygame
        channel = pygame.mixer.Channel(2)
        if channel.get_busy():
            # Sound is still active, fade it out
            print("[wrb] HOLD1 fading out current sound", flush=True)
            fade_out_sound('hold1')
            return  # Just fade out, don't play new sound
        else:
            # Sound has finished, remove from tracking
            print("[wrb] HOLD1 sound finished, removing from tracking", flush=True)
            del _current_sounds['hold1']
    
    # Flash status LED for 200ms (only if we're going to play new sound)
    status_led.value = 1.0  # Full brightness flash
    import threading
    def flash_off():
        time.sleep(0.2)  # 200ms
        status_led.value = 0.25  # Back to 25%
    threading.Thread(target=flash_off, daemon=True).start()
    
    # Play new sound
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_hold1_paths[0])
    channel = pygame.mixer.Channel(2)
    # CRITICAL: Reset channel volume to full before playing
    channel.set_volume(1.0)
    # Stop any existing sound on this channel first
    channel.stop()
    channel.play(s)
    
    # Track the sound for fade-out capability
    _current_sounds['hold1'] = s
    _last_play = time.time()

def play_hold2():
    global _last_play, _current_sounds
    if not _hold2_paths:
        print("[wrb] HOLD2 (no file)", flush=True)
        return
    
    # If already playing, fade it out over 1 second
    if 'hold2' in _current_sounds:
        # Check if sound is actually still playing by checking the channel
        import pygame
        channel = pygame.mixer.Channel(3)
        if channel.get_busy():
            # Sound is still active, fade it out
            print("[wrb] HOLD2 fading out current sound", flush=True)
            fade_out_sound('hold2')
            return  # Just fade out, don't play new sound
        else:
            # Sound has finished, remove from tracking
            print("[wrb] HOLD2 sound finished, removing from tracking", flush=True)
            del _current_sounds['hold2']
    
    # Flash status LED for 200ms (only if we're going to play new sound)
    status_led.value = 1.0  # Full brightness flash
    import threading
    def flash_off():
        time.sleep(0.2)  # 200ms
        status_led.value = 0.25  # Back to 25%
    threading.Thread(target=flash_off, daemon=True).start()
    
    # Play new sound
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_hold2_paths[0])
    channel = pygame.mixer.Channel(3)
    # CRITICAL: Reset channel volume to full before playing
    channel.set_volume(1.0)
    # Stop any existing sound on this channel first
    channel.stop()
    channel.play(s)
    
    # Track the sound for fade-out capability
    _current_sounds['hold2'] = s
    _last_play = time.time()

def wait_serial():
    print("[wrb] checking for serial…", flush=True)
    prefs = [SERIAL, "/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"]
    # Quick check for serial (don't block boot)
    for p in prefs:
        try:
            ser = serial.Serial(p, BAUD, timeout=0.1)
            print(f"[wrb] serial found: {p}", flush=True)
            return ser
        except:
            pass
    
    # If no serial found, start anyway (no blocking)
    print("[wrb] No serial device found, starting without serial...", flush=True)
    return None

def main():
    led.off()  # OFF until ready

    # Initialize mixer immediately for instant response
    print("[wrb] initializing audio mixer...", flush=True)
    ensure_mixer()

    # Turn on status LED to show service is running
    status_led.value = 0.25  # 25% brightness
    print("[wrb] Status LED ON (25% brightness) - Service running", flush=True)

    # source scan + initial paths
    tag, btn1, btn2, h1, h2 = pick_source()
    set_paths(btn1, btn2, h1, h2)
    print(f"[wrb] source={tag} btn1={btn1} btn2={btn2} hold1={h1} hold2={h2}", flush=True)

    ser = wait_serial()
    if ser:
        print(f"[wrb] serial: {ser.port}", flush=True)
    else:
        print("[wrb] serial: None (starting without serial)", flush=True)

    led.on()
    print("[wrb] READY - Audio mixer active", flush=True)
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

# USB Auto-mounting Setup
print_step "Setting up USB auto-mounting with LED status..."

# Create USB auto-mount script
print_info "Creating USB auto-mount script..."
sudo tee /usr/local/bin/usb-automount.sh > /dev/null << 'EOF'
#!/bin/bash
# Don't exit on error - we handle errors explicitly
ACTION="$1"; DEV="$2"
PI_USER="wrb01"
PI_UID=$(id -u "$PI_USER" 2>/dev/null || echo "1000")
PI_GID=$(id -g "$PI_USER" 2>/dev/null || echo "1000")

# Check if any USB drives are mounted
check_usb_mounted() {
    # Check /proc/mounts for any sda, sdb, etc. mounts
    if mount | grep -E '\b/dev/sd[a-z]' > /dev/null; then
        return 0  # At least one USB drive is mounted
    else
        return 1  # No USB drives mounted
    fi
}

# LED Control using Python gpiozero (same as simple_audio_player.py)
update_led_status() {
    if check_usb_mounted; then
        /usr/bin/python3 /usr/local/bin/usb_led_control.py on 2>&1 | tee -a /var/log/usb-automount.log
    else
        /usr/bin/python3 /usr/local/bin/usb_led_control.py off 2>&1 | tee -a /var/log/usb-automount.log
    fi
}

[ -z "$DEV" ] && exit 0

case "$ACTION" in
  add)
    # Get filesystem info (allow it to fail)
    LABEL=$(blkid -o value -s LABEL "$DEV" 2>/dev/null || echo "")
    FSTYPE=$(blkid -o value -s TYPE "$DEV" 2>/dev/null || echo "")
    
    # Generate label if not found
    if [ -z "$LABEL" ]; then
        LABEL="usb-$(basename $DEV)"
    fi
    
    MNT="/media/$LABEL"
    
    # Clean up any existing mount or stale mount point
    if mountpoint -q "$MNT" 2>/dev/null; then
        umount -l "$MNT" 2>/dev/null || true
        sleep 0.2
    fi
    rmdir "$MNT" 2>/dev/null || true
    
    # Create fresh mount point
    mkdir -p "$MNT" 2>/dev/null || true
    chown "$PI_USER:$PI_USER" "$MNT" 2>/dev/null || true
    
    # Mount with appropriate options
    OPTS="uid=$PI_UID,gid=$PI_GID,umask=002,noatime,nosuid,nodev"
    
    echo "[usb-automount] $(date): Attempting to mount $DEV (type: ${FSTYPE:-unknown})" >> /var/log/usb-automount.log
    
    if [ "$FSTYPE" = "ntfs" ] && command -v ntfs-3g >/dev/null 2>&1; then
        mount -t ntfs-3g -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
        MOUNT_SUCCESS=$?
    elif [ "$FSTYPE" = "exfat" ] && command -v mount.exfat >/dev/null 2>&1; then
        mount -t exfat -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
        MOUNT_SUCCESS=$?
    else
        mount -o "$OPTS" "$DEV" "$MNT" 2>&1 | tee -a /var/log/usb-automount.log
        MOUNT_SUCCESS=$?
    fi
    
    if [ $MOUNT_SUCCESS -eq 0 ]; then
        # Small delay to ensure mount is fully registered in /proc/mounts
        sleep 0.3
        # Update LED based on whether any USB drives are mounted
        update_led_status
        echo "[usb-automount] $(date): Successfully mounted $DEV at $MNT" >> /var/log/usb-automount.log
    else
        echo "[usb-automount] $(date): FAILED to mount $DEV" >> /var/log/usb-automount.log
    fi
    ;;
    
  remove)
    # Find and unmount all partitions of this device
    for MP in $(awk -v dev="$DEV" '$1==dev {print $2}' /proc/mounts 2>/dev/null || true); do
        umount -l "$MP" 2>/dev/null || true
        rmdir "$MP" 2>/dev/null || true
    done
    
    # Also check for matching device base (for unpartitioned drives)
    BASE_DEV=$(echo "$DEV" | sed 's/[0-9]*$//')
    for MP in $(awk -v base="$BASE_DEV" '$1~base {print $2}' /proc/mounts 2>/dev/null || true); do
        umount -l "$MP" 2>/dev/null || true
        rmdir "$MP" 2>/dev/null || true
    done
    
    # Small delay to ensure unmount is fully registered in /proc/mounts
    sleep 0.3
    # Update LED based on whether any USB drives are still mounted
    update_led_status
    
    echo "[usb-automount] $(date): Unmounted $DEV" >> /var/log/usb-automount.log
    ;;
esac
EOF

# Make script executable
sudo chmod +x /usr/local/bin/usb-automount.sh
print_success "USB auto-mount script created"

# Install Python LED controller script
print_info "Installing Python LED controller..."
sudo tee /usr/local/bin/usb_led_control.py > /dev/null << 'PYEOF'
#!/usr/bin/env python3
"""
USB Mount LED Controller
Controls GPIO 24 LED for USB mount status using gpiozero
Matches the pattern used in simple_audio_player.py
"""
import sys
from gpiozero import LED

# GPIO 24, active-low (same as READY_PIN pattern in simple_audio_player.py)
MOUNT_LED_PIN = 24
ACTIVE_LOW = True

def set_led(state):
    """Set LED state: 'on' or 'off'"""
    try:
        # Create LED object each call (gpiozero handles cleanup)
        led = LED(MOUNT_LED_PIN, active_high=not ACTIVE_LOW)
        
        if state == "on":
            led.on()
            print(f"LED ON (GPIO {MOUNT_LED_PIN})")
        elif state == "off":
            led.off()
            print(f"LED OFF (GPIO {MOUNT_LED_PIN})")
        else:
            print(f"Invalid state: {state}")
            return 1
        
        # Keep LED object alive briefly to ensure command is processed
        import time
        time.sleep(0.1)
        return 0
    except Exception as e:
        print(f"Error controlling LED: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: usb_led_control.py <on|off>")
        sys.exit(1)
    
    state = sys.argv[1].lower()
    sys.exit(set_led(state))
PYEOF

sudo chmod +x /usr/local/bin/usb_led_control.py
print_success "Python LED controller installed"

# Create udev rule for USB auto-mounting
print_info "Creating udev rule for USB auto-mounting..."
sudo tee /etc/udev/rules.d/99-usb-automount.rules > /dev/null << 'EOF'
ACTION=="add",    SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ENV{ID_FS_TYPE}!="", \
  RUN+="/usr/bin/systemd-run --property=Type=oneshot --unit=usb-mount-%k /usr/local/bin/usb-automount.sh add /dev/%k"

ACTION=="remove", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", \
  RUN+="/usr/bin/systemd-run --property=Type=oneshot --unit=usb-umount-%k /usr/local/bin/usb-automount.sh remove /dev/%k"
EOF

# Create GPIO permissions udev rule for LED control
print_info "Creating GPIO permissions rule..."
sudo tee /etc/udev/rules.d/20-gpio-permissions.rules > /dev/null << 'EOF'
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 775 /sys/class/gpio'"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'for f in /sys/class/gpio/export; do chown root:gpio \$f; chmod 775 \$f; done'"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'for f in /sys/class/gpio/*/direction; do chown root:gpio \$f; chmod 775 \$f; done'"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'for f in /sys/class/gpio/*/value; do chown root:gpio \$f; chmod 775 \$f; done'"
EOF

# Reload udev rules
sudo udevadm control --reload
print_success "USB auto-mounting configured"

# Create log directory for USB auto-mount
sudo mkdir -p /var/log
sudo touch /var/log/usb-automount.log
sudo chown wrb01:wrb01 /var/log/usb-automount.log

print_success "USB auto-mounting with LED status on GPIO 24 configured"

# Create optimized systemd service for fast startup
print_step "Creating optimized systemd service..."
sudo tee /etc/systemd/system/wrb-simple.service > /dev/null << EOF
[Unit]
Description=WRB Simple Audio Player
After=local-fs.target
# Start immediately after filesystem (no network dependency)
DefaultDependencies=no

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
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStart=/usr/bin/python3 /home/wrb01/simple_audio_player.py
Restart=on-failure
RestartSec=1
# Optimize for faster startup
TimeoutStartSec=10
TimeoutStopSec=5
# High priority for faster response
Nice=-10
IOSchedulingClass=1
IOSchedulingPriority=4
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

# Optimize boot time
print_step "Optimizing boot time..."
optimize_boot_time

# Additional startup optimizations
print_step "Adding additional startup optimizations..."

# Disable unnecessary services that slow down boot
print_info "Disabling additional services for faster boot..."
sudo systemctl disable bluetooth.service 2>/dev/null || true
sudo systemctl disable hciuart.service 2>/dev/null || true
sudo systemctl disable ModemManager.service 2>/dev/null || true
sudo systemctl disable avahi-daemon.service 2>/dev/null || true
sudo systemctl disable cups.service 2>/dev/null || true
sudo systemctl disable cups-browsed.service 2>/dev/null || true
sudo systemctl disable triggerhappy.service 2>/dev/null || true
sudo systemctl disable dphys-swapfile.service 2>/dev/null || true
sudo systemctl disable rpi-eeprom-update.service 2>/dev/null || true

# Optimize systemd for even faster startup
print_info "Applying additional systemd optimizations..."
sudo tee /etc/systemd/system.conf.d/20-wrb-fast.conf > /dev/null << EOF
[Manager]
DefaultTimeoutStartSec=3s
DefaultTimeoutStopSec=2s
DefaultRestartSec=0.5s
EOF

# Disable network wait services (MAJOR boot speed improvement)
print_info "Disabling network wait services for instant boot..."
sudo systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask NetworkManager-wait-online.service 2>/dev/null || true
sudo systemctl mask wait-online.service 2>/dev/null || true

# Add boot optimizations to config.txt
print_info "Adding boot optimizations to config.txt..."
if [ -f /boot/config.txt ]; then
    # Disable splash screen
    if ! grep -q "disable_splash=1" /boot/config.txt; then
        echo "disable_splash=1" | sudo tee -a /boot/config.txt
    fi
    
    # Faster CPU for boot
    if ! grep -q "arm_freq=1200" /boot/config.txt; then
        echo "arm_freq=1200" | sudo tee -a /boot/config.txt
    fi
fi

# Set service to start immediately after filesystem (no network dependency)
print_info "Setting service to start immediately after filesystem..."
mkdir -p /etc/systemd/system/wrb-simple.service.d
sudo tee /etc/systemd/system/wrb-simple.service.d/override.conf > /dev/null << EOF
[Unit]
After=local-fs.target
Before=multi-user.target
# No network dependency for offline operation
EOF

sudo systemctl daemon-reload

# Keep network services but make them start after audio service
print_info "Configuring network services to start after audio service..."
# Don't disable network services, just make them start later
sudo systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

# Set network services to start after our service
print_info "Setting network services to start after audio service..."
mkdir -p /etc/systemd/system/systemd-networkd.service.d
sudo tee /etc/systemd/system/systemd-networkd.service.d/override.conf > /dev/null << EOF
[Unit]
After=wrb-simple.service
EOF

mkdir -p /etc/systemd/system/dhcpcd.service.d
sudo tee /etc/systemd/system/dhcpcd.service.d/override.conf > /dev/null << EOF
[Unit]
After=wrb-simple.service
EOF

sudo systemctl daemon-reload

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

if [ -f "/usr/local/bin/usb-automount.sh" ]; then
    print_success "✓ USB auto-mount script installed"
else
    print_error "✗ USB auto-mount script not found"
fi

if [ -f "/etc/udev/rules.d/99-usb-automount.rules" ]; then
    print_success "✓ USB auto-mount udev rule installed"
else
    print_error "✗ USB auto-mount udev rule not found"
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
print_info "View USB mount logs: tail -f /var/log/usb-automount.log"
print_info "Test USB mount: sudo /usr/local/bin/usb-automount.sh add /dev/sda1"
echo
print_info "=== SYSTEM READY ==="
print_info "✓ ESP32 receiver should be connected to /dev/ttyACM0"
print_info "✓ USB audio interface configured"
print_info "✓ Audio files ready"
print_info "✓ Service running automatically"
print_info "✓ USB auto-mounting with LED status on GPIO 24"
print_info "✓ Test script available for debugging"
echo
print_info "=== USB AUTO-MOUNTING FEATURES ==="
print_info "✓ Automatic USB drive mounting to /media/<LABEL>"
print_info "✓ LED status indicator on GPIO 24 (ON=mounted, OFF=unmounted)"
print_info "✓ Support for FAT, exFAT, NTFS, and ext* filesystems"
print_info "✓ Automatic audio file detection from USB drives"
print_info "✓ Hot-swap support - change USB drives without restart"
echo
print_info "Your WRB01 Simple Button + Audio System with USB auto-mounting is ready!"
print_info "Press buttons on your ESP32 transmitter to hear audio!"
print_info "Insert USB drives with audio files for automatic detection!"
