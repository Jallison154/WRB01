#!/usr/bin/env python3
"""
System Monitor for ESP32 Wireless Button System
Monitors the health and status of the reliable Pi script
"""

import os
import json
import time
import subprocess
from datetime import datetime, timedelta

# Configuration
LOG_FILE = "/home/pi/WRB/button_log.txt"
HEALTH_LOG = "/home/pi/WRB/health_log.txt"
SERVICE_NAME = "WRB-enhanced.service"

def check_service_status():
    """Check if the systemd service is running"""
    try:
        result = subprocess.run(['systemctl', 'is-active', SERVICE_NAME], 
                              capture_output=True, text=True, timeout=5)
        return result.stdout.strip() == 'active'
    except Exception as e:
        print(f"Error checking service status: {e}")
        return False

def get_service_logs(lines=20):
    """Get recent service logs"""
    try:
        result = subprocess.run(['journalctl', '-u', SERVICE_NAME, '-n', str(lines), '--no-pager'], 
                              capture_output=True, text=True, timeout=10)
        return result.stdout
    except Exception as e:
        return f"Error getting logs: {e}"

def parse_health_log():
    """Parse the health log for statistics"""
    if not os.path.exists(HEALTH_LOG):
        return None
    
    try:
        with open(HEALTH_LOG, 'r') as f:
            lines = f.readlines()
        
        # Get the last health check entry
        health_entries = [line for line in lines if '[HEALTH]' in line]
        if not health_entries:
            return None
        
        last_health = health_entries[-1]
        
        # Extract JSON stats
        start_idx = last_health.find('{')
        if start_idx == -1:
            return None
        
        json_str = last_health[start_idx:]
        stats = json.loads(json_str)
        return stats
        
    except Exception as e:
        print(f"Error parsing health log: {e}")
        return None

def get_recent_button_presses(hours=1):
    """Get recent button press activity"""
    if not os.path.exists(LOG_FILE):
        return []
    
    try:
        cutoff_time = datetime.now() - timedelta(hours=hours)
        recent_presses = []
        
        with open(LOG_FILE, 'r') as f:
            for line in f:
                if 'RIGHT button pressed' in line or 'WRONG button pressed' in line:
                    try:
                        # Parse timestamp
                        timestamp_str = line[:19]  # "YYYY-MM-DD HH:MM:SS"
                        timestamp = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
                        if timestamp > cutoff_time:
                            recent_presses.append(line.strip())
                    except:
                        continue
        
        return recent_presses
        
    except Exception as e:
        print(f"Error reading button log: {e}")
        return []

def check_sound_files():
    """Check if sound files are available"""
    sound_dirs = [
        "/home/pi/WRB/sounds",
        "/media"
    ]
    
    sound_files = {
        'button1': [],
        'button2': [],
        'hold1': [],
        'hold2': []
    }
    
    for base_dir in sound_dirs:
        if not os.path.exists(base_dir):
            continue
            
        # Check local sounds directory
        if base_dir == "/home/pi/WRB/sounds":
            button1_files = [f for f in os.listdir(base_dir) if f.startswith('button1') and f.endswith('.wav')]
            button2_files = [f for f in os.listdir(base_dir) if f.startswith('button2') and f.endswith('.wav')]
            hold1_files = [f for f in os.listdir(base_dir) if f.startswith('hold1') and f.endswith('.wav')]
            hold2_files = [f for f in os.listdir(base_dir) if f.startswith('hold2') and f.endswith('.wav')]
            sound_files['button1'].extend([os.path.join(base_dir, f) for f in button1_files])
            sound_files['button2'].extend([os.path.join(base_dir, f) for f in button2_files])
            sound_files['hold1'].extend([os.path.join(base_dir, f) for f in hold1_files])
            sound_files['hold2'].extend([os.path.join(base_dir, f) for f in hold2_files])
        
        # Check USB drives
        else:
            for item in os.listdir(base_dir):
                usb_path = os.path.join(base_dir, item)
                if os.path.ismount(usb_path):
                    try:
                        button1_files = [f for f in os.listdir(usb_path) if f.startswith('button1') and f.endswith('.wav')]
                        button2_files = [f for f in os.listdir(usb_path) if f.startswith('button2') and f.endswith('.wav')]
                        hold1_files = [f for f in os.listdir(usb_path) if f.startswith('hold1') and f.endswith('.wav')]
                        hold2_files = [f for f in os.listdir(usb_path) if f.startswith('hold2') and f.endswith('.wav')]
                        sound_files['button1'].extend([os.path.join(usb_path, f) for f in button1_files])
                        sound_files['button2'].extend([os.path.join(usb_path, f) for f in button2_files])
                        sound_files['hold1'].extend([os.path.join(usb_path, f) for f in hold1_files])
                        sound_files['hold2'].extend([os.path.join(usb_path, f) for f in hold2_files])
                    except:
                        continue
    
    return sound_files

def main():
    """Main monitoring function"""
    print("=== ESP32 Wireless Button System - System Monitor ===\n")
    
    # Check service status
    service_running = check_service_status()
    print(f"Service Status: {'🟢 RUNNING' if service_running else '🔴 STOPPED'}")
    
    # Check sound files
    sound_files = check_sound_files()
    print(f"Sound Files:")
    print(f"  Button1 sounds: {len(sound_files['button1'])}")
    print(f"  Button2 sounds: {len(sound_files['button2'])}")
    print(f"  Hold1 sounds: {len(sound_files['hold1'])}")
    print(f"  Hold2 sounds: {len(sound_files['hold2'])}")
    
    if sound_files['right']:
        print(f"  Right files: {[os.path.basename(f) for f in sound_files['right'][:3]]}")
    if sound_files['wrong']:
        print(f"  Wrong files: {[os.path.basename(f) for f in sound_files['wrong'][:3]]}")
    
    # Get health statistics
    health_stats = parse_health_log()
    if health_stats:
        print(f"\nHealth Statistics:")
        print(f"  Uptime: {health_stats.get('uptime', 'Unknown')}")
        print(f"  Button Presses: {health_stats.get('button_presses', 0)}")
        print(f"  Errors: {health_stats.get('errors', 0)}")
        print(f"  Error Rate: {health_stats.get('error_rate', 'Unknown')}")
        print(f"  LED Available: {'Yes' if health_stats.get('led_available') else 'No'}")
        print(f"  Serial Connected: {'Yes' if health_stats.get('serial_connected') else 'No'}")
    
    # Get recent button presses
    recent_presses = get_recent_button_presses(hours=1)
    print(f"\nRecent Activity (last hour):")
    if recent_presses:
        for press in recent_presses[-5:]:  # Show last 5
            print(f"  {press}")
    else:
        print("  No recent button presses")
    
    # Show recent errors
    if os.path.exists(HEALTH_LOG):
        try:
            with open(HEALTH_LOG, 'r') as f:
                lines = f.readlines()
            
            recent_errors = [line for line in lines[-20:] if '[ERROR]' in line]
            if recent_errors:
                print(f"\nRecent Errors:")
                for error in recent_errors[-3:]:  # Show last 3 errors
                    print(f"  {error.strip()}")
        except:
            pass
    
    print(f"\n=== System Commands ===")
    print(f"Check service: sudo systemctl status {SERVICE_NAME}")
    print(f"View logs: sudo journalctl -u {SERVICE_NAME} -f")
    print(f"Restart service: sudo systemctl restart {SERVICE_NAME}")
    print(f"Stop service: sudo systemctl stop {SERVICE_NAME}")

if __name__ == "__main__":
    main()
