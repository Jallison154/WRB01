#!/usr/bin/env python3
"""
Create Clean WRB Script
Create a clean, working script using the reference pattern
"""
import os

def create_clean_script():
    """Create a clean WRB script using the reference pattern"""
    print("=== Creating Clean WRB Script ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    script_path = f"{script_dir}/PiScript"
    
    # Create a clean script using the reference pattern
    clean_script = '''#!/usr/bin/env python3
"""
WRB Enhanced Audio System - Clean Version
"""
import os, glob, time, random, sys, serial, threading, logging
from pathlib import Path

# ALSA device configuration
os.environ.setdefault("SDL_AUDIODRIVER", "alsa")
os.environ.setdefault("AUDIODEV", "default")

# Configuration
BAUD = 115200
SERIAL = os.getenv("WRB_SERIAL", "/dev/ttyACM0")
READY_PIN = 23
USB_LED_PIN = 24
MIX_FREQ = 22050
MIX_BUF = 512
RESCAN_SEC = 1.0
IDLE_SHUTOFF_SEC = 2.0

# Global variables
running = True
serial_conn = None
_mixer_ready = False
_last_play = 0
sound_files = {}

# Setup logging
def setup_logging():
    """Setup logging"""
    os.makedirs("logs", exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('logs/wrb.log'),
            logging.StreamHandler()
        ]
    )
    return logging.getLogger(__name__)

# Try to import GPIO, fallback if not available
try:
    import RPi.GPIO as GPIO
    GPIO.setwarnings(False)
    GPIO_AVAILABLE = True
except ImportError:
    print("Warning: RPi.GPIO not available, GPIO features disabled")
    GPIO_AVAILABLE = False
    GPIO = None

# LED control
def setup_gpio():
    """Initialize GPIO pins"""
    if not GPIO_AVAILABLE:
        return True
        
    try:
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(READY_PIN, GPIO.OUT)
        GPIO.setup(USB_LED_PIN, GPIO.OUT)
        GPIO.output(READY_PIN, GPIO.HIGH)
        GPIO.output(USB_LED_PIN, GPIO.LOW)
        return True
    except Exception as e:
        print(f"GPIO setup failed: {e}")
        return False

def cleanup_gpio():
    """Clean up GPIO pins"""
    if not GPIO_AVAILABLE:
        return
    try:
        GPIO.cleanup()
    except:
        pass

def flash_ready_led():
    """Flash ready LED"""
    if not GPIO_AVAILABLE:
        return
    try:
        GPIO.output(READY_PIN, GPIO.LOW)
        time.sleep(0.1)
        GPIO.output(READY_PIN, GPIO.HIGH)
    except:
        pass

# USB detection
def usb_mount_dirs():
    """Get USB mount directories"""
    base = "/media"
    if not os.path.isdir(base):
        return []
    return [os.path.join(base, d) for d in sorted(os.listdir(base))
            if os.path.isdir(os.path.join(base, d)) and os.path.ismount(os.path.join(base, d))]

def find_sound_files():
    """Find sound files"""
    global sound_files
    
    # Check USB drives first
    for mnt in usb_mount_dirs():
        button1 = sorted(glob.glob(os.path.join(mnt, "button1.wav")))
        button2 = sorted(glob.glob(os.path.join(mnt, "button2.wav")))
        hold1 = sorted(glob.glob(os.path.join(mnt, "hold1.wav")))
        hold2 = sorted(glob.glob(os.path.join(mnt, "hold2.wav")))
        
        if button1 or button2 or hold1 or hold2:
            sound_files = {
                "button1": button1[:1],
                "button2": button2[:1],
                "hold1": hold1[:1],
                "hold2": hold2[:1]
            }
            return f"USB:{mnt}"
    
    # Check local directories
    local_dirs = [
        "sounds",
        "default_sounds",
        os.path.expanduser("~/WRB/sounds"),
        os.path.expanduser("~/WRB/default_sounds")
    ]
    
    for local_dir in local_dirs:
        if os.path.exists(local_dir):
            button1 = sorted(glob.glob(os.path.join(local_dir, "button1.wav")))
            button2 = sorted(glob.glob(os.path.join(local_dir, "button2.wav")))
            hold1 = sorted(glob.glob(os.path.join(local_dir, "hold1.wav")))
            hold2 = sorted(glob.glob(os.path.join(local_dir, "hold2.wav")))
            
            if button1 or button2 or hold1 or hold2:
                sound_files = {
                    "button1": button1[:1],
                    "button2": button2[:1],
                    "hold1": hold1[:1],
                    "hold2": hold2[:1]
                }
                return f"LOCAL:{local_dir}"
    
    return "NONE"

# Audio system
def ensure_mixer():
    """Ensure audio mixer is ready"""
    global _mixer_ready
    if _mixer_ready:
        return
    
    try:
        import pygame
        for i in range(3):
            try:
                pygame.mixer.init(frequency=MIX_FREQ, size=-16, channels=2, buffer=MIX_BUF)
                _mixer_ready = True
                print("[WRB] audio: mixer ready", flush=True)
                return
            except Exception as e:
                print(f"[WRB] audio init retry {i+1}: {e}", flush=True)
                time.sleep(0.2)
        raise Exception("audio init failed")
    except Exception as e:
        print(f"[WRB] audio not available: {e}", flush=True)
        _mixer_ready = False

def shutdown_mixer_if_idle():
    """Shutdown mixer if idle"""
    global _mixer_ready
    if not _mixer_ready:
        return
    
    try:
        import pygame
        if (time.time() - _last_play) > IDLE_SHUTOFF_SEC and not pygame.mixer.get_busy():
            pygame.mixer.quit()
            _mixer_ready = False
            print("[WRB] audio: mixer closed (idle)", flush=True)
    except:
        pass

def play_sound(sound_name):
    """Play a sound file"""
    global _last_play
    
    if not _mixer_ready or sound_name not in sound_files or not sound_files[sound_name]:
        print(f"[WRB] {sound_name} (no file)", flush=True)
        return
    
    try:
        import pygame
        s = pygame.mixer.Sound(sound_files[sound_name][0])
        pygame.mixer.Channel(0).play(s)
        _last_play = time.time()
        print(f"[WRB] playing {sound_name}", flush=True)
    except Exception as e:
        print(f"[WRB] play error: {e}", flush=True)

# Serial communication
def wait_serial():
    """Wait for serial connection"""
    print("[WRB] waiting for serial…", flush=True)
    prefs = [SERIAL, "/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyUSB0", "/dev/ttyUSB1"]
    
    while True:
        for p in prefs:
            try:
                return serial.Serial(p, BAUD, timeout=0.1)
            except:
                pass
        time.sleep(0.3)

def classify_message(line):
    """Classify incoming message"""
    line = line.strip().upper()
    if "BTN1" in line or "BUTTON1" in line:
        return "button1"
    elif "BTN2" in line or "BUTTON2" in line:
        return "button2"
    elif "HOLD1" in line:
        return "hold1"
    elif "HOLD2" in line:
        return "hold2"
    return None

def main():
    """Main function"""
    global running, logger
    
    # Setup logging
    logger = setup_logging()
    logger.info("=== WRB Enhanced Audio System Starting ===")
    
    # Setup GPIO
    if not setup_gpio():
        logger.error("GPIO setup failed, continuing without LEDs")
    
    # Find sound files
    source = find_sound_files()
    logger.info(f"Sound source: {source}")
    
    # Wait for serial
    try:
        serial_conn = wait_serial()
        logger.info(f"Serial connected: {serial_conn.port}")
    except Exception as e:
        logger.error(f"Serial connection failed: {e}")
        return 1
    
    # Initialize audio
    ensure_mixer()
    
    logger.info("WRB system ready and running")
    
    last_scan = time.time()
    
    try:
        while running:
            # Hot-swap sound files
            if time.time() - last_scan > RESCAN_SEC:
                new_source = find_sound_files()
                if new_source != source:
                    source = new_source
                    logger.info(f"Sound source updated: {source}")
                last_scan = time.time()
            
            # Read serial
            try:
                line = serial_conn.readline().decode(errors="ignore")
            except Exception:
                time.sleep(0.05)
                continue
            
            if not line:
                shutdown_mixer_if_idle()
                continue
            
            # Process message
            sound_type = classify_message(line)
            if sound_type:
                logger.info(f"Received: {sound_type}")
                play_sound(sound_type)
                flash_ready_led()
            
            shutdown_mixer_if_idle()
            
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        running = False
        logger.info("Shutting down WRB system...")
        cleanup_gpio()
        if serial_conn:
            serial_conn.close()
        if _mixer_ready:
            try:
                import pygame
                pygame.mixer.quit()
            except:
                pass
        logger.info("WRB system shutdown complete")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
'''
    
    # Write the clean script
    try:
        with open(script_path, 'w') as f:
            f.write(clean_script)
        os.chmod(script_path, 0o755)
        print("✅ Created clean WRB script")
    except Exception as e:
        print(f"❌ Error creating clean script: {e}")
        return
    
    print(f"\n=== Clean Script Created ===")
    print("This clean script:")
    print("✅ Uses the reference pattern")
    print("✅ Has simple audio system")
    print("✅ Has GPIO control")
    print("✅ Has USB detection")
    print("✅ Has hot-swap sound files")
    print("✅ Has proper error handling")
    print("✅ Has idle audio shutdown")
    print("\nTest the service: sudo systemctl restart WRB-enhanced.service")

if __name__ == "__main__":
    create_clean_script()
