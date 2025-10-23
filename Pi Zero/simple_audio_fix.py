#!/usr/bin/env python3
"""
Simple Audio Fix
Add audio to the script without testing
"""
import os

def simple_audio_fix():
    """Add audio functionality without testing"""
    print("=== Simple Audio Fix ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    script_path = f"{script_dir}/PiScript"
    
    # Create a version with simple audio
    new_script = '''#!/usr/bin/env python3
"""
WRB Enhanced Audio System - With Simple Audio
"""
import serial
import time
import threading
import logging
import os
import sys
from pathlib import Path

# Configuration
SERIAL_PORT = "/dev/ttyACM0"
BAUD_RATE = 115200
READY_PIN = 23
USB_LED_PIN = 24

# Global variables
running = True
serial_conn = None

# Try to import GPIO, fallback if not available
try:
    import RPi.GPIO as GPIO
    GPIO_AVAILABLE = True
except ImportError:
    print("Warning: RPi.GPIO not available, GPIO features disabled")
    GPIO_AVAILABLE = False
    GPIO = None

# Try to import pygame for audio, fallback if not available
try:
    import pygame
    pygame.mixer.init(frequency=22050, size=-16, channels=2, buffer=512)
    AUDIO_AVAILABLE = True
    print("Audio system initialized successfully")
except Exception as e:
    print(f"Warning: Audio system not available: {e}")
    AUDIO_AVAILABLE = False
    pygame = None

# Setup logging
def setup_logging():
    """Setup logging"""
    # Create logs directory
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

def setup_gpio():
    """Initialize GPIO pins"""
    if not GPIO_AVAILABLE:
        logger.warning("GPIO not available, LED control disabled")
        return True
        
    try:
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(READY_PIN, GPIO.OUT)
        GPIO.setup(USB_LED_PIN, GPIO.OUT)
        
        # Turn on ready LED
        GPIO.output(READY_PIN, GPIO.HIGH)
        GPIO.output(USB_LED_PIN, GPIO.LOW)
        
        logger.info("GPIO initialized successfully")
        logger.info(f"Ready LED (GPIO {READY_PIN}) is ON")
        logger.info(f"USB LED (GPIO {USB_LED_PIN}) is OFF")
        return True
        
    except Exception as e:
        logger.error(f"GPIO setup failed: {e}")
        return False

def cleanup_gpio():
    """Clean up GPIO pins"""
    if not GPIO_AVAILABLE:
        return
        
    try:
        GPIO.cleanup()
        logger.info("GPIO cleaned up")
    except Exception as e:
        logger.error(f"GPIO cleanup failed: {e}")

def setup_serial():
    """Setup serial connection"""
    global serial_conn
    
    try:
        serial_conn = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        logger.info(f"Serial connection established on {SERIAL_PORT}")
        return True
    except Exception as e:
        logger.error(f"Serial setup failed: {e}")
        return False

def play_sound(sound_name):
    """Play a sound file"""
    if not AUDIO_AVAILABLE:
        logger.warning("Audio not available, cannot play sound")
        return
    
    try:
        # Look for sound files in different locations
        sound_paths = [
            f"sounds/{sound_name}.wav",
            f"default_sounds/{sound_name}.wav",
            f"~/WRB/sounds/{sound_name}.wav",
            f"~/WRB/default_sounds/{sound_name}.wav"
        ]
        
        sound_file = None
        for path in sound_paths:
            expanded_path = os.path.expanduser(path)
            if os.path.exists(expanded_path):
                sound_file = expanded_path
                break
        
        if sound_file:
            pygame.mixer.music.load(sound_file)
            pygame.mixer.music.play()
            logger.info(f"Playing sound: {sound_file}")
        else:
            logger.warning(f"Sound file not found: {sound_name}")
            
    except Exception as e:
        logger.error(f"Error playing sound: {e}")

def process_serial_message(message):
    """Process incoming serial messages"""
    message = message.strip()
    
    if not message:
        return
    
    logger.info(f"Received: {message}")
    
    # Handle different message types
    if message == "BTN1":
        logger.info("Button 1 pressed")
        play_sound("button1")
        # Flash ready LED
        if GPIO_AVAILABLE:
            GPIO.output(READY_PIN, GPIO.LOW)
            time.sleep(0.1)
            GPIO.output(READY_PIN, GPIO.HIGH)
    
    elif message == "BTN2":
        logger.info("Button 2 pressed")
        play_sound("button2")
        # Flash ready LED
        if GPIO_AVAILABLE:
            GPIO.output(READY_PIN, GPIO.LOW)
            time.sleep(0.1)
            GPIO.output(READY_PIN, GPIO.HIGH)
    
    elif message == "HOLD1":
        logger.info("Button 1 held")
        play_sound("hold1")
        # Double flash ready LED
        if GPIO_AVAILABLE:
            for _ in range(2):
                GPIO.output(READY_PIN, GPIO.LOW)
                time.sleep(0.1)
                GPIO.output(READY_PIN, GPIO.HIGH)
                time.sleep(0.1)
    
    elif message == "HOLD2":
        logger.info("Button 2 held")
        play_sound("hold2")
        # Double flash ready LED
        if GPIO_AVAILABLE:
            for _ in range(2):
                GPIO.output(READY_PIN, GPIO.LOW)
                time.sleep(0.1)
                GPIO.output(READY_PIN, GPIO.HIGH)
                time.sleep(0.1)

def serial_monitor():
    """Monitor serial connection"""
    global running
    
    while running:
        try:
            if serial_conn and serial_conn.in_waiting:
                message = serial_conn.readline().decode('utf-8', errors='ignore')
                process_serial_message(message)
            time.sleep(0.1)
        except Exception as e:
            logger.error(f"Serial monitor error: {e}")
            time.sleep(1)

def main():
    """Main function"""
    global running, logger
    
    # Setup logging
    logger = setup_logging()
    logger.info("=== WRB Enhanced Audio System Starting ===")
    
    # Setup GPIO
    if not setup_gpio():
        logger.error("GPIO setup failed, continuing without LEDs")
    
    # Setup serial
    if not setup_serial():
        logger.error("Serial setup failed, continuing without serial")
    
    # Check audio status
    if AUDIO_AVAILABLE:
        logger.info("Audio system ready")
    else:
        logger.warning("Audio system not available, continuing without audio")
    
    logger.info("WRB system ready and running")
    
    try:
        # Start serial monitor thread
        serial_thread = threading.Thread(target=serial_monitor, daemon=True)
        serial_thread.start()
        
        # Main loop
        while running:
            time.sleep(1)
            
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        # Cleanup
        running = False
        logger.info("Shutting down WRB system...")
        cleanup_gpio()
        if serial_conn:
            serial_conn.close()
        if AUDIO_AVAILABLE:
            pygame.mixer.quit()
        logger.info("WRB system shutdown complete")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
'''
    
    # Write the new script with audio
    try:
        with open(script_path, 'w') as f:
            f.write(new_script)
        os.chmod(script_path, 0o755)
        print("✅ Updated script with audio functionality")
    except Exception as e:
        print(f"❌ Error updating script: {e}")
        return
    
    print(f"\n=== Audio Added ===")
    print("This updated script now has:")
    print("✅ Simple audio system (won't crash)")
    print("✅ GPIO handling with fallbacks")
    print("✅ Serial monitoring")
    print("✅ Sound file playback")
    print("✅ Proper error handling")
    print("✅ Audio cleanup")
    print("\nTest the service: sudo systemctl restart WRB-enhanced.service")

if __name__ == "__main__":
    simple_audio_fix()
