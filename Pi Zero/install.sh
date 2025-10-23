#!/bin/bash
# WRB Enhanced Audio System - One-Command Installation Script
# Raspberry Pi ESP32 Wireless Button System
# 
# This script provides a complete one-command installation for the WRB system.
# It handles all dependencies, configuration, and service setup automatically.

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
WRB_HOME="$HOME/WRB"
WRB_LOG_DIR="$WRB_HOME/logs"
WRB_SOUNDS_DIR="$WRB_HOME/sounds"
WRB_DEFAULT_SOUNDS="$WRB_HOME/default_sounds"

# Service configuration
SERVICE_NAME="WRB-enhanced.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

# Repository information
REPO_URL="https://github.com/Jallison154/WRB01.git"
BRANCH_UPDATE="WRB01"
BRANCH_MAIN="main"
REPO_DIR="$HOME/WRB01"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  WRB Enhanced Audio System     ${NC}"
    echo -e "${BLUE}  Installation Script v1.0      ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        print_info "Please run as a regular user (pi)"
        exit 1
    fi
}

# Check if running on Raspberry Pi
check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_warning "This script is designed for Raspberry Pi"
        print_info "Continuing anyway..."
    fi
}

# Check internet connectivity
check_internet() {
    print_step "Checking internet connectivity..."
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        print_error "No internet connection detected"
        print_info "Please ensure your Raspberry Pi is connected to the internet"
        exit 1
    fi
    print_success "Internet connection verified"
}

# =============================================================================
# SYSTEM UPDATE FUNCTIONS
# =============================================================================

update_system() {
    print_step "Updating system packages..."
    sudo apt update -y
    sudo apt upgrade -y
    print_success "System packages updated"
}

install_dependencies() {
    print_step "Installing required packages..."
    
    # Essential packages - optimized for Pi Zero W
    PACKAGES=(
        "python3"
        "python3-pip"
        "python3-dev"
        "python3-pygame"
        "python3-serial"
        "python3-numpy"
        "git"
        "curl"
        "wget"
        "unzip"
        "alsa-utils"
        "pulseaudio"
        "pulseaudio-utils"
        "libasound2-dev"
        "portaudio19-dev"
        "python3-setuptools"
        "python3-wheel"
        "sox"
        "libsox-fmt-all"
        "pavucontrol"
        "python3-rpi.gpio"
    )
    
    for package in "${PACKAGES[@]}"; do
        print_info "Installing $package..."
        sudo apt install -y "$package"
    done
    
    print_success "All packages installed successfully"
}

install_python_packages() {
    print_step "Installing Python packages..."
    
    # Install Python packages via pip
    pip3 install --user --upgrade pip
    pip3 install --user pygame pyserial numpy RPi.GPIO psutil
    
    print_success "Python packages installed successfully"
}

# =============================================================================
# REPOSITORY FUNCTIONS
# =============================================================================

clone_repository() {
    print_step "Cloning WRB repository..."
    
    # Remove existing repository if it exists
    if [ -d "$REPO_DIR" ]; then
        print_info "Removing existing repository..."
        rm -rf "$REPO_DIR"
    fi
    
    # Try to clone WRB01 branch first
    print_info "Attempting to clone WRB01 branch..."
    if git clone -b "$BRANCH_UPDATE" "$REPO_URL" "$REPO_DIR" 2>/dev/null; then
        print_success "Successfully cloned WRB01 branch"
    else
        print_warning "WRB01 branch not available, trying main branch..."
        if git clone -b "$BRANCH_MAIN" "$REPO_URL" "$REPO_DIR" 2>/dev/null; then
            print_success "Successfully cloned main branch"
        else
            print_error "Failed to clone repository"
            exit 1
        fi
    fi
}

# =============================================================================
# DIRECTORY SETUP FUNCTIONS
# =============================================================================

create_directories() {
    print_step "Creating WRB directories..."
    
    # Create main directories
    mkdir -p "$WRB_HOME"
    mkdir -p "$WRB_LOG_DIR"
    mkdir -p "$WRB_SOUNDS_DIR"
    mkdir -p "$WRB_DEFAULT_SOUNDS"
    
    print_success "Directories created successfully"
}

copy_files() {
    print_step "Copying WRB files..."
    
    # Copy main files
    cp "$REPO_DIR/Pi Zero/PiScript" "$WRB_HOME/"
    cp "$REPO_DIR/Pi Zero/config.py" "$WRB_HOME/"
    
    # Copy new audio testing and setup files
    if [ -f "$REPO_DIR/Pi Zero/test_audio.py" ]; then
        cp "$REPO_DIR/Pi Zero/test_audio.py" "$WRB_HOME/"
        print_info "Audio test script copied"
    fi
    
    if [ -f "$REPO_DIR/Pi Zero/setup_audio.sh" ]; then
        cp "$REPO_DIR/Pi Zero/setup_audio.sh" "$WRB_HOME/"
        chmod +x "$WRB_HOME/setup_audio.sh"
        print_info "Audio setup script copied"
    fi
    
    # Copy default sounds if they exist
    if [ -d "$REPO_DIR/Pi Zero/Default Sounds" ]; then
        cp -r "$REPO_DIR/Pi Zero/Default Sounds"/* "$WRB_DEFAULT_SOUNDS/"
        print_info "Default sounds copied"
    fi
    
    # Make scripts executable
    chmod +x "$WRB_HOME/PiScript"
    
    print_success "Files copied successfully"
}

# =============================================================================
# AUDIO SETUP FUNCTIONS
# =============================================================================

setup_audio() {
    print_step "Setting up audio system for Pi Zero W..."
    
    # Add user to audio groups
    sudo usermod -a -G audio,pulse,pulse-access "$USER"
    
    # Configure PulseAudio for Pi Zero W
    print_info "Configuring PulseAudio..."
    mkdir -p ~/.config/pulse
    cat > ~/.config/pulse/daemon.conf << EOF
# PulseAudio daemon configuration for Pi Zero W
default-sample-rate = 44100
default-sample-format = s16le
default-sample-channels = 2
default-fragments = 4
default-fragment-size-msec = 25
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 9
rlimit-rt = 9
daemonize = no
avoid-resampling = yes
EOF
    
    # Configure ALSA with fallback support
    print_info "Configuring ALSA..."
    sudo tee /etc/asound.conf > /dev/null << EOF
# ALSA configuration for Pi Zero W
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}

# USB audio support
pcm.usb {
    type hw
    card 1
    device 0
}

ctl.usb {
    type hw
    card 1
}

# HDMI audio support
pcm.hdmi {
    type hw
    card 0
    device 0
}

ctl.hdmi {
    type hw
    card 0
}
EOF
    
    # Enable PulseAudio user service
    print_info "Enabling PulseAudio user service..."
    systemctl --user enable pulseaudio
    systemctl --user start pulseaudio
    
    # Configure HDMI audio if using HDMI display
    print_info "Configuring HDMI audio..."
    if [ -f /boot/config.txt ]; then
        # Enable HDMI audio
        if ! grep -q "hdmi_drive=2" /boot/config.txt; then
            echo "hdmi_drive=2" | sudo tee -a /boot/config.txt
        fi
        
        # Disable audio jack (if using HDMI)
        if ! grep -q "dtparam=audio=off" /boot/config.txt; then
            echo "dtparam=audio=off" | sudo tee -a /boot/config.txt
        fi
    fi
    
    # Set up audio environment variables
    print_info "Setting up audio environment..."
    cat >> ~/.bashrc << 'EOF'

# WRB Audio Environment Variables
export SDL_AUDIODRIVER=pulse
export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
export AUDIODEV=plughw:0,0
EOF
    
    print_success "Audio system configured for Pi Zero W"
}

test_audio_system() {
    print_step "Testing audio system..."
    
    # Run audio test if available
    if [ -f "$WRB_HOME/test_audio.py" ]; then
        print_info "Running comprehensive audio test..."
        if python3 "$WRB_HOME/test_audio.py"; then
            print_success "Audio system test passed"
        else
            print_warning "Audio system test failed - audio may not work properly"
            print_info "You can run the test manually later: python3 $WRB_HOME/test_audio.py"
        fi
    else
        print_info "Audio test script not available, skipping test"
    fi
    
    # Test basic audio commands
    print_info "Testing basic audio commands..."
    if command -v aplay >/dev/null 2>&1; then
        print_info "ALSA audio tools available"
    else
        print_warning "ALSA audio tools not available"
    fi
    
    if command -v pactl >/dev/null 2>&1; then
        print_info "PulseAudio tools available"
    else
        print_warning "PulseAudio tools not available"
    fi
}

copy_default_sounds() {
    print_step "Copying default sound files..."
    
    # Copy existing default sound files from repository
    if [ -d "$REPO_DIR/Pi Zero/Default Sounds" ]; then
        print_info "Copying default sounds from repository..."
        cp -r "$REPO_DIR/Pi Zero/Default Sounds"/* "$WRB_DEFAULT_SOUNDS/"
        print_success "Default sound files copied successfully"
        
        # List copied files
        print_info "Default sound files:"
        ls -la "$WRB_DEFAULT_SOUNDS"/*.wav 2>/dev/null | while read line; do
            print_info "  $line"
        done
    else
        print_warning "Default sounds directory not found in repository"
        print_info "No default sounds will be available"
    fi
}

# =============================================================================
# PERMISSION SETUP FUNCTIONS
# =============================================================================

setup_permissions() {
    print_step "Setting up permissions..."
    
    # Add user to necessary groups
    sudo usermod -a -G audio,gpio,dialout "$USER"
    
    # Set permissions for WRB directory
    chmod -R 755 "$WRB_HOME"
    
    # Make sure PiScript is executable
    chmod +x "$WRB_HOME/PiScript"
    
    print_success "Permissions configured"
}

# =============================================================================
# SYSTEMD SERVICE FUNCTIONS
# =============================================================================

create_service_file() {
    print_step "Creating systemd service file..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=WRB Enhanced Audio System
After=network.target sound.target
Wants=network.target sound.target
StartLimitInterval=300
StartLimitBurst=3

[Service]
Type=simple
User=$USER
Group=audio
WorkingDirectory=$WRB_HOME
Environment=HOME=$HOME
Environment=USER=$USER
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=pulse
Environment=PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
ExecStart=/usr/bin/python3 $WRB_HOME/PiScript
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=1
StandardOutput=journal
StandardError=journal
TimeoutStartSec=30
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Service file created"
}

enable_service() {
    print_step "Enabling WRB service..."
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    # Enable the service
    sudo systemctl enable "$SERVICE_NAME"
    
    print_success "Service enabled successfully"
}

start_service() {
    print_step "Starting WRB service..."
    
    # Start the service
    sudo systemctl start "$SERVICE_NAME"
    
    # Wait a moment and check status
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_warning "Service may not have started properly"
        print_info "Check service status with: sudo systemctl status $SERVICE_NAME"
    fi
}

# =============================================================================
# RELIABILITY AND STABILITY FUNCTIONS
# =============================================================================

setup_watchdog() {
    print_step "Setting up hardware watchdog..."
    
    # Enable hardware watchdog
    if [ -f "/dev/watchdog" ]; then
        # Install watchdog package
        sudo apt install -y watchdog
        
        # Configure watchdog
        cat > /etc/watchdog.conf << EOF
# Watchdog configuration for WRB system
watchdog-device = /dev/watchdog
watchdog-timeout = 60
max-load-1 = 5
max-load-5 = 3
max-load-15 = 2
min-memory = 1
admin = root
interval = 10
logtick = 1
temperature-sensor = /sys/class/thermal/thermal_zone0/temp
max-temperature = 85
EOF
        
        # Enable and start watchdog service
        sudo systemctl enable watchdog
        sudo systemctl start watchdog
        
        print_success "Hardware watchdog configured"
    else
        print_warning "Hardware watchdog not available, using software monitoring"
    fi
}

create_health_monitor() {
    print_step "Creating health monitoring script..."
    
    cat > "$WRB_HOME/health_monitor.py" << 'EOF'
#!/usr/bin/env python3
"""
WRB Health Monitor - Comprehensive system health monitoring
Designed for remote devices with no physical access
"""

import os
import sys
import time
import json
import logging
import subprocess
import psutil
import serial
import pygame
from datetime import datetime, timedelta
from pathlib import Path

class WRBHealthMonitor:
    def __init__(self):
        self.wrb_home = os.path.expanduser("~/WRB")
        self.log_file = f"{self.wrb_home}/logs/health_monitor.log"
        self.status_file = f"{self.wrb_home}/logs/system_status.json"
        self.alert_file = f"{self.wrb_home}/logs/alerts.log"
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
        # Health thresholds
        self.cpu_threshold = 80.0
        self.memory_threshold = 85.0
        self.disk_threshold = 90.0
        self.temp_threshold = 80.0
        
        # Service monitoring
        self.service_name = "WRB-enhanced.service"
        self.max_restart_attempts = 5
        self.restart_cooldown = 300  # 5 minutes
        
    def check_system_resources(self):
        """Check CPU, memory, disk, and temperature"""
        health_status = {
            "cpu_percent": psutil.cpu_percent(interval=1),
            "memory_percent": psutil.virtual_memory().percent,
            "disk_percent": psutil.disk_usage('/').percent,
            "temperature": self.get_cpu_temperature(),
            "timestamp": datetime.now().isoformat()
        }
        
        issues = []
        
        # Check CPU usage
        if health_status["cpu_percent"] > self.cpu_threshold:
            issues.append(f"High CPU usage: {health_status['cpu_percent']:.1f}%")
            
        # Check memory usage
        if health_status["memory_percent"] > self.memory_threshold:
            issues.append(f"High memory usage: {health_status['memory_percent']:.1f}%")
            
        # Check disk usage
        if health_status["disk_percent"] > self.disk_threshold:
            issues.append(f"High disk usage: {health_status['disk_percent']:.1f}%")
            
        # Check temperature
        if health_status["temperature"] > self.temp_threshold:
            issues.append(f"High temperature: {health_status['temperature']:.1f}°C")
            
        health_status["issues"] = issues
        health_status["healthy"] = len(issues) == 0
        
        return health_status
        
    def get_cpu_temperature(self):
        """Get CPU temperature"""
        try:
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                temp = int(f.read().strip()) / 1000.0
                return temp
        except:
            return 0.0
            
    def check_service_status(self):
        """Check if WRB service is running"""
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', self.service_name],
                capture_output=True, text=True, timeout=10
            )
            return result.stdout.strip() == 'active'
        except:
            return False
            
    def check_serial_connection(self):
        """Check ESP32 serial connection"""
        try:
            # Try to open serial connection
            ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)
            ser.close()
            return True
        except:
            return False
            
    def check_audio_system(self):
        """Check audio system functionality"""
        try:
            pygame.mixer.init()
            pygame.mixer.quit()
            return True
        except:
            return False
            
    def restart_service(self):
        """Restart the WRB service"""
        try:
            self.logger.warning("Restarting WRB service...")
            subprocess.run(['sudo', 'systemctl', 'restart', self.service_name], 
                         timeout=30, check=True)
            time.sleep(10)  # Wait for service to start
            return self.check_service_status()
        except Exception as e:
            self.logger.error(f"Failed to restart service: {e}")
            return False
            
    def cleanup_logs(self):
        """Clean up old log files to prevent disk space issues"""
        try:
            log_dir = Path(f"{self.wrb_home}/logs")
            cutoff_date = datetime.now() - timedelta(days=7)
            
            for log_file in log_dir.glob("*.log"):
                if log_file.stat().st_mtime < cutoff_date.timestamp():
                    log_file.unlink()
                    self.logger.info(f"Removed old log file: {log_file}")
                    
        except Exception as e:
            self.logger.error(f"Log cleanup failed: {e}")
            
    def save_status(self, status):
        """Save system status to JSON file"""
        try:
            with open(self.status_file, 'w') as f:
                json.dump(status, f, indent=2)
        except Exception as e:
            self.logger.error(f"Failed to save status: {e}")
            
    def send_alert(self, message):
        """Send alert (log for now, could be extended to email/webhook)"""
        try:
            with open(self.alert_file, 'a') as f:
                f.write(f"{datetime.now().isoformat()} - ALERT: {message}\n")
            self.logger.warning(f"ALERT: {message}")
        except Exception as e:
            self.logger.error(f"Failed to send alert: {e}")
            
    def run_health_check(self):
        """Run comprehensive health check"""
        self.logger.info("Starting health check...")
        
        # System resources
        system_health = self.check_system_resources()
        
        # Service status
        service_running = self.check_service_status()
        
        # Hardware checks
        serial_ok = self.check_serial_connection()
        audio_ok = self.check_audio_system()
        
        # Compile overall status
        status = {
            "timestamp": datetime.now().isoformat(),
            "system_health": system_health,
            "service_running": service_running,
            "serial_connection": serial_ok,
            "audio_system": audio_ok,
            "overall_healthy": system_health["healthy"] and service_running and serial_ok and audio_ok
        }
        
        # Handle issues
        if not status["overall_healthy"]:
            issues = []
            if not system_health["healthy"]:
                issues.extend(system_health["issues"])
            if not service_running:
                issues.append("WRB service not running")
            if not serial_ok:
                issues.append("ESP32 serial connection failed")
            if not audio_ok:
                issues.append("Audio system not working")
                
            self.send_alert(f"System health issues detected: {', '.join(issues)}")
            
            # Attempt service restart if service is down
            if not service_running:
                self.restart_service()
                
        # Save status
        self.save_status(status)
        
        # Cleanup old logs
        self.cleanup_logs()
        
        self.logger.info("Health check completed")
        return status

def main():
    monitor = WRBHealthMonitor()
    while True:
        try:
            monitor.run_health_check()
            time.sleep(60)  # Check every minute
        except KeyboardInterrupt:
            break
        except Exception as e:
            monitor.logger.error(f"Health monitor error: {e}")
            time.sleep(60)

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "$WRB_HOME/health_monitor.py"
    print_success "Health monitoring script created"
}

create_watchdog_service() {
    print_step "Creating watchdog service..."
    
    cat > "/etc/systemd/system/wrb-watchdog.service" << EOF
[Unit]
Description=WRB System Watchdog
After=network.target WRB-enhanced.service
Wants=network.target

[Service]
Type=simple
User=$USER
Group=audio
WorkingDirectory=$WRB_HOME
Environment=HOME=$HOME
Environment=USER=$USER
ExecStart=/usr/bin/python3 $WRB_HOME/health_monitor.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable watchdog service
    sudo systemctl daemon-reload
    sudo systemctl enable wrb-watchdog.service
    
    print_success "Watchdog service created and enabled"
}

setup_log_rotation() {
    print_step "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/wrb" << EOF
$WRB_HOME/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        systemctl reload WRB-enhanced.service > /dev/null 2>&1 || true
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

setup_network_monitoring() {
    print_step "Setting up network monitoring..."
    
    cat > "$WRB_HOME/network_monitor.py" << 'EOF'
#!/usr/bin/env python3
"""
Network connectivity monitor for WRB system
"""

import time
import subprocess
import logging
from datetime import datetime

class NetworkMonitor:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.test_hosts = ['8.8.8.8', '1.1.1.1', 'google.com']
        self.max_failures = 3
        self.failure_count = 0
        
    def test_connectivity(self):
        """Test network connectivity"""
        for host in self.test_hosts:
            try:
                result = subprocess.run(
                    ['ping', '-c', '1', '-W', '5', host],
                    capture_output=True, timeout=10
                )
                if result.returncode == 0:
                    return True
            except:
                continue
        return False
        
    def restart_networking(self):
        """Restart networking services"""
        try:
            self.logger.warning("Restarting networking services...")
            subprocess.run(['sudo', 'systemctl', 'restart', 'networking'], 
                         timeout=60, check=True)
            subprocess.run(['sudo', 'systemctl', 'restart', 'dhcpcd'], 
                         timeout=60, check=True)
            return True
        except Exception as e:
            self.logger.error(f"Failed to restart networking: {e}")
            return False
            
    def monitor(self):
        """Main monitoring loop"""
        while True:
            if self.test_connectivity():
                if self.failure_count > 0:
                    self.logger.info("Network connectivity restored")
                    self.failure_count = 0
            else:
                self.failure_count += 1
                self.logger.warning(f"Network connectivity lost (failure {self.failure_count})")
                
                if self.failure_count >= self.max_failures:
                    self.restart_networking()
                    self.failure_count = 0
                    
            time.sleep(30)  # Check every 30 seconds

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    monitor = NetworkMonitor()
    monitor.monitor()
EOF
    
    chmod +x "$WRB_HOME/network_monitor.py"
    
    # Create network monitor service
    cat > "/etc/systemd/system/wrb-network-monitor.service" << EOF
[Unit]
Description=WRB Network Monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/python3 $WRB_HOME/network_monitor.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable wrb-network-monitor.service
    
    print_success "Network monitoring configured"
}

# =============================================================================
# VERIFICATION FUNCTIONS
# =============================================================================

verify_installation() {
    print_step "Verifying installation..."
    
    local errors=0
    
    # Check if files exist
    if [ ! -f "$WRB_HOME/PiScript" ]; then
        print_error "PiScript not found"
        ((errors++))
    fi
    
    if [ ! -f "$WRB_HOME/config.py" ]; then
        print_error "config.py not found"
        ((errors++))
    fi
    
    if [ ! -f "$WRB_HOME/test_audio.py" ]; then
        print_error "Audio test script not found"
        ((errors++))
    fi
    
    if [ ! -f "$WRB_HOME/setup_audio.sh" ]; then
        print_error "Audio setup script not found"
        ((errors++))
    fi
    
    if [ ! -d "$WRB_DEFAULT_SOUNDS" ]; then
        print_error "Default sounds directory not found"
        ((errors++))
    fi
    
    # Check if service exists
    if [ ! -f "$SERVICE_FILE" ]; then
        print_error "Service file not found"
        ((errors++))
    fi
    
    # Check service status
    if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_error "Service not enabled"
        ((errors++))
    fi
    
    # Check reliability systems
    if [ ! -f "$WRB_HOME/health_monitor.py" ]; then
        print_error "Health monitor not found"
        ((errors++))
    fi
    
    if [ ! -f "/etc/systemd/system/wrb-watchdog.service" ]; then
        print_error "Watchdog service not found"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "Installation verification passed"
        return 0
    else
        print_error "Installation verification failed ($errors errors)"
        return 1
    fi
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

cleanup_installation() {
    print_step "Cleaning up installation files..."
    
    # Remove repository directory
    if [ -d "$REPO_DIR" ]; then
        rm -rf "$REPO_DIR"
        print_info "Repository directory removed"
    fi
    
    print_success "Cleanup completed"
}

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

main_installation() {
    print_header
    
    # Pre-installation checks
    check_root
    check_raspberry_pi
    check_internet
    
    # System preparation
    update_system
    install_dependencies
    install_python_packages
    
    # Repository setup
    clone_repository
    
    # Directory and file setup
    create_directories
    copy_files
    
    # Audio setup
    setup_audio
    copy_default_sounds
    test_audio_system
    
    # Permission setup
    setup_permissions
    
    # Reliability and stability setup
    setup_watchdog
    create_health_monitor
    create_watchdog_service
    setup_log_rotation
    setup_network_monitoring
    
    # Service setup
    create_service_file
    enable_service
    
    # Start reliability services
    print_step "Starting reliability services..."
    sudo systemctl start wrb-watchdog.service
    sudo systemctl start wrb-network-monitor.service
    print_success "Reliability services started"
    
    # Cleanup
    cleanup_installation
    
    # Verification
    if verify_installation; then
        print_success "WRB Enhanced Audio System installed successfully!"
        echo
        print_info "The system will start automatically on boot"
        print_info "To start the service now, run: sudo systemctl start $SERVICE_NAME"
        print_info "To check service status, run: sudo systemctl status $SERVICE_NAME"
        print_info "To view logs, run: sudo journalctl -u $SERVICE_NAME -f"
        echo
        print_info "=== RELIABILITY FEATURES ENABLED ==="
        print_info "✓ Hardware watchdog monitoring"
        print_info "✓ Health monitoring (CPU, memory, disk, temperature)"
        print_info "✓ Automatic service restart on failure"
        print_info "✓ Network connectivity monitoring"
        print_info "✓ Log rotation to prevent disk space issues"
        print_info "✓ ESP32 serial connection monitoring"
        print_info "✓ Audio system health checks"
        print_info "✓ Pi Zero W optimized audio system"
        print_info "✓ PulseAudio and ALSA support"
        print_info "✓ USB and HDMI audio support"
        print_info "✓ Comprehensive audio testing"
        echo
        print_info "System status available at: $WRB_HOME/logs/system_status.json"
        print_info "Health monitor logs: $WRB_HOME/logs/health_monitor.log"
        print_info "Alert logs: $WRB_HOME/logs/alerts.log"
        echo
        print_info "For troubleshooting, see the documentation in $WRB_HOME"
    else
        print_error "Installation completed with errors"
        print_info "Please check the error messages above and fix any issues"
        exit 1
    fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "WRB Enhanced Audio System Installation Script"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Show version information"
        echo "  --verify       Verify installation without installing"
        echo
        exit 0
        ;;
    --version|-v)
        echo "WRB Enhanced Audio System Installation Script v1.0"
        exit 0
        ;;
    --verify)
        print_header
        verify_installation
        exit $?
        ;;
    "")
        main_installation
        ;;
    *)
        print_error "Unknown option: $1"
        print_info "Use --help for usage information"
        exit 1
        ;;
esac
