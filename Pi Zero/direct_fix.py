#!/usr/bin/env python3
"""
Direct Fix for WRB Script
Fix the script directly without backup
"""
import os
import subprocess

def direct_fix():
    """Fix the script directly"""
    print("=== WRB Direct Fix ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    script_path = f"{script_dir}/PiScript"
    
    # Check what files we have
    print("\n=== Checking Files ===")
    try:
        files = os.listdir(script_dir)
        print(f"Files in directory: {files}")
    except Exception as e:
        print(f"❌ Error listing files: {e}")
        return
    
    # Read the current script
    try:
        with open(script_path, 'r') as f:
            content = f.read()
        print("✅ Script file readable")
    except Exception as e:
        print(f"❌ Error reading script: {e}")
        return
    
    # Check if the script has syntax errors
    print("\n=== Checking Script Syntax ===")
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
    
    # Apply a minimal fix - just change the audio failure handling
    print("\n=== Applying Minimal Fix ===")
    
    # Find and replace the audio failure handling
    if "Audio setup failed, exiting" in content:
        print("✅ Found audio exit pattern")
        
        # Create a minimal fix - just change the error message and remove the exit
        fixed_content = content.replace(
            "logger.error(\"Audio setup failed, exiting\")",
            "logger.warning(\"Audio setup failed, continuing without audio\")"
        ).replace(
            "cleanup_gpio()\n        return 1",
            "# cleanup_gpio()\n        # return 1"
        )
        
        # Write the fixed script
        try:
            with open(f"{script_dir}/PiScript-fixed", 'w') as f:
                f.write(fixed_content)
            os.chmod(f"{script_dir}/PiScript-fixed", 0o755)
            print("✅ Created fixed script")
        except Exception as e:
            print(f"❌ Error creating fixed script: {e}")
            return
        
        # Test the fixed script
        print("\n=== Testing Fixed Script ===")
        try:
            result = subprocess.run(
                f"cd '{script_dir}' && timeout 10 python3 PiScript-fixed",
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
            print("✅ Fixed script is running (timeout - this is good)")
        except Exception as e:
            print(f"❌ Error testing fixed script: {e}")
        
        # Replace the original script
        try:
            os.rename(script_path, f"{script_dir}/PiScript-original")
            os.rename(f"{script_dir}/PiScript-fixed", script_path)
            print("✅ Replaced original script with fixed version")
        except Exception as e:
            print(f"❌ Error replacing script: {e}")
    else:
        print("❌ Audio exit pattern not found")
    
    print(f"\n=== Fix Complete ===")
    print("Test the service: sudo systemctl restart WRB-enhanced.service")

if __name__ == "__main__":
    direct_fix()
