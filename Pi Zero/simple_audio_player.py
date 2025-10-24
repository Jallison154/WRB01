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
                print(f"Received: {line}")
                
                # Handle button commands (from ESP32 receiver)
                if line == "BTN1":
                    play_audio(BUTTON1_FILE)
                elif line == "BTN2":
                    play_audio(BUTTON2_FILE)
                elif line == "HOLD1":
                    play_audio(HOLD1_FILE)  # Separate audio for hold
                elif line == "HOLD2":
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
