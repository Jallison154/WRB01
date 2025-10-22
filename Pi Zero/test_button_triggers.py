#!/usr/bin/env python3
"""
Simple Button Trigger Test
Tests if button messages are being received from ESP32
"""

import serial
import time
import sys

def test_serial_connection(port="/dev/ttyACM0", baud=115200):
    """Test serial connection and look for button messages"""
    print(f"🔌 Testing serial connection on {port} at {baud} baud...")
    
    try:
        ser = serial.Serial(port, baud, timeout=1)
        print(f"✅ Serial port {port} opened successfully")
        
        print("📡 Listening for button messages (30 seconds)...")
        print("🎯 Press buttons on your ESP32 transmitter now!")
        print("")
        
        start_time = time.time()
        button_messages = []
        
        while time.time() - start_time < 30:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"📨 Received: {line}")
                    
                    # Check if it's a button message
                    if "BTN1" in line.upper() or "BTN2" in line.upper():
                        button_messages.append(line)
                        print(f"🎯 BUTTON TRIGGER DETECTED: {line}")
                        
            except Exception as e:
                print(f"❌ Read error: {e}")
                break
        
        ser.close()
        
        print(f"\n📊 Results:")
        print(f"  Total messages received: {len(button_messages)}")
        if button_messages:
            print(f"  Button messages: {button_messages}")
            print(f"✅ Button triggers are working!")
            return True
        else:
            print(f"❌ No button messages received")
            print(f"💡 Check ESP32 power, connection, and button presses")
            return False
            
    except Exception as e:
        print(f"❌ Serial connection failed: {e}")
        print(f"💡 Check if ESP32 is connected and powered on")
        return False

def find_serial_ports():
    """Find available serial ports"""
    import glob
    import os
    
    print("🔍 Searching for serial ports...")
    
    # Common ESP32 ports
    port_patterns = [
        "/dev/ttyACM*",
        "/dev/ttyUSB*", 
        "/dev/serial*",
        "/dev/ttyAMA*",
        "/dev/ttyS*"
    ]
    
    found_ports = []
    for pattern in port_patterns:
        ports = glob.glob(pattern)
        for port in ports:
            if os.path.exists(port):
                found_ports.append(port)
                print(f"  ✅ {port}")
    
    if not found_ports:
        print("  ❌ No serial ports found")
        print("  💡 Check ESP32 connection and drivers")
    
    return found_ports

def main():
    """Main test function"""
    print("=" * 60)
    print("  WRB Button Trigger Test")
    print("=" * 60)
    print("")
    
    # Find serial ports
    ports = find_serial_ports()
    if not ports:
        print("❌ No serial ports available for testing")
        return
    
    # Test each port
    for port in ports:
        print(f"\n🔌 Testing {port}...")
        if test_serial_connection(port):
            print(f"✅ {port} is working - button triggers detected!")
            break
    else:
        print("❌ No working button triggers found on any port")
        print("")
        print("🔧 Troubleshooting steps:")
        print("  1. Check ESP32 power and USB connection")
        print("  2. Verify transmitter and receiver are paired")
        print("  3. Check button wiring on ESP32")
        print("  4. Try pressing buttons while watching this test")
        print("  5. Check ESP32 serial monitor for debug messages")

if __name__ == "__main__":
    main()
