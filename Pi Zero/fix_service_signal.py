#!/usr/bin/env python3
"""
Fix WRB Service Signal Issues
Remove problematic ExecStartPre and test service
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

def fix_service_signal():
    """Fix service signal issues"""
    print("=== WRB Service Signal Fix ===")
    
    # Create simplified service file without ExecStartPre
    home_dir = os.path.expanduser("~")
    script_dir = f"{home_dir}/WRB01/Pi Zero"
    
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
    
    # Write new service file
    with open(f"{script_dir}/WRB-enhanced-simple.service", "w") as f:
        f.write(service_content)
    
    # Install the simplified service file
    run_command(f"sudo cp '{script_dir}/WRB-enhanced-simple.service' /etc/systemd/system/WRB-enhanced.service", "Installing simplified service file")
    run_command("sudo systemctl daemon-reload", "Reloading systemd")
    
    # Test manual script execution
    print("\n=== Manual Script Test ===")
    run_command(f"cd '{script_dir}' && timeout 10 python3 PiScript", "Testing script manually")
    
    # Test service
    print("\n=== Testing Service ===")
    run_command("sudo systemctl stop WRB-enhanced.service", "Stopping service")
    run_command("sudo systemctl start WRB-enhanced.service", "Starting service")
    
    # Wait a moment and check status
    import time
    time.sleep(3)
    
    # Check service status
    result = subprocess.run(['systemctl', 'is-active', 'WRB-enhanced.service'], 
                          capture_output=True, text=True)
    if result.stdout.strip() == 'active':
        print("   ✅ Service is running")
        
        # Check if it's actually working
        result = subprocess.run(['systemctl', 'status', 'WRB-enhanced.service', '--no-pager'], 
                              capture_output=True, text=True)
        print(f"   Service status: {result.stdout.strip()}")
    else:
        print("   ❌ Service failed to start")
        print("   Check logs: sudo journalctl -u WRB-enhanced.service -f")
    
    print(f"\n=== Fix Complete ===")
    print("Run: python3 test_complete_system.py")

if __name__ == "__main__":
    fix_service_signal()
