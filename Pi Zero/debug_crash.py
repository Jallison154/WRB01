#!/usr/bin/env python3
"""
Debug WRB Script Crash
Find out why the script is crashing on startup
"""
import subprocess
import os
import time

def debug_crash():
    """Debug why the script is crashing"""
    print("=== WRB Script Crash Debug ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    
    print(f"Script directory: {script_dir}")
    print(f"Script exists: {os.path.exists(f'{script_dir}/PiScript')}")
    
    # Test script execution with full error capture
    print("\n1. Testing script execution...")
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
        print("Script is running (timeout - this is good)")
    except Exception as e:
        print(f"Error running script: {e}")
    
    # Test with environment variables like the service
    print("\n2. Testing with service environment...")
    env = os.environ.copy()
    env['HOME'] = home_dir
    env['USER'] = 'wrb01'
    env['WRB_SERIAL'] = '/dev/ttyACM0'
    env['SDL_AUDIODRIVER'] = 'alsa'
    env['AUDIODEV'] = 'default'
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
        print("Script running with env vars (timeout - this is good)")
    except Exception as e:
        print(f"Error with env vars: {e}")
    
    # Check if config.py is valid
    print("\n3. Checking config.py...")
    config_path = f"{script_dir}/config.py"
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                content = f.read()
                print(f"Config file size: {len(content)} characters")
                print(f"First 200 chars: {content[:200]}")
        except Exception as e:
            print(f"Error reading config: {e}")
    else:
        print("Config file missing!")
    
    # Test imports individually
    print("\n4. Testing imports individually...")
    imports_to_test = [
        "import serial",
        "import pygame", 
        "import RPi.GPIO as GPIO",
        "import numpy",
        "from config import *"
    ]
    
    for import_stmt in imports_to_test:
        try:
            result = subprocess.run(
                f"cd '{script_dir}' && python3 -c '{import_stmt}'",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                print(f"✅ {import_stmt}")
            else:
                print(f"❌ {import_stmt} - {result.stderr}")
        except Exception as e:
            print(f"❌ {import_stmt} - {e}")
    
    # Check audio device
    print("\n5. Checking audio device...")
    try:
        result = subprocess.run(['aplay', '-l'], capture_output=True, text=True)
        print(f"Audio devices: {result.stdout}")
    except Exception as e:
        print(f"Audio check error: {e}")
    
    # Test audio with pygame
    print("\n6. Testing pygame audio...")
    try:
        result = subprocess.run(
            f"cd '{script_dir}' && python3 -c 'import pygame; pygame.mixer.init(); print(\"Audio OK\")'",
            shell=True,
            capture_output=True,
            text=True,
            timeout=5
        )
        print(f"Pygame audio test: {result.returncode}")
        if result.stdout:
            print(f"Output: {result.stdout}")
        if result.stderr:
            print(f"Error: {result.stderr}")
    except Exception as e:
        print(f"Pygame audio error: {e}")

if __name__ == "__main__":
    debug_crash()
