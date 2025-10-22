#!/usr/bin/env python3
"""
WRB Button Trigger Troubleshooting Script
Comprehensive diagnostic tool for button trigger issues
"""

import os
import sys
import time
import serial
import subprocess
import glob
from datetime import datetime

def print_header(title):
    """Print a formatted header"""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def print_section(title):
    """Print a formatted section header"""
    print(f"\n🔍 {title}")
    print("-" * 40)

def check_system_services():
    """Check if all WRB services are running"""
    print_section("System Services Status")
    
    services = [
        "WRB-enhanced.service",
        "WRB-health-check.service", 
        "WRB-watchdog.service",
        "WRB-auto-start.service"
    ]
    
    for service in services:
        try:
            result = subprocess.run(['systemctl', 'is-active', service], 
                                  capture_output=True, text=True, timeout=5)
            status = "🟢 RUNNING" if result.stdout.strip() == 'active' else "🔴 STOPPED"
            print(f"  {service:<25} {status}")
        except Exception as e:
            print(f"  {service:<25} ❌ ERROR: {e}")

def check_serial_ports():
    """Check for available serial ports"""
    print_section("Serial Port Detection")
    
    # Common ESP32 serial ports
    common_ports = [
        "/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyACM2",
        "/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyUSB2",
        "/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"
    ]
    
    found_ports = []
    for port in common_ports:
        if os.path.exists(port):
            found_ports.append(port)
            print(f"  ✅ {port}")
        else:
            print(f"  ❌ {port}")
    
    if not found_ports:
        print("  ⚠️  No serial ports found!")
        print("  💡 Check ESP32 connection and drivers")
        return None
    
    return found_ports

def test_serial_communication(port, baud=115200):
    """Test serial communication with ESP32"""
    print_section(f"Testing Serial Communication ({port})")
    
    try:
        ser = serial.Serial(port, baud, timeout=1)
        print(f"  ✅ Serial port {port} opened successfully")
        
        # Try to read some data
        print("  📡 Listening for ESP32 data (10 seconds)...")
        start_time = time.time()
        data_received = []
        
        while time.time() - start_time < 10:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    data_received.append(line)
                    print(f"    📨 Received: {line}")
            except Exception as e:
                print(f"    ❌ Read error: {e}")
                break
        
        ser.close()
        
        if data_received:
            print(f"  ✅ Received {len(data_received)} messages from ESP32")
            return True
        else:
            print("  ⚠️  No data received from ESP32")
            print("  💡 Check ESP32 power and button presses")
            return False
            
    except Exception as e:
        print(f"  ❌ Serial communication failed: {e}")
        return False

def check_button_messages():
    """Check for button trigger messages in logs"""
    print_section("Button Trigger Messages")
    
    # Check systemd logs
    try:
        result = subprocess.run(['journalctl', '-u', 'WRB-enhanced.service', '-n', '50', '--no-pager'], 
                              capture_output=True, text=True, timeout=10)
        logs = result.stdout
        
        button_messages = []
        for line in logs.split('\n'):
            if any(keyword in line.upper() for keyword in ['BTN1', 'BTN2', 'BUTTON1', 'BUTTON2', 'HOLD1', 'HOLD2']):
                button_messages.append(line.strip())
        
        if button_messages:
            print("  📨 Recent button messages found:")
            for msg in button_messages[-10:]:  # Show last 10
                print(f"    {msg}")
        else:
            print("  ⚠️  No button messages found in logs")
            print("  💡 ESP32 may not be sending button data")
            
    except Exception as e:
        print(f"  ❌ Error reading logs: {e}")

def check_audio_system():
    """Check audio system configuration"""
    print_section("Audio System Check")
    
    # Check if pygame is available
    try:
        import pygame
        print("  ✅ Pygame is available")
        
        # Test pygame mixer
        pygame.mixer.init()
        print("  ✅ Pygame mixer initialized")
        pygame.mixer.quit()
        
    except Exception as e:
        print(f"  ❌ Pygame error: {e}")
        return False
    
    # Check sound files
    sound_dirs = ["/home/pi/WRB/sounds", "/media"]
    sound_files = {'button1': [], 'button2': [], 'hold1': [], 'hold2': []}
    
    for base_dir in sound_dirs:
        if os.path.exists(base_dir):
            if base_dir == "/home/pi/WRB/sounds":
                for sound_type in sound_files.keys():
                    pattern = f"{base_dir}/{sound_type}*.wav"
                    files = glob.glob(pattern)
                    sound_files[sound_type].extend(files)
            else:
                # Check USB drives
                for item in os.listdir(base_dir):
                    usb_path = os.path.join(base_dir, item)
                    if os.path.ismount(usb_path):
                        for sound_type in sound_files.keys():
                            pattern = f"{usb_path}/{sound_type}*.wav"
                            files = glob.glob(pattern)
                            sound_files[sound_type].extend(files)
    
    print("  🎵 Sound files found:")
    for sound_type, files in sound_files.items():
        count = len(files)
        status = "✅" if count > 0 else "❌"
        print(f"    {sound_type}: {count} files {status}")
        if files:
            for file in files[:3]:  # Show first 3 files
                print(f"      - {os.path.basename(file)}")
    
    return any(sound_files.values())

def check_esp32_connection():
    """Test ESP32 connection and button triggers"""
    print_section("ESP32 Connection Test")
    
    ports = check_serial_ports()
    if not ports:
        return False
    
    # Test each port
    for port in ports:
        print(f"\n  🔌 Testing {port}...")
        if test_serial_communication(port):
            print(f"  ✅ {port} is working - ESP32 is connected!")
            return True
    
    print("  ❌ No working ESP32 connection found")
    return False

def check_configuration():
    """Check configuration files"""
    print_section("Configuration Check")
    
    config_file = "/home/pi/WRB/config.py"
    if os.path.exists(config_file):
        print("  ✅ config.py found")
        try:
            with open(config_file, 'r') as f:
                content = f.read()
                
            # Check for important settings
            if "BAUD = 115200" in content:
                print("  ✅ Baud rate: 115200")
            if "SERIAL = " in content:
                print("  ✅ Serial port configured")
            if "READY_PIN = 23" in content:
                print("  ✅ Ready pin: 23")
            if "USB_LED_PIN = 24" in content:
                print("  ✅ USB LED pin: 24")
                
        except Exception as e:
            print(f"  ❌ Error reading config: {e}")
    else:
        print("  ❌ config.py not found")
        print("  💡 Run the install script to create configuration")

def run_live_test():
    """Run a live test of the button system"""
    print_section("Live Button Test")
    print("  🎯 Press buttons on your ESP32 transmitter now...")
    print("  ⏱️  Test will run for 30 seconds")
    print("  📡 Listening for button messages...")
    
    ports = check_serial_ports()
    if not ports:
        print("  ❌ No serial ports available for testing")
        return
    
    # Test the first available port
    port = ports[0]
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        start_time = time.time()
        button_presses = []
        
        while time.time() - start_time < 30:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"    📨 {line}")
                    if any(keyword in line.upper() for keyword in ['BTN1', 'BTN2', 'BUTTON1', 'BUTTON2']):
                        button_presses.append(line)
            except Exception as e:
                print(f"    ❌ Read error: {e}")
                break
        
        ser.close()
        
        if button_presses:
            print(f"  ✅ Detected {len(button_presses)} button presses!")
            for press in button_presses:
                print(f"    🎯 {press}")
        else:
            print("  ⚠️  No button presses detected")
            print("  💡 Check ESP32 power, button connections, and transmitter range")
            
    except Exception as e:
        print(f"  ❌ Live test failed: {e}")

def main():
    """Main troubleshooting function"""
    print_header("WRB Button Trigger Troubleshooting")
    print("This script will help diagnose button trigger issues")
    
    # Run all diagnostic checks
    check_system_services()
    check_configuration()
    check_audio_system()
    check_button_messages()
    check_esp32_connection()
    
    # Ask if user wants to run live test
    print_section("Live Button Test")
    response = input("  🎯 Run live button test? (y/n): ").lower().strip()
    if response in ['y', 'yes']:
        run_live_test()
    
    # Provide troubleshooting recommendations
    print_section("Troubleshooting Recommendations")
    print("  🔧 If buttons aren't working, try:")
    print("    1. Check ESP32 power and connections")
    print("    2. Verify transmitter and receiver are paired")
    print("    3. Check button wiring on ESP32")
    print("    4. Restart services: sudo systemctl restart WRB-enhanced")
    print("    5. Check logs: sudo journalctl -u WRB-enhanced.service -f")
    print("    6. Verify sound files are in ~/WRB/sounds/")
    print("    7. Test ESP32 directly with serial monitor")
    
    print("\n📋 Useful Commands:")
    print("  Check service: sudo systemctl status WRB-enhanced.service")
    print("  View logs: sudo journalctl -u WRB-enhanced.service -f")
    print("  Restart: sudo systemctl restart WRB-enhanced.service")
    print("  Monitor: python3 /home/pi/WRB/monitor_system.py")

if __name__ == "__main__":
    main()
