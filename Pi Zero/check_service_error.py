#!/usr/bin/env python3
"""
Check WRB Service Error
Find out exactly what's causing the service to fail
"""
import subprocess
import os

def check_service_error():
    """Check what's causing the service to fail"""
    print("=== WRB Service Error Check ===")
    
    # Check current service file
    print("\n1. Checking current service file...")
    try:
        result = subprocess.run(['systemctl', 'cat', 'WRB-enhanced.service'], 
                              capture_output=True, text=True)
        print("Current service file:")
        print(result.stdout)
    except Exception as e:
        print(f"Error reading service file: {e}")
    
    # Check recent logs
    print("\n2. Checking recent service logs...")
    try:
        result = subprocess.run(['journalctl', '-u', 'WRB-enhanced.service', '--since', '2 minutes ago', '--no-pager'], 
                              capture_output=True, text=True)
        print("Recent logs:")
        print(result.stdout)
    except Exception as e:
        print(f"Error reading logs: {e}")
    
    # Test script manually
    print("\n3. Testing script manually...")
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    
    try:
        # Change to script directory and run
        result = subprocess.run(
            f"cd '{script_dir}' && python3 PiScript",
            shell=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        print(f"Return code: {result.returncode}")
        if result.stdout:
            print(f"STDOUT: {result.stdout}")
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
    except subprocess.TimeoutExpired:
        print("Script is running (timeout - this is good)")
    except Exception as e:
        print(f"Error running script: {e}")
    
    # Check if config.py exists and is valid
    print("\n4. Checking config.py...")
    config_path = f"{script_dir}/config.py"
    if os.path.exists(config_path):
        print(f"✅ config.py exists: {config_path}")
        try:
            with open(config_path, 'r') as f:
                content = f.read()
                print(f"Config content: {content[:200]}...")
        except Exception as e:
            print(f"❌ Error reading config.py: {e}")
    else:
        print(f"❌ config.py missing: {config_path}")
        print("Creating basic config.py...")
        try:
            with open(config_path, 'w') as f:
                f.write("""# WRB Configuration
MIX_FREQ = 22050
MIX_BUF = 512
FADE_OUT_DURATION = 1.0
BUTTON_DEBOUNCE_TIME = 0.1
""")
            print("✅ Created basic config.py")
        except Exception as e:
            print(f"❌ Error creating config.py: {e}")
    
    # Test with environment variables
    print("\n5. Testing with environment variables...")
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
        print("Script running with env vars (timeout - this is good)")
    except Exception as e:
        print(f"Error with env vars: {e}")

if __name__ == "__main__":
    check_service_error()
