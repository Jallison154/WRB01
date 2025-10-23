#!/usr/bin/env python3
"""
WRB System Tester
Comprehensive testing tool for the WRB system
"""

import pygame
import serial
import time
import sys
import os
import subprocess
from pathlib import Path
import RPi.GPIO as GPIO
from config import *

class WRBTester:
    def __init__(self):
        self.wrb_home = Path.home() / "WRB"
        self.test_results = {}
        
    def test_audio_system(self):
        """Test audio system functionality"""
        print("Testing Audio System...")
        
        try:
            # Initialize pygame mixer
            pygame.mixer.pre_init(frequency=MIX_FREQ, size=-16, channels=2, buffer=MIX_BUF)
            pygame.mixer.init()
            
            # Create test sound
            import numpy as np
            sample_rate = MIX_FREQ
            duration = 0.5
            frames = int(duration * sample_rate)
            arr = np.zeros((frames, 2))
            
            for i in range(frames):
                arr[i][0] = np.sin(2 * np.pi * 440 * i / sample_rate) * 0.3
                arr[i][1] = arr[i][0]
            
            arr = (arr * 32767).astype(np.int16)
            test_sound = pygame.mixer.Sound(pygame.sndarray.make_sound(arr))
            
            # Test playback
            test_sound.play()
            time.sleep(duration + 0.1)
            
            pygame.mixer.quit()
            
            self.test_results['audio'] = True
            print("✓ Audio system test passed")
            return True
            
        except Exception as e:
            self.test_results['audio'] = False
            print(f"✗ Audio system test failed: {e}")
            return False
    
    def test_gpio_system(self):
        """Test GPIO functionality"""
        print("Testing GPIO System...")
        
        try:
            # Test GPIO pins
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            
            # Test ready pin
            GPIO.setup(READY_PIN, GPIO.OUT)
            GPIO.output(READY_PIN, GPIO.HIGH)
            time.sleep(0.1)
            GPIO.output(READY_PIN, GPIO.LOW)
            
            # Test USB LED pin
            GPIO.setup(USB_LED_PIN, GPIO.OUT)
            GPIO.output(USB_LED_PIN, GPIO.HIGH)
            time.sleep(0.1)
            GPIO.output(USB_LED_PIN, GPIO.LOW)
            
            GPIO.cleanup()
            
            self.test_results['gpio'] = True
            print("✓ GPIO system test passed")
            return True
            
        except Exception as e:
            self.test_results['gpio'] = False
            print(f"✗ GPIO system test failed: {e}")
            return False
    
    def test_serial_communication(self):
        """Test serial communication"""
        print("Testing Serial Communication...")
        
        try:
            # Find serial port
            port = None
            for test_port in [SERIAL_PORT] + ALTERNATIVE_PORTS:
                if os.path.exists(test_port):
                    port = test_port
                    break
            
            if not port:
                self.test_results['serial'] = False
                print("✗ No serial port found")
                return False
            
            # Test serial connection
            ser = serial.Serial(port, BAUD, timeout=1)
            time.sleep(1)
            
            # Send test message
            test_message = "TEST\n"
            ser.write(test_message.encode())
            
            # Wait for response
            time.sleep(0.5)
            if ser.in_waiting > 0:
                response = ser.readline().decode('utf-8', errors='ignore')
                print(f"Received response: {response.strip()}")
            
            ser.close()
            
            self.test_results['serial'] = True
            print("✓ Serial communication test passed")
            return True
            
        except Exception as e:
            self.test_results['serial'] = False
            print(f"✗ Serial communication test failed: {e}")
            return False
    
    def test_sound_files(self):
        """Test sound file loading and playback"""
        print("Testing Sound Files...")
        
        try:
            # Initialize audio
            pygame.mixer.pre_init(frequency=MIX_FREQ, size=-16, channels=2, buffer=MIX_BUF)
            pygame.mixer.init()
            
            # Find sound files
            sound_dirs = [
                self.wrb_home / "sounds",
                self.wrb_home / "default_sounds"
            ]
            
            sounds_found = 0
            for sound_dir in sound_dirs:
                if sound_dir.exists():
                    for wav_file in sound_dir.glob("*.wav"):
                        try:
                            sound = pygame.mixer.Sound(str(wav_file))
                            sounds_found += 1
                            print(f"✓ Loaded sound: {wav_file.name}")
                        except Exception as e:
                            print(f"✗ Failed to load {wav_file.name}: {e}")
            
            pygame.mixer.quit()
            
            if sounds_found > 0:
                self.test_results['sound_files'] = True
                print(f"✓ Sound files test passed ({sounds_found} files loaded)")
                return True
            else:
                self.test_results['sound_files'] = False
                print("✗ No sound files found")
                return False
                
        except Exception as e:
            self.test_results['sound_files'] = False
            print(f"✗ Sound files test failed: {e}")
            return False
    
    def test_service_status(self):
        """Test systemd service status"""
        print("Testing Service Status...")
        
        try:
            result = subprocess.run(
                ["systemctl", "is-active", "WRB-enhanced.service"],
                capture_output=True,
                text=True
            )
            
            if result.stdout.strip() == "active":
                self.test_results['service'] = True
                print("✓ Service is running")
                return True
            else:
                self.test_results['service'] = False
                print("✗ Service is not running")
                return False
                
        except Exception as e:
            self.test_results['service'] = False
            print(f"✗ Service test failed: {e}")
            return False
    
    def test_usb_detection(self):
        """Test USB drive detection"""
        print("Testing USB Detection...")
        
        try:
            # Check for USB devices
            result = subprocess.run(
                ["lsblk", "-J"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                import json
                data = json.loads(result.stdout)
                usb_devices = [d for d in data.get("blockdevices", []) if d.get("tran") == "usb"]
                
                if usb_devices:
                    self.test_results['usb'] = True
                    print(f"✓ USB detection test passed ({len(usb_devices)} devices found)")
                    return True
                else:
                    self.test_results['usb'] = False
                    print("✗ No USB devices found")
                    return False
            else:
                self.test_results['usb'] = False
                print("✗ USB detection test failed")
                return False
                
        except Exception as e:
            self.test_results['usb'] = False
            print(f"✗ USB detection test failed: {e}")
            return False
    
    def run_all_tests(self):
        """Run all system tests"""
        print("WRB System Test Suite")
        print("=" * 50)
        print()
        
        tests = [
            ("Audio System", self.test_audio_system),
            ("GPIO System", self.test_gpio_system),
            ("Serial Communication", self.test_serial_communication),
            ("Sound Files", self.test_sound_files),
            ("Service Status", self.test_service_status),
            ("USB Detection", self.test_usb_detection)
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            print(f"Running {test_name} test...")
            if test_func():
                passed += 1
            print()
        
        # Print summary
        print("Test Summary")
        print("-" * 20)
        print(f"Passed: {passed}/{total}")
        print(f"Failed: {total - passed}/{total}")
        
        if passed == total:
            print("✓ All tests passed!")
            return True
        else:
            print("✗ Some tests failed")
            return False

def main():
    """Main function"""
    tester = WRBTester()
    
    if len(sys.argv) > 1:
        test_type = sys.argv[1]
        
        if test_type == "audio":
            tester.test_audio_system()
        elif test_type == "gpio":
            tester.test_gpio_system()
        elif test_type == "serial":
            tester.test_serial_communication()
        elif test_type == "sounds":
            tester.test_sound_files()
        elif test_type == "service":
            tester.test_service_status()
        elif test_type == "usb":
            tester.test_usb_detection()
        else:
            print("Unknown test type. Available: audio, gpio, serial, sounds, service, usb")
    else:
        # Run all tests
        success = tester.run_all_tests()
        sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
