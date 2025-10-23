#!/usr/bin/env python3
"""
Fix WRB Audio Issue Directly
Modify the script to handle audio failures gracefully
"""
import os
import subprocess

def fix_audio_direct():
    """Fix audio issue directly"""
    print("=== WRB Audio Direct Fix ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    script_path = f"{script_dir}/PiScript"
    
    # Read the current script
    try:
        with open(script_path, 'r') as f:
            content = f.read()
        print("✅ Script file readable")
    except Exception as e:
        print(f"❌ Error reading script: {e}")
        return
    
    # Look for the main function and audio setup
    print("\n=== Analyzing Script ===")
    
    # Check if we can find the main function
    if "def main():" in content:
        print("✅ Found main function")
    else:
        print("❌ Main function not found")
    
    # Check if we can find audio setup
    if "setup_audio" in content:
        print("✅ Found audio setup")
    else:
        print("❌ Audio setup not found")
    
    # Check if we can find the exit on audio failure
    if "Audio setup failed, exiting" in content:
        print("✅ Found audio exit pattern")
    else:
        print("❌ Audio exit pattern not found")
    
    # Create a simple test script to see what's happening
    print("\n=== Creating Test Script ===")
    test_script = f"""#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '{script_dir}')

# Test imports
try:
    import serial
    print("✅ serial imported")
except Exception as e:
    print(f"❌ serial import failed: {{e}}")

try:
    import pygame
    print("✅ pygame imported")
except Exception as e:
    print(f"❌ pygame import failed: {{e}}")

try:
    import RPi.GPIO as GPIO
    print("✅ RPi.GPIO imported")
except Exception as e:
    print(f"❌ RPi.GPIO import failed: {{e}}")

try:
    from config import *
    print("✅ config imported")
except Exception as e:
    print(f"❌ config import failed: {{e}}")

# Test audio setup
try:
    pygame.mixer.init(frequency=22050, size=-16, channels=2, buffer=512)
    print("✅ pygame mixer initialized")
    pygame.mixer.quit()
except Exception as e:
    print(f"❌ pygame mixer failed: {{e}}")

print("Test complete")
"""
    
    try:
        with open(f"{script_dir}/test_imports.py", 'w') as f:
            f.write(test_script)
        os.chmod(f"{script_dir}/test_imports.py", 0o755)
        print("✅ Created test script")
    except Exception as e:
        print(f"❌ Error creating test script: {e}")
        return
    
    # Run the test script
    print("\n=== Running Test Script ===")
    try:
        result = subprocess.run(
            f"cd '{script_dir}' && python3 test_imports.py",
            shell=True,
            capture_output=True,
            text=True
        )
        
        print(f"Return code: {result.returncode}")
        if result.stdout:
            print(f"STDOUT: {result.stdout}")
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
    except Exception as e:
        print(f"❌ Error running test script: {e}")
    
    # Create a modified version of the main script that doesn't exit on audio failure
    print("\n=== Creating Modified Script ===")
    try:
        # Read the original script
        with open(script_path, 'r') as f:
            original_content = f.read()
        
        # Create a modified version that continues even if audio fails
        modified_content = original_content.replace(
            "if not setup_audio():",
            "if not setup_audio():"
        ).replace(
            "logger.error(\"Audio setup failed, exiting\")",
            "logger.warning(\"Audio setup failed, continuing without audio\")"
        ).replace(
            "cleanup_gpio()\n        return 1",
            "# cleanup_gpio()\n        # return 1"
        )
        
        # Write the modified script
        with open(f"{script_dir}/PiScript-modified", 'w') as f:
            f.write(modified_content)
        os.chmod(f"{script_dir}/PiScript-modified", 0o755)
        print("✅ Created modified script")
        
        # Test the modified script
        print("\n=== Testing Modified Script ===")
        try:
            result = subprocess.run(
                f"cd '{script_dir}' && timeout 10 python3 PiScript-modified",
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
            print("✅ Modified script is running (timeout - this is good)")
        except Exception as e:
            print(f"❌ Error testing modified script: {e}")
        
        # Replace the original script
        try:
            os.rename(f"{script_dir}/PiScript", f"{script_dir}/PiScript-backup")
            os.rename(f"{script_dir}/PiScript-modified", f"{script_dir}/PiScript")
            print("✅ Replaced original script with modified version")
        except Exception as e:
            print(f"❌ Error replacing script: {e}")
            
    except Exception as e:
        print(f"❌ Error creating modified script: {e}")
    
    print(f"\n=== Fix Complete ===")
    print("Test the service: sudo systemctl restart WRB-enhanced.service")

if __name__ == "__main__":
    fix_audio_direct()
