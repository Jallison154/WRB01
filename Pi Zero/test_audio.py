#!/usr/bin/env python3
"""
WRB Audio Test Script
Test audio system for Pi Zero W compatibility

This script tests various audio configurations and provides
diagnostic information for troubleshooting audio issues.
"""

import os
import sys
import time
import subprocess
import pygame
import logging
from pathlib import Path

# Add current directory to path for imports
sys.path.append(str(Path(__file__).parent))

try:
    from config import *
except ImportError:
    print("Warning: Could not import config.py, using defaults")
    MIX_FREQ = 44100
    MIX_BUF = 1024

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def test_audio_devices():
    """Test available audio devices"""
    logger.info("=== Testing Audio Devices ===")
    
    # Test ALSA devices
    logger.info("Testing ALSA devices...")
    try:
        result = subprocess.run(['aplay', '-l'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0 and result.stdout.strip():
            logger.info("✓ ALSA devices found:")
            for line in result.stdout.split('\n'):
                if line.strip():
                    logger.info(f"  {line}")
            return True
        else:
            logger.warning("✗ No ALSA devices found")
    except Exception as e:
        logger.error(f"✗ ALSA test failed: {e}")
    
    # Test PulseAudio
    logger.info("Testing PulseAudio...")
    try:
        result = subprocess.run(['pactl', 'info'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            logger.info("✓ PulseAudio is running")
            # Get sink info
            result = subprocess.run(['pactl', 'list', 'sinks', 'short'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                logger.info("PulseAudio sinks:")
                for line in result.stdout.split('\n'):
                    if line.strip():
                        logger.info(f"  {line}")
            return True
        else:
            logger.warning("✗ PulseAudio not running")
    except Exception as e:
        logger.error(f"✗ PulseAudio test failed: {e}")
    
    return False

def test_pygame_audio():
    """Test pygame audio initialization"""
    logger.info("=== Testing Pygame Audio ===")
    
    # Test different audio drivers
    drivers_to_test = ["pulse", "alsa", "dummy"]
    
    for driver in drivers_to_test:
        logger.info(f"Testing {driver} driver...")
        try:
            # Set environment
            os.environ["SDL_AUDIODRIVER"] = driver
            
            # Initialize pygame mixer
            pygame.mixer.pre_init(
                frequency=MIX_FREQ,
                size=-16,
                channels=2,
                buffer=MIX_BUF
            )
            
            pygame.mixer.init()
            
            # Test with a simple sound
            test_sound = create_test_sound(440, 0.1)
            if test_sound:
                channel = pygame.mixer.Channel(0)
                channel.play(test_sound)
                time.sleep(0.2)
                channel.stop()
                logger.info(f"✓ {driver} driver works")
                pygame.mixer.quit()
                return True
            else:
                logger.warning(f"✗ {driver} driver failed - no test sound")
                
        except Exception as e:
            logger.error(f"✗ {driver} driver failed: {e}")
        finally:
            try:
                pygame.mixer.quit()
            except:
                pass
    
    return False

def create_test_sound(frequency=440, duration=0.5):
    """Create a test sound"""
    try:
        import numpy as np
        
        sample_rate = MIX_FREQ
        frames = int(duration * sample_rate)
        arr = np.zeros((frames, 2))
        
        for i in range(frames):
            arr[i][0] = np.sin(2 * np.pi * frequency * i / sample_rate) * 0.3
            arr[i][1] = arr[i][0]
        
        arr = (arr * 32767).astype(np.int16)
        sound = pygame.sndarray.make_sound(arr)
        return sound
    except Exception as e:
        logger.error(f"Test sound creation failed: {e}")
        return None

def test_audio_playback():
    """Test actual audio playback"""
    logger.info("=== Testing Audio Playback ===")
    
    try:
        # Initialize pygame
        pygame.mixer.init(
            frequency=MIX_FREQ,
            size=-16,
            channels=2,
            buffer=MIX_BUF
        )
        
        # Create test sounds
        test_sounds = {
            'low': create_test_sound(220, 0.5),    # A3
            'mid': create_test_sound(440, 0.5),    # A4
            'high': create_test_sound(880, 0.5),   # A5
        }
        
        logger.info("Playing test tones...")
        for name, sound in test_sounds.items():
            if sound:
                logger.info(f"Playing {name} tone (440Hz)...")
                channel = pygame.mixer.Channel(0)
                channel.play(sound)
                time.sleep(0.6)  # Wait for sound to play
                channel.stop()
                time.sleep(0.1)
        
        logger.info("✓ Audio playback test completed")
        return True
        
    except Exception as e:
        logger.error(f"✗ Audio playback test failed: {e}")
        return False
    finally:
        try:
            pygame.mixer.quit()
        except:
            pass

def test_system_audio():
    """Test system audio commands"""
    logger.info("=== Testing System Audio ===")
    
    # Test speaker-test command
    logger.info("Testing speaker-test command...")
    try:
        result = subprocess.run(['speaker-test', '-c2', '-t', 'wav', '-l1'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            logger.info("✓ speaker-test successful")
            return True
        else:
            logger.warning(f"✗ speaker-test failed: {result.stderr}")
    except Exception as e:
        logger.error(f"✗ speaker-test failed: {e}")
    
    # Test aplay command
    logger.info("Testing aplay command...")
    try:
        # Create a simple WAV file for testing
        test_wav = create_test_wav_file()
        if test_wav:
            result = subprocess.run(['aplay', test_wav], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                logger.info("✓ aplay successful")
                return True
            else:
                logger.warning(f"✗ aplay failed: {result.stderr}")
    except Exception as e:
        logger.error(f"✗ aplay test failed: {e}")
    
    return False

def create_test_wav_file():
    """Create a test WAV file"""
    try:
        import numpy as np
        import wave
        
        # Create a simple sine wave
        sample_rate = 44100
        duration = 1.0
        frequency = 440
        
        frames = int(sample_rate * duration)
        arr = np.zeros(frames)
        
        for i in range(frames):
            arr[i] = np.sin(2 * np.pi * frequency * i / sample_rate) * 0.3
        
        # Convert to 16-bit PCM
        arr = (arr * 32767).astype(np.int16)
        
        # Save as WAV file
        test_file = "/tmp/test_audio.wav"
        with wave.open(test_file, 'w') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)   # 16-bit
            wav_file.setframerate(sample_rate)
            wav_file.writeframes(arr.tobytes())
        
        return test_file
    except Exception as e:
        logger.error(f"Failed to create test WAV file: {e}")
        return None

def main():
    """Main test function"""
    logger.info("=== WRB Audio System Test ===")
    logger.info(f"Testing on Pi Zero W with pygame {pygame.version.ver}")
    
    # Test 1: Audio devices
    devices_ok = test_audio_devices()
    
    # Test 2: Pygame audio
    pygame_ok = test_pygame_audio()
    
    # Test 3: Audio playback
    playback_ok = test_audio_playback()
    
    # Test 4: System audio
    system_ok = test_system_audio()
    
    # Summary
    logger.info("=== Test Results Summary ===")
    logger.info(f"Audio devices: {'✓ PASS' if devices_ok else '✗ FAIL'}")
    logger.info(f"Pygame audio: {'✓ PASS' if pygame_ok else '✗ FAIL'}")
    logger.info(f"Audio playback: {'✓ PASS' if playback_ok else '✗ FAIL'}")
    logger.info(f"System audio: {'✓ PASS' if system_ok else '✗ FAIL'}")
    
    if all([devices_ok, pygame_ok, playback_ok]):
        logger.info("🎉 All audio tests passed! Audio system is working.")
        return 0
    else:
        logger.error("❌ Some audio tests failed. Check the logs above for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
