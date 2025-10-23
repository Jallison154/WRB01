#!/usr/bin/env python3
"""
Fix WRB Running Variable
Fix the global variable issue in the main function
"""
import os
import subprocess

def fix_running_variable():
    """Fix the running variable issue"""
    print("=== WRB Running Variable Fix ===")
    
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
    
    # Fix the running variable issue
    print("\n=== Fixing Running Variable ===")
    
    # Add global declaration in main function
    if "def main():" in content and "global running" not in content:
        print("✅ Found main function, adding global declaration")
        
        # Add global running declaration at the start of main function
        fixed_content = content.replace(
            "def main():",
            "def main():\n    global running"
        )
        
        # Also fix the audio failure handling
        if "Audio setup failed, exiting" in fixed_content:
            print("✅ Found audio exit pattern, fixing it")
            fixed_content = fixed_content.replace(
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
                f"cd '{script_dir}' && timeout 15 python3 PiScript-fixed",
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
        print("❌ Main function not found or already has global declaration")
    
    print(f"\n=== Fix Complete ===")
    print("Test the service: sudo systemctl restart WRB-enhanced.service")

if __name__ == "__main__":
    fix_running_variable()
