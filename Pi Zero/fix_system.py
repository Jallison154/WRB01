#!/usr/bin/env python3
"""
Fix WRB System - Create missing files and directories
"""
import os
import shutil
import subprocess
import sys

def fix_system():
    """Fix missing files and directories"""
    print("=== WRB System Fix ===")
    
    # Get current directory and user
    current_dir = os.getcwd()
    home_dir = os.path.expanduser("~")
    user = os.getenv('USER', 'wrb01')
    
    print(f"Current directory: {current_dir}")
    print(f"Home directory: {home_dir}")
    print(f"User: {user}")
    
    # Create directories
    print("\n1. Creating directories...")
    dirs_to_create = [
        f"{home_dir}/WRB01/Pi Zero/logs",
        f"{home_dir}/WRB01/Pi Zero/sounds",
        f"{home_dir}/WRB01/Pi Zero/default_sounds"
    ]
    
    for dir_path in dirs_to_create:
        try:
            os.makedirs(dir_path, exist_ok=True)
            print(f"   ✅ {dir_path}")
        except Exception as e:
            print(f"   ❌ {dir_path} - {e}")
    
    # Copy files from current directory
    print("\n2. Copying files...")
    files_to_copy = [
        ("PiScript", f"{home_dir}/WRB01/Pi Zero/PiScript"),
        ("config.py", f"{home_dir}/WRB01/Pi Zero/config.py"),
        ("WRB-enhanced.service", f"{home_dir}/WRB01/Pi Zero/WRB-enhanced.service"),
        ("test_pwm.py", f"{home_dir}/WRB01/Pi Zero/test_pwm.py"),
        ("startup_test.py", f"{home_dir}/WRB01/Pi Zero/startup_test.py"),
        ("test_complete_system.py", f"{home_dir}/WRB01/Pi Zero/test_complete_system.py")
    ]
    
    for src, dst in files_to_copy:
        try:
            if os.path.exists(src):
                shutil.copy2(src, dst)
                print(f"   ✅ {src} -> {dst}")
            else:
                print(f"   ⚠️  {src} not found in current directory")
        except Exception as e:
            print(f"   ❌ {src} -> {dst} - {e}")
    
    # Copy default sounds if they exist
    print("\n3. Copying default sounds...")
    default_sounds_src = "Default Sounds"
    default_sounds_dst = f"{home_dir}/WRB01/Pi Zero/default_sounds"
    
    if os.path.exists(default_sounds_src):
        try:
            for item in os.listdir(default_sounds_src):
                src_path = os.path.join(default_sounds_src, item)
                dst_path = os.path.join(default_sounds_dst, item)
                if os.path.isfile(src_path):
                    shutil.copy2(src_path, dst_path)
                    print(f"   ✅ {item}")
        except Exception as e:
            print(f"   ❌ Error copying default sounds: {e}")
    else:
        print("   ⚠️  Default Sounds directory not found")
    
    # Set permissions
    print("\n4. Setting permissions...")
    try:
        # Make scripts executable
        scripts = [
            f"{home_dir}/WRB01/Pi Zero/PiScript",
            f"{home_dir}/WRB01/Pi Zero/test_pwm.py",
            f"{home_dir}/WRB01/Pi Zero/startup_test.py",
            f"{home_dir}/WRB01/Pi Zero/test_complete_system.py"
        ]
        
        for script in scripts:
            if os.path.exists(script):
                os.chmod(script, 0o755)
                print(f"   ✅ {script} - executable")
        
        # Set directory permissions
        for dir_path in dirs_to_create:
            if os.path.exists(dir_path):
                os.chmod(dir_path, 0o755)
                print(f"   ✅ {dir_path} - permissions set")
                
    except Exception as e:
        print(f"   ❌ Permission error: {e}")
    
    # Update service file
    print("\n5. Updating service file...")
    try:
        # Copy service file to systemd
        service_src = f"{home_dir}/WRB01/Pi Zero/WRB-enhanced.service"
        service_dst = "/etc/systemd/system/WRB-enhanced.service"
        
        if os.path.exists(service_src):
            subprocess.run(['sudo', 'cp', service_src, service_dst], check=True)
            subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
            print(f"   ✅ Service file updated")
        else:
            print(f"   ❌ Service file not found: {service_src}")
            
    except Exception as e:
        print(f"   ❌ Service update failed: {e}")
    
    print(f"\n=== Fix Complete ===")
    print(f"Files should now be in: {home_dir}/WRB01/Pi Zero/")
    print(f"Run: python3 {home_dir}/WRB01/Pi\\ Zero/test_complete_system.py")

if __name__ == "__main__":
    fix_system()
