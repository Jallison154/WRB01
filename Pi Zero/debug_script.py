#!/usr/bin/env python3
"""
Debug WRB Script Issues
Run script manually to see actual errors
"""
import subprocess
import os

def debug_script():
    """Debug the script execution"""
    print("=== WRB Script Debug ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    
    print(f"Script directory: {script_dir}")
    print(f"Script exists: {os.path.exists(f'{script_dir}/PiScript')}")
    print(f"Script executable: {os.access(f'{script_dir}/PiScript', os.X_OK)}")
    
    # Test Python imports
    print("\n=== Testing Python Imports ===")
    try:
        import sys
        print(f"Python version: {sys.version}")
        
        import pygame
        print("✅ pygame imported")
        
        import RPi.GPIO as GPIO
        print("✅ RPi.GPIO imported")
        
        import serial
        print("✅ serial imported")
        
        import numpy
        print("✅ numpy imported")
        
    except Exception as e:
        print(f"❌ Import error: {e}")
    
    # Test script execution with error capture
    print("\n=== Testing Script Execution ===")
    try:
        result = subprocess.run(
            f"cd '{script_dir}' && python3 PiScript 2>&1",
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        print(f"Return code: {result.returncode}")
        print(f"STDOUT: {result.stdout}")
        print(f"STDERR: {result.stderr}")
        
    except subprocess.TimeoutExpired:
        print("Script timed out (this might be normal if it's running)")
    except Exception as e:
        print(f"Error running script: {e}")
    
    # Test with different audio device
    print("\n=== Testing Audio Device ===")
    try:
        result = subprocess.run(
            "aplay -l",
            shell=True,
            capture_output=True,
            text=True
        )
        print(f"Audio devices: {result.stdout}")
    except Exception as e:
        print(f"Audio test error: {e}")
    
    # Test with environment variables
    print("\n=== Testing with Environment Variables ===")
    env = os.environ.copy()
    env['SDL_AUDIODRIVER'] = 'alsa'
    env['AUDIODEV'] = 'plughw:0,0'
    env['PYGAME_HIDE_SUPPORT_PROMPT'] = '1'
    
    try:
        result = subprocess.run(
            f"cd '{script_dir}' && python3 PiScript",
            shell=True,
            capture_output=True,
            text=True,
            timeout=5,
            env=env
        )
        
        print(f"Return code: {result.returncode}")
        if result.stdout:
            print(f"STDOUT: {result.stdout}")
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
    except subprocess.TimeoutExpired:
        print("Script running (timeout - this is good)")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    debug_script()
