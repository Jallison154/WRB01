#!/usr/bin/env python3
"""
Test System Integration
Integration test for WRB system components
"""

import sys
import os

def test_audio_system():
    """Test audio system"""
    print("Testing audio system...")
    try:
        import pygame
        pygame.mixer.init()
        print("✓ Pygame audio initialized")
        pygame.mixer.quit()
        return True
    except Exception as e:
        print(f"✗ Audio system error: {e}")
        return False

def test_serial_ports():
    """Test serial port availability"""
    print("Testing serial ports...")
    import glob
    ports = glob.glob('/dev/ttyACM*') + glob.glob('/dev/ttyUSB*')
    if ports:
        print(f"✓ Found {len(ports)} serial port(s): {', '.join(ports)}")
        return True
    else:
        print("⚠ No serial ports found")
        return False

def test_gpio():
    """Test GPIO access"""
    print("Testing GPIO...")
    try:
        from gpiozero import LED
        print("✓ GPIO library available")
        return True
    except Exception as e:
        print(f"✗ GPIO error: {e}")
        return False

def test_audio_files():
    """Test audio files"""
    print("Testing audio files...")
    audio_dirs = [
        '/home/wrb01/WRB/sounds',
        '/home/wrb01/audio',
        '/home/wrb01/WRB/audio'
    ]
    
    found_files = False
    for audio_dir in audio_dirs:
        if os.path.isdir(audio_dir):
            files = [f for f in os.listdir(audio_dir) if f.endswith('.wav')]
            if files:
                print(f"✓ Found {len(files)} audio file(s) in {audio_dir}")
                found_files = True
    
    if not found_files:
        print("⚠ No audio files found")
    
    return found_files

def main():
    """Run all integration tests"""
    print("=== WRB System Integration Test ===\n")
    
    results = []
    results.append(("Audio System", test_audio_system()))
    results.append(("Serial Ports", test_serial_ports()))
    results.append(("GPIO", test_gpio()))
    results.append(("Audio Files", test_audio_files()))
    
    print("\n=== Test Summary ===")
    for name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"{name}: {status}")
    
    all_passed = all(result for _, result in results)
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
