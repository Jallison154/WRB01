#!/usr/bin/env python3
"""
WRB Simple Audio Player for ESP32 Button System
Production-ready version with comprehensive reliability features
Optimized for fast startup (target: < 3 seconds to ready)
"""

import os
import glob
import time
import serial
# Lazy imports for faster startup
try:
    import signal
    import sys
    import threading
    import traceback
    from pathlib import Path
except ImportError as e:
    print(f"[wrb] Warning: Import failed: {e}", flush=True)

# ALSA device configuration - try USB first, fallback to built-in
os.environ.setdefault("SDL_AUDIODRIVER", "alsa")

# =============================================================================
# CONFIGURATION
# =============================================================================

BAUD = 115200
SERIAL = os.getenv("WRB_SERIAL", "/dev/ttyACM0")
READY_PIN = 18
READY_ACTIVE_LOW = True
MIX_FREQ = 44100
MIX_BUF = 256
RESCAN_SEC = 1.0
IDLE_SHUTOFF_SEC = 0   # Keep mixer always active for instant response

# Reliability Configuration
MAX_SERIAL_RETRIES = 5          # Maximum retries for serial reconnection
SERIAL_RECONNECT_DELAY = 2.0    # Delay between serial reconnection attempts
WATCHDOG_TIMEOUT = 30           # Watchdog timeout in seconds
HEALTH_CHECK_INTERVAL = 5       # Health check interval in seconds
MAX_CONSECUTIVE_ERRORS = 10     # Maximum consecutive errors before restart

# Logging
LOG_DIR = Path("/var/log/wrb01")
LOG_FILE = LOG_DIR / "simple_audio_player.log"

# =============================================================================
# LOGGING SYSTEM
# =============================================================================

def setup_logging():
    """Setup logging directory and file"""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    return

def log_message(level, message):
    """Log message with timestamp"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}\n"
    try:
        with open(LOG_FILE, "a") as f:
            f.write(log_entry)
    except Exception as e:
        print(f"Failed to write to log: {e}", flush=True)
    print(log_entry.strip(), flush=True)

def log_error(message, exc_info=False):
    """Log error with optional traceback"""
    log_message("ERROR", message)
    if exc_info:
        try:
            tb = traceback.format_exc()
            with open(LOG_FILE, "a") as f:
                f.write(tb + "\n")
        except:
            pass

def log_info(message):
    """Log info message"""
    log_message("INFO", message)

def log_warning(message):
    """Log warning message"""
    log_message("WARNING", message)

def log_debug(message):
    """Log debug message"""
    log_message("DEBUG", message)

# =============================================================================
# GLOBAL STATE TRACKING
# =============================================================================

class SystemHealth:
    """Track system health and reliability metrics"""
    def __init__(self):
        self.consecutive_errors = 0
        self.last_error_time = 0
        self.serial_errors = 0
        self.audio_errors = 0
        self.button_presses = 0
        self.last_activity = time.time()
        self.start_time = time.time()
        self.serial_reconnect_count = 0
        self.health_check_failures = 0
        
    def record_error(self, error_type="general"):
        """Record an error occurrence"""
        self.consecutive_errors += 1
        self.last_error_time = time.time()
        if error_type == "serial":
            self.serial_errors += 1
        elif error_type == "audio":
            self.audio_errors += 1
            
    def record_success(self):
        """Record a successful operation"""
        self.consecutive_errors = 0
        
    def record_button_press(self):
        """Record button activity"""
        self.button_presses += 1
        self.last_activity = time.time()
        
    def get_uptime(self):
        """Get system uptime in seconds"""
        return time.time() - self.start_time
        
    def should_restart(self):
        """Check if system should restart due to error count"""
        return self.consecutive_errors >= MAX_CONSECUTIVE_ERRORS
        
    def get_status(self):
        """Get current health status"""
        return {
            "uptime": self.get_uptime(),
            "consecutive_errors": self.consecutive_errors,
            "serial_errors": self.serial_errors,
            "audio_errors": self.audio_errors,
            "button_presses": self.button_presses,
            "serial_reconnects": self.serial_reconnect_count,
            "health_check_failures": self.health_check_failures
        }

health = SystemHealth()

# --- LED (simple on/off, active-low wiring) ---
from gpiozero import PWMLED
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

        # read serial and play (only if serial device exists)
        if ser:
            try:
                line = ser.readline().decode(errors="ignore")
            except Exception:
                time.sleep(0.05)
                continue
            if not line:
                continue
        else:
            # No serial device - just wait
            time.sleep(0.1)
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