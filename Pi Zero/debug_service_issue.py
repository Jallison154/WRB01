#!/usr/bin/env python3
"""
Debug Service Issue
Check what's causing the service to fail
"""
import os
import subprocess

def debug_service_issue():
    """Debug the service issue"""
    print("=== Debugging Service Issue ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    script_path = f"{script_dir}/PiScript"
    
    # Check if script exists and is executable
    print(f"\n=== Checking Script ===")
    print(f"Script path: {script_path}")
    print(f"Script exists: {os.path.exists(script_path)}")
    print(f"Script is executable: {os.access(script_path, os.X_OK)}")
    
    # Check script syntax
    print(f"\n=== Checking Script Syntax ===")
    try:
        result = subprocess.run(
            f"cd '{script_dir}' && python3 -m py_compile PiScript",
            shell=True,
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            print("✅ Script syntax is valid")
        else:
            print(f"❌ Script has syntax errors: {result.stderr}")
            return
    except Exception as e:
        print(f"❌ Error checking syntax: {e}")
        return
    
    # Test script manually
    print(f"\n=== Testing Script Manually ===")
    try:
        result = subprocess.run(
            f"cd '{script_dir}' && timeout 5 python3 PiScript",
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
        print("✅ Script is running (timeout - this is good)")
    except Exception as e:
        print(f"❌ Error testing script: {e}")
    
    # Check service status
    print(f"\n=== Checking Service Status ===")
    try:
        result = subprocess.run(
            "systemctl status WRB-enhanced.service",
            shell=True,
            capture_output=True,
            text=True
        )
        
        print(f"Service status:")
        print(result.stdout)
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
    except Exception as e:
        print(f"❌ Error checking service status: {e}")
    
    # Check recent logs
    print(f"\n=== Checking Recent Logs ===")
    try:
        result = subprocess.run(
            "journalctl -u WRB-enhanced.service --no-pager -n 20",
            shell=True,
            capture_output=True,
            text=True
        )
        
        print(f"Recent logs:")
        print(result.stdout)
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
    except Exception as e:
        print(f"❌ Error checking logs: {e}")
    
    print(f"\n=== Debug Complete ===")

if __name__ == "__main__":
    debug_service_issue()
