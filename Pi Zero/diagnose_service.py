#!/usr/bin/env python3
"""
Diagnose WRB Service Issues
Check logs and identify problems
"""
import subprocess
import os

def run_command(cmd, description):
    """Run a command and report results"""
    print(f"\n{description}...")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        print(f"   Return code: {result.returncode}")
        if result.stdout.strip():
            print(f"   Output: {result.stdout.strip()}")
        if result.stderr.strip():
            print(f"   Error: {result.stderr.strip()}")
        return result.returncode == 0
    except Exception as e:
        print(f"   Exception: {e}")
        return False

def diagnose_service():
    """Diagnose service issues"""
    print("=== WRB Service Diagnosis ===")
    
    # Check service status
    run_command("systemctl status WRB-enhanced.service", "Service status")
    
    # Check recent logs
    run_command("journalctl -u WRB-enhanced.service --since '5 minutes ago' --no-pager", "Recent logs")
    
    # Check if service file exists
    if os.path.exists("/etc/systemd/system/WRB-enhanced.service"):
        print("\n✅ Service file exists in systemd")
    else:
        print("\n❌ Service file missing from systemd")
    
    # Check if script exists and is executable
    home_dir = os.path.expanduser("~")
    script_path = f"{home_dir}/WRB01/Pi Zero/PiScript"
    
    if os.path.exists(script_path):
        print(f"✅ Script exists: {script_path}")
        if os.access(script_path, os.X_OK):
            print("✅ Script is executable")
        else:
            print("❌ Script is not executable")
            print("   Fix: chmod +x PiScript")
    else:
        print(f"❌ Script missing: {script_path}")
    
    # Test script manually
    print(f"\n=== Manual Script Test ===")
    run_command(f"cd '{home_dir}/WRB01/Pi Zero' && python3 -c 'import sys; print(\"Python OK\"); import pygame; print(\"Pygame OK\")'", "Python imports test")
    
    # Test GPIO import
    run_command(f"cd '{home_dir}/WRB01/Pi Zero' && python3 -c 'import RPi.GPIO as GPIO; print(\"GPIO OK\")'", "GPIO import test")
    
    # Test script startup
    print(f"\n=== Script Startup Test ===")
    run_command(f"cd '{home_dir}/WRB01/Pi Zero' && timeout 10 python3 PiScript", "Script startup test")

if __name__ == "__main__":
    diagnose_service()
