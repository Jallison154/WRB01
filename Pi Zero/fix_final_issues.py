#!/usr/bin/env python3
"""
Fix Final WRB Issues
Fix permissions and audio device problems
"""
import subprocess
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

def fix_final_issues():
    """Fix final issues"""
    print("=== WRB Final Issues Fix ===")
    
    # Fix script permissions
    print("\n1. Fixing script permissions...")
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    
    # Make all Python scripts executable
    scripts = ["PiScript", "test_pwm.py", "startup_test.py", "test_complete_system.py", 
               "fix_dependencies.py", "diagnose_service.py", "fix_debian_packages.py"]
    
    for script in scripts:
        script_path = f"{script_dir}/{script}"
        if os.path.exists(script_path):
            os.chmod(script_path, 0o755)
            print(f"   ✅ {script} - Made executable")
        else:
            print(f"   ⚠️  {script} - Not found")
    
    # Fix service file path issue
    print("\n2. Fixing service file...")
    service_content = f"""[Unit]
Description=WRB Enhanced Audio System
After=network.target
Wants=network.target
StartLimitInterval=300
StartLimitBurst=3

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory={script_dir}
Environment=HOME={home_dir}
Environment=USER=wrb01
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:0,0
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/python3 {script_dir}/PiScript
Restart=on-failure
RestartSec=5
RestartPreventExitStatus=1
StandardOutput=journal
StandardError=journal
TimeoutStartSec=30
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target"""
    
    # Write new service file
    with open(f"{script_dir}/WRB-enhanced-fixed.service", "w") as f:
        f.write(service_content)
    
    # Install the fixed service file
    run_command(f"sudo cp '{script_dir}/WRB-enhanced-fixed.service' /etc/systemd/system/WRB-enhanced.service", "Installing fixed service file")
    run_command("sudo systemctl daemon-reload", "Reloading systemd")
    
    # Fix audio device issues
    print("\n3. Fixing audio device...")
    
    # Check available audio devices
    run_command("aplay -l", "Available audio devices")
    
    # Test audio device
    run_command("speaker-test -t wav -c 2 -l 1", "Testing audio device")
    
    # Set audio environment variables
    run_command("export SDL_AUDIODRIVER=alsa", "Setting SDL audio driver")
    run_command("export AUDIODEV=plughw:0,0", "Setting audio device")
    
    # Test service
    print("\n4. Testing service...")
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
    fix_final_issues()
