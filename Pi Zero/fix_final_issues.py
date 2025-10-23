#!/usr/bin/env python3
"""
Fix Final WRB Issues - Service Path and Audio
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
    """Fix service path and audio issues"""
    print("=== WRB Final Issues Fix ===")
    
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    
    print(f"Home directory: {home_dir}")
    print(f"Script directory: {script_dir}")
    print(f"Script exists: {os.path.exists(f'{script_dir}/PiScript')}")
    
    # 1. Fix service file with correct path
    print("\n1. Fixing service file...")
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
Environment=AUDIODEV=default
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStart=/usr/bin/python3 {script_dir}/PiScript
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=1
StandardOutput=journal
StandardError=journal
TimeoutStartSec=60
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target"""
    
    # Write the correct service file
    with open(f"{script_dir}/WRB-enhanced-fixed.service", "w") as f:
        f.write(service_content)
    
    # Install the service file
    run_command(f"sudo cp '{script_dir}/WRB-enhanced-fixed.service' /etc/systemd/system/WRB-enhanced.service", "Installing fixed service file")
    run_command("sudo systemctl daemon-reload", "Reloading systemd")
    
    # 2. Fix audio device issues
    print("\n2. Fixing audio device...")
    
    # Check available audio devices
    run_command("aplay -l", "Available audio devices")
    
    # Test different audio devices
    print("\nTesting audio devices...")
    devices_to_test = [
        "default",
        "plughw:0,0", 
        "plughw:1,0",
        "hw:0,0",
        "hw:1,0"
    ]
    
    for device in devices_to_test:
        print(f"Testing device: {device}")
        result = subprocess.run(f"speaker-test -t wav -c 2 -D {device} -l 1", 
                              shell=True, capture_output=True, text=True, timeout=3)
        if result.returncode == 0:
            print(f"   ✅ {device} works")
        else:
            print(f"   ❌ {device} failed")
    
    # 3. Test service
    print("\n3. Testing service...")
    run_command("sudo systemctl stop WRB-enhanced.service", "Stopping service")
    run_command("sudo systemctl start WRB-enhanced.service", "Starting service")
    
    # Wait and check status
    import time
    time.sleep(3)
    
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