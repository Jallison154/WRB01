#!/usr/bin/env python3
"""
Fast startup test for WRB system
Measures startup time and identifies bottlenecks
"""
import time
import sys
import os
import subprocess

def measure_startup_time():
    """Measure and report startup time"""
    start_time = time.time()
    
    print("=== WRB Fast Startup Test ===")
    print(f"Start time: {time.strftime('%H:%M:%S')}")
    
    # Test 1: Service status
    print("\n1. Checking service status...")
    try:
        result = subprocess.run(['systemctl', 'is-active', 'WRB-enhanced.service'], 
                              capture_output=True, text=True)
        if result.stdout.strip() == 'active':
            print("   ✅ Service is running")
        else:
            print("   ❌ Service not running")
    except Exception as e:
        print(f"   ❌ Error checking service: {e}")
    
    # Test 2: GPIO access
    print("\n2. Testing GPIO access...")
    try:
        import RPi.GPIO as GPIO
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(23, GPIO.OUT)
        GPIO.output(23, GPIO.HIGH)
        GPIO.cleanup()
        print("   ✅ GPIO access working")
    except Exception as e:
        print(f"   ❌ GPIO error: {e}")
    
    # Test 3: Audio system
    print("\n3. Testing audio system...")
    try:
        import pygame
        pygame.mixer.init(frequency=22050, size=-16, channels=2, buffer=512)
        pygame.mixer.quit()
        print("   ✅ Audio system working")
    except Exception as e:
        print(f"   ❌ Audio error: {e}")
    
    # Test 4: Serial port
    print("\n4. Testing serial port...")
    try:
        import serial
        # Just test import, don't actually open port
        print("   ✅ Serial library available")
    except Exception as e:
        print(f"   ❌ Serial error: {e}")
    
    # Test 5: File system
    print("\n5. Testing file system...")
    try:
        if os.path.exists('/home/pi/WRB'):
            print("   ✅ WRB directory exists")
        else:
            print("   ❌ WRB directory missing")
        
        if os.path.exists('/home/pi/WRB/PiScript'):
            print("   ✅ PiScript exists")
        else:
            print("   ❌ PiScript missing")
    except Exception as e:
        print(f"   ❌ File system error: {e}")
    
    end_time = time.time()
    total_time = end_time - start_time
    
    print(f"\n=== Startup Test Complete ===")
    print(f"Total test time: {total_time:.2f} seconds")
    print(f"End time: {time.strftime('%H:%M:%S')}")
    
    return total_time

def test_service_startup():
    """Test actual service startup time"""
    print("\n=== Service Startup Test ===")
    
    # Stop service first
    print("Stopping service...")
    subprocess.run(['sudo', 'systemctl', 'stop', 'WRB-enhanced.service'])
    time.sleep(2)
    
    # Start service and measure time
    print("Starting service...")
    start_time = time.time()
    subprocess.run(['sudo', 'systemctl', 'start', 'WRB-enhanced.service'])
    
    # Wait for service to be active
    max_wait = 30  # 30 second timeout
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
    
    print("❌ Service failed to start within 30 seconds")
    return None

if __name__ == "__main__":
    print("WRB Fast Startup Analysis")
    print("=" * 40)
    
    # Run component tests
    test_time = measure_startup_time()
    
    # Test service startup
    service_time = test_service_startup()
    
    print(f"\n=== Summary ===")
    print(f"Component test time: {test_time:.2f}s")
    if service_time:
        print(f"Service startup time: {service_time:.2f}s")
        print(f"Total startup time: {test_time + service_time:.2f}s")
    else:
        print("Service startup: FAILED")
    
    # Recommendations
    print(f"\n=== Recommendations ===")
    if service_time and service_time < 10:
        print("✅ Startup is fast (< 10 seconds)")
    elif service_time and service_time < 20:
        print("⚠️  Startup is moderate (10-20 seconds)")
    else:
        print("❌ Startup is slow (> 20 seconds)")
        print("   - Check service dependencies")
        print("   - Verify GPIO permissions")
        print("   - Test audio system")
