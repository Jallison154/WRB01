#!/usr/bin/env python3
"""
Test ESP32 Connection
Simple test script to verify ESP32 serial communication
"""

import serial
import sys
import time

def test_esp32_connection():
    """Test serial connection to ESP32"""
    print("Testing ESP32 connection...")
    
    # Try common serial ports
    ports = ['/dev/ttyACM0', '/dev/ttyACM1', '/dev/ttyUSB0', '/dev/ttyUSB1']
    
    for port in ports:
        try:
            ser = serial.Serial(port, 115200, timeout=1)
            print(f"✓ Connected to {port}")
            print("Waiting for data (press Ctrl+C to stop)...")
            
            try:
                while True:
                    if ser.in_waiting > 0:
                        line = ser.readline().decode('utf-8', errors='ignore').strip()
                        if line:
                            print(f"Received: {line}")
                    time.sleep(0.1)
            except KeyboardInterrupt:
                print("\nTest stopped by user")
            
            ser.close()
            return True
        except (serial.SerialException, FileNotFoundError):
            continue
    
    print("✗ No ESP32 found on any serial port")
    print("Available ports:")
    import glob
    for port in glob.glob('/dev/tty[A-Z]*'):
        print(f"  - {port}")
    return False

if __name__ == "__main__":
    test_esp32_connection()
