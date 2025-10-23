#!/usr/bin/env python3
"""
Fix WRB Script Structure
Properly fix the script without breaking the main loop
"""
import os
import subprocess

def fix_script_structure():
    """Fix the script structure properly"""
    print("=== WRB Script Structure Fix ===")
    
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
    
    # Create a proper fix that doesn't break the main loop
    print("\n=== Creating Proper Fix ===")
    
    # Find the audio setup section and modify it properly
    lines = content.split('\n')
    modified_lines = []
    
    for i, line in enumerate(lines):
        if "if not setup_audio():" in line:
            # Replace the audio failure handling
            modified_lines.append("if not setup_audio():")
            modified_lines.append("        logger.warning(\"Audio setup failed, continuing without audio\")")
            modified_lines.append("        # Audio failed but continue anyway")
        elif "logger.error(\"Audio setup failed, exiting\")" in line:
            # Skip this line
            continue
        elif "cleanup_gpio()" in line and "return 1" in line:
            # Skip the cleanup and return
            continue
        else:
            modified_lines.append(line)
    
    # Write the properly modified script
    try:
        with open(f"{script_dir}/PiScript-fixed", 'w') as f:
            f.write('\n'.join(modified_lines))
        os.chmod(f"{script_dir}/PiScript-fixed", 0o755)
        print("✅ Created properly fixed script")
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
        os.rename(f"{script_dir}/PiScript", f"{script_dir}/PiScript-backup")
        os.rename(f"{script_dir}/PiScript-fixed", f"{script_dir}/PiScript")
        print("✅ Replaced original script with properly fixed version")
    except Exception as e:
        print(f"❌ Error replacing script: {e}")
    
    print(f"\n=== Fix Complete ===")
    print("Test the service: sudo systemctl restart WRB-enhanced.service")

if __name__ == "__main__":
    fix_script_structure()
