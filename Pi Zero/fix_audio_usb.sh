#!/bin/bash
# Fix for USB audio as default output

echo "=== Configuring USB Audio as Default ==="

# Stop the service
echo "Stopping service..."
sudo systemctl stop wrb-simple.service

# Check available audio devices
echo "Available audio devices:"
aplay -l

# Update ALSA configuration to use USB audio as default
echo "Configuring USB audio as default..."
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

# Update the Python script to prefer USB audio
echo "Updating Python script for USB audio..."
sudo tee /home/wrb01/simple_audio_player.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""
Simple Audio Player for ESP32 Button System
Reads serial commands and plays corresponding audio files
"""

import serial
import pygame
import time
import os

# Audio file paths
AUDIO_DIR = "/home/wrb01/audio"
BUTTON1_FILE = os.path.join(AUDIO_DIR, "button1.wav")
BUTTON2_FILE = os.path.join(AUDIO_DIR, "button2.wav")
HOLD1_FILE = os.path.join(AUDIO_DIR, "hold1.wav")
HOLD2_FILE = os.path.join(AUDIO_DIR, "hold2.wav")

def setup_audio():
    """Initialize pygame audio system for USB audio interface"""
    # Set environment variables for USB audio
    os.environ['SDL_AUDIODRIVER'] = 'alsa'
    os.environ['AUDIODEV'] = 'plughw:1,0'  # USB audio device (card 1, device 0)
    
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
    print("Audio system initialized for USB audio interface")

def play_audio(file_path):
    """Play audio file"""
    try:
        if os.path.exists(file_path):
            pygame.mixer.music.load(file_path)
            pygame.mixer.music.play()
            print(f"Playing: {file_path}")
        else:
            print(f"Audio file not found: {file_path}")
    except Exception as e:
        print(f"Error playing audio: {e}")

def test_usb_audio():
    """Test USB audio interface"""
    print("Testing USB audio interface...")
    try:
        # Test with a simple beep
        import numpy as np
        sample_rate = 44100
        duration = 0.5
        frequency = 440  # A note
        
        # Generate a simple tone
        t = np.linspace(0, duration, int(sample_rate * duration), False)
        wave = np.sin(frequency * 2 * np.pi * t)
        wave = (wave * 32767).astype(np.int16)
        
        # Convert to stereo
        stereo_wave = np.array([wave, wave]).T
        
        # Play the tone
        pygame.sndarray.make_sound(stereo_wave).play()
        pygame.time.wait(int(duration * 1000))
        
        print("✓ USB audio test passed")
        return True
    except Exception as e:
        print(f"⚠ USB audio test failed: {e}")
        return False

def main():
    print("Simple Audio Player Starting...")
    print("Configured for USB audio interface")
    
    # Setup audio
    setup_audio()
    
    # Test USB audio
    test_usb_audio()
    
    # Test audio files
    print("Testing audio files...")
    if os.path.exists(BUTTON1_FILE):
        print(f"✓ {BUTTON1_FILE} exists")
    else:
        print(f"✗ {BUTTON1_FILE} not found")
    
    if os.path.exists(BUTTON2_FILE):
        print(f"✓ {BUTTON2_FILE} exists")
    else:
        print(f"✗ {BUTTON2_FILE} not found")
    
    # Setup serial connection
    try:
        ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)
        print("Serial connection established")
    except Exception as e:
        print(f"Serial connection failed: {e}")
        return
    
    # Create audio directory if it doesn't exist
    os.makedirs(AUDIO_DIR, exist_ok=True)
    
    print("Waiting for button presses...")
    
    while True:
        try:
            # Read serial data
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8').strip()
                print(f"Received: '{line}' (length: {len(line)})")
                
                # Handle button commands (from ESP32 receiver)
                if line.startswith("BTN"):
                    button_num = line[3:]  # Extract number after "BTN"
                    if button_num == "1":
                        play_audio(BUTTON1_FILE)
                    elif button_num == "2":
                        play_audio(BUTTON2_FILE)
                elif line.startswith("HOLD"):
                    button_num = line[4:]  # Extract number after "HOLD"
                    if button_num == "1":
                        play_audio(HOLD1_FILE)  # Separate audio for hold
                    elif button_num == "2":
                        play_audio(HOLD2_FILE)  # Separate audio for hold
            
            time.sleep(0.01)  # Small delay
            
        except KeyboardInterrupt:
            print("Stopping...")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()
EOF

# Set proper ownership
sudo chown wrb01:wrb01 /home/wrb01/simple_audio_player.py
sudo chmod +x /home/wrb01/simple_audio_player.py

# Restart the service
echo "Restarting service..."
sudo systemctl start wrb-simple.service

echo "✓ USB audio configured as default!"
echo "Check service status: sudo systemctl status wrb-simple.service"
echo "Check service logs: sudo journalctl -u wrb-simple.service -f"
