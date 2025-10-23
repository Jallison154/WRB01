#!/usr/bin/env python3
"""
WRB System Monitor
Monitors the health and status of the WRB system
"""

import subprocess
import time
import json
import os
import sys
from datetime import datetime
from pathlib import Path

class WRBMonitor:
    def __init__(self):
        self.wrb_home = Path.home() / "WRB"
        self.log_file = self.wrb_home / "logs" / "button_log.txt"
        self.service_name = "WRB-enhanced.service"
        
    def check_service_status(self):
        """Check if the WRB service is running"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", self.service_name],
                capture_output=True,
                text=True
            )
            return result.stdout.strip() == "active"
        except Exception as e:
            print(f"Error checking service status: {e}")
            return False
    
    def get_service_info(self):
        """Get detailed service information"""
        try:
            # Get service status
            status_result = subprocess.run(
                ["systemctl", "status", self.service_name, "--no-pager"],
                capture_output=True,
                text=True
            )
            
            # Get service logs (last 20 lines)
            log_result = subprocess.run(
                ["journalctl", "-u", self.service_name, "-n", "20", "--no-pager"],
                capture_output=True,
                text=True
            )
            
            return {
                "status": status_result.stdout,
                "logs": log_result.stdout,
                "status_code": status_result.returncode
            }
        except Exception as e:
            return {"error": str(e)}
    
    def check_serial_ports(self):
        """Check for available serial ports"""
        ports = []
        common_ports = ["/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyUSB0", "/dev/ttyUSB1"]
        
        for port in common_ports:
            if os.path.exists(port):
                try:
                    # Try to get port info
                    result = subprocess.run(
                        ["udevadm", "info", "--name", port],
                        capture_output=True,
                        text=True
                    )
                    ports.append({
                        "port": port,
                        "exists": True,
                        "info": result.stdout
                    })
                except:
                    ports.append({
                        "port": port,
                        "exists": True,
                        "info": "Unable to get info"
                    })
            else:
                ports.append({
                    "port": port,
                    "exists": False
                })
        
        return ports
    
    def check_audio_system(self):
        """Check audio system status"""
        audio_status = {}
        
        try:
            # Check ALSA
            result = subprocess.run(
                ["aplay", "-l"],
                capture_output=True,
                text=True
            )
            audio_status["alsa"] = {
                "available": result.returncode == 0,
                "output": result.stdout
            }
        except:
            audio_status["alsa"] = {"available": False, "error": "Command not found"}
        
        try:
            # Check PulseAudio
            result = subprocess.run(
                ["pactl", "info"],
                capture_output=True,
                text=True
            )
            audio_status["pulseaudio"] = {
                "available": result.returncode == 0,
                "output": result.stdout
            }
        except:
            audio_status["pulseaudio"] = {"available": False, "error": "Command not found"}
        
        return audio_status
    
    def check_gpio_status(self):
        """Check GPIO status"""
        try:
            import RPi.GPIO as GPIO
            GPIO.setmode(GPIO.BCM)
            
            # Check if we can access GPIO
            GPIO.setup(23, GPIO.OUT)
            GPIO.output(23, GPIO.HIGH)
            time.sleep(0.1)
            GPIO.output(23, GPIO.LOW)
            GPIO.cleanup()
            
            return {"available": True, "test": "passed"}
        except Exception as e:
            return {"available": False, "error": str(e)}
    
    def check_sound_files(self):
        """Check for sound files"""
        sound_dirs = [
            self.wrb_home / "sounds",
            self.wrb_home / "default_sounds"
        ]
        
        sound_files = {}
        for sound_dir in sound_dirs:
            if sound_dir.exists():
                files = list(sound_dir.glob("*.wav"))
                sound_files[str(sound_dir)] = [f.name for f in files]
            else:
                sound_files[str(sound_dir)] = []
        
        return sound_files
    
    def check_usb_drives(self):
        """Check for mounted USB drives"""
        try:
            result = subprocess.run(
                ["lsblk", "-J"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                data = json.loads(result.stdout)
                usb_devices = []
                
                for device in data.get("blockdevices", []):
                    if device.get("tran") == "usb":
                        usb_devices.append({
                            "name": device.get("name"),
                            "size": device.get("size"),
                            "mountpoint": device.get("mountpoint"),
                            "label": device.get("label")
                        })
                
                return usb_devices
            else:
                return []
        except:
            return []
    
    def get_system_info(self):
        """Get general system information"""
        info = {}
        
        try:
            # CPU info
            with open("/proc/cpuinfo", "r") as f:
                cpu_info = f.read()
                if "Raspberry Pi" in cpu_info:
                    info["device"] = "Raspberry Pi"
                else:
                    info["device"] = "Unknown"
        
            # Memory info
            with open("/proc/meminfo", "r") as f:
                mem_info = f.read()
                for line in mem_info.split("\n"):
                    if "MemTotal" in line:
                        info["memory"] = line.split(":")[1].strip()
                        break
        
            # Disk usage
            result = subprocess.run(
                ["df", "-h", "/"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split("\n")
                if len(lines) > 1:
                    info["disk_usage"] = lines[1]
        
        except Exception as e:
            info["error"] = str(e)
        
        return info
    
    def generate_report(self):
        """Generate a comprehensive system report"""
        print("WRB System Monitor Report")
        print("=" * 50)
        print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Service status
        print("Service Status:")
        print("-" * 20)
        service_running = self.check_service_status()
        print(f"WRB Service: {'RUNNING' if service_running else 'STOPPED'}")
        
        if not service_running:
            print("\nService Details:")
            service_info = self.get_service_info()
            print(service_info.get("status", "Unable to get status"))
        
        print()
        
        # Serial ports
        print("Serial Ports:")
        print("-" * 20)
        ports = self.check_serial_ports()
        for port_info in ports:
            status = "AVAILABLE" if port_info["exists"] else "NOT FOUND"
            print(f"{port_info['port']}: {status}")
        
        print()
        
        # Audio system
        print("Audio System:")
        print("-" * 20)
        audio_status = self.check_audio_system()
        print(f"ALSA: {'AVAILABLE' if audio_status['alsa']['available'] else 'NOT AVAILABLE'}")
        print(f"PulseAudio: {'AVAILABLE' if audio_status['pulseaudio']['available'] else 'NOT AVAILABLE'}")
        
        print()
        
        # GPIO status
        print("GPIO Status:")
        print("-" * 20)
        gpio_status = self.check_gpio_status()
        print(f"GPIO: {'AVAILABLE' if gpio_status['available'] else 'NOT AVAILABLE'}")
        if not gpio_status['available']:
            print(f"Error: {gpio_status.get('error', 'Unknown error')}")
        
        print()
        
        # Sound files
        print("Sound Files:")
        print("-" * 20)
        sound_files = self.check_sound_files()
        for directory, files in sound_files.items():
            print(f"{directory}: {len(files)} files")
            if files:
                for file in files[:3]:  # Show first 3 files
                    print(f"  - {file}")
                if len(files) > 3:
                    print(f"  ... and {len(files) - 3} more")
        
        print()
        
        # USB drives
        print("USB Drives:")
        print("-" * 20)
        usb_drives = self.check_usb_drives()
        if usb_drives:
            for drive in usb_drives:
                print(f"{drive['name']}: {drive['size']} - {drive['mountpoint'] or 'Not mounted'}")
        else:
            print("No USB drives detected")
        
        print()
        
        # System info
        print("System Information:")
        print("-" * 20)
        system_info = self.get_system_info()
        for key, value in system_info.items():
            print(f"{key}: {value}")
        
        print()
        print("=" * 50)

def main():
    """Main function"""
    monitor = WRBMonitor()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "status":
            service_running = monitor.check_service_status()
            print("RUNNING" if service_running else "STOPPED")
        elif command == "report":
            monitor.generate_report()
        elif command == "service":
            service_info = monitor.get_service_info()
            print(service_info.get("status", "Unable to get status"))
        elif command == "ports":
            ports = monitor.check_serial_ports()
            for port_info in ports:
                if port_info["exists"]:
                    print(port_info["port"])
        elif command == "audio":
            audio_status = monitor.check_audio_system()
            print(f"ALSA: {audio_status['alsa']['available']}")
            print(f"PulseAudio: {audio_status['pulseaudio']['available']}")
        else:
            print("Unknown command. Use: status, report, service, ports, audio")
    else:
        # Default: generate full report
        monitor.generate_report()

if __name__ == "__main__":
    main()
