#!/usr/bin/env python3
"""
WRB Remote Diagnostics Tool
Comprehensive system diagnostics for remote troubleshooting
"""

import os
import sys
import json
import subprocess
import logging
from datetime import datetime
from pathlib import Path

class WRBDiagnostics:
    def __init__(self):
        self.wrb_home = os.path.expanduser("~/WRB")
        self.logger = logging.getLogger(__name__)
        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
        
    def get_system_info(self):
        """Get comprehensive system information"""
        info = {
            "timestamp": datetime.now().isoformat(),
            "hostname": os.uname().nodename,
            "uptime": self.get_uptime(),
            "load_average": os.getloadavg(),
            "memory": self.get_memory_info(),
            "disk": self.get_disk_info(),
            "temperature": self.get_temperature(),
            "network": self.get_network_info(),
            "services": self.get_service_status(),
            "hardware": self.get_hardware_info()
        }
        return info
        
    def get_uptime(self):
        """Get system uptime"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
                days = int(uptime_seconds // 86400)
                hours = int((uptime_seconds % 86400) // 3600)
                minutes = int((uptime_seconds % 3600) // 60)
                return f"{days}d {hours}h {minutes}m"
        except:
            return "Unknown"
            
    def get_memory_info(self):
        """Get memory information"""
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = {}
                for line in f:
                    key, value = line.split(':', 1)
                    meminfo[key.strip()] = value.strip()
                    
            total = int(meminfo['MemTotal'].split()[0]) // 1024  # MB
            free = int(meminfo['MemFree'].split()[0]) // 1024
            available = int(meminfo['MemAvailable'].split()[0]) // 1024
            
            return {
                "total_mb": total,
                "free_mb": free,
                "available_mb": available,
                "used_percent": round((total - available) / total * 100, 1)
            }
        except:
            return {"error": "Unable to get memory info"}
            
    def get_disk_info(self):
        """Get disk usage information"""
        try:
            result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                parts = lines[1].split()
                return {
                    "filesystem": parts[0],
                    "size": parts[1],
                    "used": parts[2],
                    "available": parts[3],
                    "use_percent": parts[4],
                    "mount": parts[5]
                }
        except:
            return {"error": "Unable to get disk info"}
            
    def get_temperature(self):
        """Get CPU temperature"""
        try:
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                temp = int(f.read().strip()) / 1000.0
                return f"{temp:.1f}°C"
        except:
            return "Unknown"
            
    def get_network_info(self):
        """Get network interface information"""
        try:
            result = subprocess.run(['ip', 'addr', 'show'], capture_output=True, text=True)
            interfaces = {}
            current_interface = None
            
            for line in result.stdout.split('\n'):
                if ': ' in line and not line.startswith(' '):
                    current_interface = line.split(':')[1].strip()
                    interfaces[current_interface] = {}
                elif 'inet ' in line and current_interface:
                    ip = line.strip().split()[1]
                    interfaces[current_interface]['ip'] = ip
                    
            return interfaces
        except:
            return {"error": "Unable to get network info"}
            
    def get_service_status(self):
        """Get status of WRB services"""
        services = [
            "WRB-enhanced.service",
            "wrb-watchdog.service", 
            "wrb-network-monitor.service",
            "watchdog"
        ]
        
        status = {}
        for service in services:
            try:
                result = subprocess.run(
                    ['systemctl', 'is-active', service],
                    capture_output=True, text=True, timeout=5
                )
                status[service] = result.stdout.strip()
            except:
                status[service] = "unknown"
                
        return status
        
    def get_hardware_info(self):
        """Get hardware information"""
        try:
            info = {}
            
            # CPU info
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read()
                if 'model name' in cpuinfo:
                    model_line = [line for line in cpuinfo.split('\n') if 'model name' in line][0]
                    info['cpu'] = model_line.split(':')[1].strip()
                    
            # GPU info
            with open('/proc/device-tree/model', 'r') as f:
                info['model'] = f.read().strip('\x00')
                
            return info
        except:
            return {"error": "Unable to get hardware info"}
            
    def check_wrb_files(self):
        """Check if WRB files exist and are accessible"""
        files_to_check = [
            f"{self.wrb_home}/PiScript",
            f"{self.wrb_home}/config.py",
            f"{self.wrb_home}/health_monitor.py",
            f"{self.wrb_home}/network_monitor.py",
            f"{self.wrb_home}/logs/system_status.json"
        ]
        
        file_status = {}
        for file_path in files_to_check:
            if os.path.exists(file_path):
                stat = os.stat(file_path)
                file_status[file_path] = {
                    "exists": True,
                    "size": stat.st_size,
                    "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()
                }
            else:
                file_status[file_path] = {"exists": False}
                
        return file_status
        
    def check_esp32_connection(self):
        """Check ESP32 serial connection"""
        try:
            import serial
            ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)
            ser.close()
            return {"connected": True, "port": "/dev/ttyACM0"}
        except Exception as e:
            return {"connected": False, "error": str(e)}
            
    def check_audio_system(self):
        """Check audio system"""
        try:
            import pygame
            pygame.mixer.init()
            pygame.mixer.quit()
            return {"working": True}
        except Exception as e:
            return {"working": False, "error": str(e)}
            
    def get_recent_logs(self, service_name, lines=50):
        """Get recent logs for a service"""
        try:
            result = subprocess.run(
                ['journalctl', '-u', service_name, '-n', str(lines), '--no-pager'],
                capture_output=True, text=True, timeout=30
            )
            return result.stdout
        except Exception as e:
            return f"Error getting logs: {e}"
            
    def run_full_diagnostics(self):
        """Run complete system diagnostics"""
        print("=== WRB Remote Diagnostics ===")
        print(f"Timestamp: {datetime.now().isoformat()}")
        print()
        
        # System information
        print("SYSTEM INFORMATION:")
        sys_info = self.get_system_info()
        print(f"  Hostname: {sys_info['hostname']}")
        print(f"  Uptime: {sys_info['uptime']}")
        print(f"  Load Average: {sys_info['load_average']}")
        print(f"  Temperature: {sys_info['temperature']}")
        print()
        
        # Memory and disk
        print("RESOURCE USAGE:")
        print(f"  Memory: {sys_info['memory'].get('used_percent', 'Unknown')}% used")
        print(f"  Disk: {sys_info['disk'].get('use_percent', 'Unknown')} used")
        print()
        
        # Services
        print("SERVICE STATUS:")
        for service, status in sys_info['services'].items():
            print(f"  {service}: {status}")
        print()
        
        # WRB files
        print("WRB FILES:")
        file_status = self.check_wrb_files()
        for file_path, status in file_status.items():
            if status['exists']:
                print(f"  ✓ {file_path}")
            else:
                print(f"  ✗ {file_path}")
        print()
        
        # Hardware connections
        print("HARDWARE CONNECTIONS:")
        esp32_status = self.check_esp32_connection()
        print(f"  ESP32: {'Connected' if esp32_status['connected'] else 'Not connected'}")
        
        audio_status = self.check_audio_system()
        print(f"  Audio: {'Working' if audio_status['working'] else 'Not working'}")
        print()
        
        # Recent errors
        print("RECENT ERRORS (last 20 lines):")
        for service in ["WRB-enhanced.service", "wrb-watchdog.service"]:
            logs = self.get_recent_logs(service, 20)
            error_lines = [line for line in logs.split('\n') if 'ERROR' in line or 'FAILED' in line]
            if error_lines:
                print(f"  {service}:")
                for line in error_lines[-5:]:  # Last 5 errors
                    print(f"    {line}")
        print()
        
        return sys_info
        
    def save_diagnostics_report(self, filename=None):
        """Save diagnostics report to file"""
        if filename is None:
            filename = f"{self.wrb_home}/logs/diagnostics_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            
        report = {
            "timestamp": datetime.now().isoformat(),
            "system_info": self.get_system_info(),
            "file_status": self.check_wrb_files(),
            "esp32_status": self.check_esp32_connection(),
            "audio_status": self.check_audio_system()
        }
        
        try:
            with open(filename, 'w') as f:
                json.dump(report, f, indent=2)
            print(f"Diagnostics report saved to: {filename}")
            return filename
        except Exception as e:
            print(f"Error saving report: {e}")
            return None

def main():
    diagnostics = WRBDiagnostics()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "--report":
            diagnostics.save_diagnostics_report()
        elif sys.argv[1] == "--json":
            report = diagnostics.run_full_diagnostics()
            print(json.dumps(report, indent=2))
        else:
            print("Usage: python3 remote_diagnostics.py [--report|--json]")
    else:
        diagnostics.run_full_diagnostics()

if __name__ == "__main__":
    main()
