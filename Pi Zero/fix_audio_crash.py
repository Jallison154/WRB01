#!/usr/bin/env python3
"""
Fix WRB Audio Crash
Make the script continue even if audio fails
"""
import os

def fix_audio_crash():
    """Fix the audio crash issue"""
    print("=== WRB Audio Crash Fix ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    script_path = f"{script_dir}/PiScript"
    
    print(f"Script path: {script_path}")
    
    # Read the current script
    try:
        with open(script_path, 'r') as f:
            content = f.read()
        print("✅ Script file readable")
    except Exception as e:
        print(f"❌ Error reading script: {e}")
        return
    
    # Check if audio setup is causing the crash
    if "Audio setup failed, exiting" in content:
        print("✅ Found audio crash issue")
        
        # Create a modified version that doesn't exit on audio failure
        modified_content = content.replace(
            "if not setup_audio():\n        logger.error(\"Audio setup failed, exiting\")\n        cleanup_gpio()\n        return 1",
            "if not setup_audio():\n        logger.warning(\"Audio setup failed, continuing without audio\")\n        # cleanup_gpio()\n        # return 1"
        )
        
        # Write the modified script
        try:
            with open(f"{script_dir}/PiScript-fixed", 'w') as f:
                f.write(modified_content)
            print("✅ Created fixed script")
        except Exception as e:
            print(f"❌ Error writing fixed script: {e}")
            return
        
        # Make it executable
        os.chmod(f"{script_dir}/PiScript-fixed", 0o755)
        print("✅ Made fixed script executable")
        
        # Test the fixed script
        print("\n=== Testing Fixed Script ===")
        try:
            import subprocess
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
            os.rename(f"{script_dir}/PiScript", f"{script_dir}/PiScript-backup")
            os.rename(f"{script_dir}/PiScript-fixed", f"{script_dir}/PiScript")
            print("✅ Replaced original script with fixed version")
        except Exception as e:
            print(f"❌ Error replacing script: {e}")
    
    else:
        print("❌ Audio crash pattern not found in script")
    
    print(f"\n=== Fix Complete ===")
    print("Test the service: sudo systemctl restart WRB-enhanced.service")

if __name__ == "__main__":
    fix_audio_crash()
