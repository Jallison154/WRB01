#!/usr/bin/env python3
"""
Restore and Fix WRB Script
Restore the original script and apply a minimal fix
"""
import os
import subprocess

def restore_and_fix():
    """Restore original script and apply minimal fix"""
    print("=== WRB Restore and Fix ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    script_path = f"{script_dir}/PiScript"
    backup_path = f"{script_dir}/PiScript-backup"
    
    # Check if backup exists
    if os.path.exists(backup_path):
        print("✅ Found backup script")
        
        # Restore the original script
        try:
            os.rename(script_path, f"{script_dir}/PiScript-broken")
            os.rename(backup_path, script_path)
            print("✅ Restored original script")
        except Exception as e:
            print(f"❌ Error restoring script: {e}")
            return
    else:
        print("❌ No backup found, cannot restore")
        return
    
    # Read the restored script
    try:
        with open(script_path, 'r') as f:
            content = f.read()
        print("✅ Script file readable")
    except Exception as e:
        print(f"❌ Error reading script: {e}")
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
    restore_and_fix()
