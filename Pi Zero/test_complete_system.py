#!/usr/bin/env python3
"""
Complete WRB System Test
Tests all components after updates
"""
import time
import sys
import os
import subprocess
import threading

def test_system_components():
    """Test all system components"""
    print("=== WRB Complete System Test ===")
    print(f"Test started: {time.strftime('%H:%M:%S')}")
    
    results = {}
    
    # Test 1: File Structure
    print("\n1. Testing file structure...")
    # Get current user's home directory
    home_dir = os.path.expanduser("~")
    required_files = [
        f"{home_dir}/WRB01/Pi Zero/PiScript",
        f"{home_dir}/WRB01/Pi Zero/config.py",
        f"{home_dir}/WRB01/Pi Zero/WRB-enhanced.service",
        f"{home_dir}/WRB01/Pi Zero/test_pwm.py",
        f"{home_dir}/WRB01/Pi Zero/startup_test.py"
    ]
    
    for file_path in required_files:
        if os.path.exists(file_path):
            print(f"   ✅ {file_path}")
        else:
            print(f"   ❌ {file_path} - MISSING")
            results['files'] = False
            break
    else:
        print("   ✅ All required files present")
        results['files'] = True
    
    # Test 2: Directory Structure
    print("\n2. Testing directory structure...")
    required_dirs = [
        f"{home_dir}/WRB01/Pi Zero/logs",
        f"{home_dir}/WRB01/Pi Zero/sounds",
        f"{home_dir}/WRB01/Pi Zero/default_sounds"
    ]
    
    for dir_path in required_dirs:
        if os.path.exists(dir_path):
            print(f"   ✅ {dir_path}")
        else:
            print(f"   ⚠️  {dir_path} - Creating...")
            os.makedirs(dir_path, exist_ok=True)
            print(f"   ✅ {dir_path} - Created")
    
    results['directories'] = True
    
    # Test 3: Service Configuration
    print("\n3. Testing service configuration...")
    try:
        # Check if service file exists in systemd
        result = subprocess.run(['systemctl', 'cat', 'WRB-enhanced.service'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("   ✅ Service file is installed")
            results['service'] = True
        else:
            print("   ❌ Service file not installed")
            print("   Run: sudo cp ~/WRB01/Pi\\ Zero/WRB-enhanced.service /etc/systemd/system/")
            results['service'] = False
    except Exception as e:
        print(f"   ❌ Service check failed: {e}")
        results['service'] = False
    
    # Test 4: GPIO Access
    print("\n4. Testing GPIO access...")
    try:
        import RPi.GPIO as GPIO
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(23, GPIO.OUT)
        GPIO.output(23, GPIO.HIGH)
        time.sleep(0.1)
        GPIO.output(23, GPIO.LOW)
        GPIO.cleanup()
        print("   ✅ GPIO access working")
        results['gpio'] = True
    except Exception as e:
        print(f"   ❌ GPIO error: {e}")
        results['gpio'] = False
    
    # Test 5: Audio System
    print("\n5. Testing audio system...")
    try:
        import pygame
        pygame.mixer.init(frequency=22050, size=-16, channels=2, buffer=512)
        pygame.mixer.quit()
        print("   ✅ Audio system working")
        results['audio'] = True
    except Exception as e:
        print(f"   ❌ Audio error: {e}")
        results['audio'] = False
    
    # Test 6: Python Dependencies
    print("\n6. Testing Python dependencies...")
    dependencies = ['serial', 'pygame', 'numpy', 'RPi.GPIO']
    missing_deps = []
    
    for dep in dependencies:
        try:
            __import__(dep)
            print(f"   ✅ {dep}")
        except ImportError:
            print(f"   ❌ {dep} - MISSING")
            missing_deps.append(dep)
    
    if missing_deps:
        print(f"   Install missing: pip3 install {' '.join(missing_deps)}")
        results['dependencies'] = False
    else:
        results['dependencies'] = True
    
    return results

def test_service_startup():
    """Test service startup time"""
    print("\n=== Service Startup Test ===")
    
    # Stop service first
    print("Stopping service...")
    subprocess.run(['sudo', 'systemctl', 'stop', 'WRB-enhanced.service'], 
                  capture_output=True)
    time.sleep(2)
    
    # Start service and measure time
    print("Starting service...")
    start_time = time.time()
    result = subprocess.run(['sudo', 'systemctl', 'start', 'WRB-enhanced.service'])
    
    if result.returncode != 0:
        print("❌ Failed to start service")
        return None
    
    # Wait for service to be active
    max_wait = 15  # 15 second timeout
    for i in range(max_wait):
        result = subprocess.run(['systemctl', 'is-active', 'WRB-enhanced.service'], 
                              capture_output=True, text=True)
        if result.stdout.strip() == 'active':
            end_time = time.time()
            startup_time = end_time - start_time
            print(f"✅ Service started in {startup_time:.2f} seconds")
            return startup_time
        time.sleep(1)
        print(f"   Waiting... {i+1}/{max_wait}")
    
    print("❌ Service failed to start within 15 seconds")
    return None

def test_led_functionality():
    """Test LED functionality"""
    print("\n=== LED Functionality Test ===")
    
    try:
        import RPi.GPIO as GPIO
        import time
        
        # Test PWM setup
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(23, GPIO.OUT)
        GPIO.setup(24, GPIO.OUT)
        
        # Test PWM
        ready_pwm = GPIO.PWM(23, 1000)
        usb_pwm = GPIO.PWM(24, 1000)
        
        ready_pwm.start(0)
        usb_pwm.start(0)
        
        print("Testing Ready LED (GPIO 23)...")
        ready_pwm.ChangeDutyCycle(25)  # 25% brightness
        time.sleep(1)
        ready_pwm.ChangeDutyCycle(100)  # Flash to 100%
        time.sleep(0.2)
        ready_pwm.ChangeDutyCycle(25)  # Back to 25%
        time.sleep(1)
        
        print("Testing USB LED (GPIO 24)...")
        usb_pwm.ChangeDutyCycle(100)  # 100% brightness
        time.sleep(1)
        usb_pwm.ChangeDutyCycle(0)  # Off
        time.sleep(1)
        
        # Cleanup
        ready_pwm.stop()
        usb_pwm.stop()
        GPIO.cleanup()
        
        print("✅ LED functionality test passed")
        return True
        
    except Exception as e:
        print(f"❌ LED test failed: {e}")
        return False

def main():
    """Main test function"""
    print("WRB Complete System Test")
    print("=" * 50)
    
    # Test system components
    results = test_system_components()
    
    # Test LED functionality
    led_test = test_led_functionality()
    
    # Test service startup
    startup_time = test_service_startup()
    
    # Summary
    print(f"\n=== Test Summary ===")
    print(f"Files: {'✅' if results.get('files', False) else '❌'}")
    print(f"Directories: {'✅' if results.get('directories', False) else '❌'}")
    print(f"Service: {'✅' if results.get('service', False) else '❌'}")
    print(f"GPIO: {'✅' if results.get('gpio', False) else '❌'}")
    print(f"Audio: {'✅' if results.get('audio', False) else '❌'}")
    print(f"Dependencies: {'✅' if results.get('dependencies', False) else '❌'}")
    print(f"LEDs: {'✅' if led_test else '❌'}")
    print(f"Startup: {'✅' if startup_time else '❌'}")
    
    if startup_time:
        print(f"Startup time: {startup_time:.2f} seconds")
    
    # Overall result
    all_passed = all(results.values()) and led_test and startup_time
    print(f"\nOverall: {'✅ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
