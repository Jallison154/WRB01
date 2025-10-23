#!/usr/bin/env python3
"""
Fix WRB Dependencies
Install missing packages and fix service issues
"""
import subprocess
import sys
import os

def run_command(cmd, description):
    """Run a command and report results"""
    print(f"\n{description}...")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"   ✅ {description} - Success")
            if result.stdout.strip():
                print(f"   Output: {result.stdout.strip()}")
            return True
        else:
            print(f"   ❌ {description} - Failed")
            print(f"   Error: {result.stderr.strip()}")
            return False
    except Exception as e:
        print(f"   ❌ {description} - Exception: {e}")
        return False

def fix_dependencies():
    """Fix all missing dependencies and service issues"""
    print("=== WRB Dependencies Fix ===")
    
    # Update package lists
    run_command("sudo apt update", "Updating package lists")
    
    # Install system packages
    system_packages = [
        "python3-pip",
        "python3-dev",
        "python3-setuptools",
        "python3-wheel",
        "alsa-utils",
        "libasound2-dev",
        "portaudio19-dev"
    ]
    
    for package in system_packages:
        run_command(f"sudo apt install -y {package}", f"Installing {package}")
    
    # Install Python packages
    python_packages = [
        "RPi.GPIO",
        "pygame",
        "pyserial",
        "numpy"
    ]
    
    for package in python_packages:
        run_command(f"pip3 install --user {package}", f"Installing Python {package}")
    
    # Add user to required groups
    run_command("sudo usermod -a -G audio,gpio,dialout $USER", "Adding user to groups")
    
    # Fix service file permissions
    home_dir = os.path.expanduser("~")
    service_file = f"{home_dir}/WRB01/Pi Zero/WRB-enhanced.service"
    
    if os.path.exists(service_file):
        run_command(f"sudo cp {service_file} /etc/systemd/system/", "Installing service file")
        run_command("sudo systemctl daemon-reload", "Reloading systemd")
    else:
        print(f"   ❌ Service file not found: {service_file}")
    
    # Test GPIO access
    print(f"\n=== Testing GPIO Access ===")
    try:
        import RPi.GPIO as GPIO
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(23, GPIO.OUT)
        GPIO.output(23, GPIO.HIGH)
        GPIO.cleanup()
        print("   ✅ GPIO access working")
    except Exception as e:
        print(f"   ❌ GPIO test failed: {e}")
        print("   Try: sudo python3 -c 'import RPi.GPIO as GPIO; print(\"GPIO OK\")'")
    
    # Test service
    print(f"\n=== Testing Service ===")
    run_command("sudo systemctl stop WRB-enhanced.service", "Stopping service")
    run_command("sudo systemctl start WRB-enhanced.service", "Starting service")
    
    # Check service status
    result = subprocess.run(['systemctl', 'is-active', 'WRB-enhanced.service'], 
                          capture_output=True, text=True)
    if result.stdout.strip() == 'active':
        print("   ✅ Service is running")
    else:
        print("   ❌ Service failed to start")
        print("   Check logs: sudo journalctl -u WRB-enhanced.service -f")
    
    print(f"\n=== Fix Complete ===")
    print("Run: python3 test_complete_system.py")

if __name__ == "__main__":
    fix_dependencies()
