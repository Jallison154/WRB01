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
