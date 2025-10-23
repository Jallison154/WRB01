#!/usr/bin/env python3
"""
Check WRB Startup Issues
See what's happening when the system starts
"""
import subprocess
import os
import time

def check_startup():
    """Check what's happening on startup"""
    print("=== WRB Startup Check ===")
    
    # Check service status
    print("\n1. Checking service status...")
    try:
        result = subprocess.run(['systemctl', 'status', 'WRB-enhanced.service', '--no-pager'], 
                              capture_output=True, text=True)
        print("Service status:")
        print(result.stdout)
    except Exception as e:
        print(f"Error checking service: {e}")
    
    # Check if service is actually running
    print("\n2. Checking if service is running...")
    try:
        result = subprocess.run(['systemctl', 'is-active', 'WRB-enhanced.service'], 
                              capture_output=True, text=True)
        print(f"Service active: {result.stdout.strip()}")
    except Exception as e:
        print(f"Error checking service: {e}")
    
    # Check recent logs
    print("\n3. Checking recent logs...")
    try:
        result = subprocess.run(['journalctl', '-u', 'WRB-enhanced.service', '--since', '5 minutes ago', '--no-pager'], 
                              capture_output=True, text=True)
        print("Recent logs:")
        print(result.stdout)
    except Exception as e:
        print(f"Error reading logs: {e}")
    
    # Check if script is actually running
    print("\n4. Checking if script is running...")
    try:
        result = subprocess.run(['pgrep', '-f', 'PiScript'], capture_output=True, text=True)
        if result.stdout.strip():
            print(f"PiScript processes: {result.stdout.strip()}")
        else:
            print("No PiScript processes running")
    except Exception as e:
        print(f"Error checking processes: {e}")
    
    # Test manual script execution
    print("\n5. Testing manual script execution...")
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    
    try:
        print("Running script manually for 10 seconds...")
        result = subprocess.run(
            f"cd '{script_dir}' && timeout 10 python3 PiScript",
            shell=True,
            capture_output=True,
            text=True
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
    
    # Check LED status
    print("\n6. Checking LED status...")
    try:
        import RPi.GPIO as GPIO
        GPIO.setmode(GPIO.BCM)
        
        # Check if LEDs are on
        ready_pin = 23
        usb_pin = 24
        
        GPIO.setup(ready_pin, GPIO.IN)
        GPIO.setup(usb_pin, GPIO.IN)
        
        ready_state = GPIO.input(ready_pin)
        usb_state = GPIO.input(usb_pin)
        
        print(f"Ready LED (GPIO 23): {'ON' if ready_state else 'OFF'}")
        print(f"USB LED (GPIO 24): {'ON' if usb_state else 'OFF'}")
        
        GPIO.cleanup()
        
    except Exception as e:
        print(f"Error checking LEDs: {e}")
    
    # Check serial ports
    print("\n7. Checking serial ports...")
    try:
        result = subprocess.run(['ls', '-la', '/dev/tty*'], capture_output=True, text=True)
        print("Available serial ports:")
        print(result.stdout)
    except Exception as e:
        print(f"Error checking serial ports: {e}")

if __name__ == "__main__":
    check_startup()
