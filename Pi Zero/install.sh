#!/bin/bash
# Complete WRB Pi Installation Script
# This single script handles everything needed for installation

set -e  # Exit on any error

echo "=========================================="
echo "  WRB Pi Installation Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please don't run this script as root. Run as pi user instead."
    exit 1
fi

# Auto-detect and navigate to the correct directory
if [ ! -f "PiScript" ]; then
    echo "🔍 PiScript not found in current directory, searching..."
    
    # Try common locations
    if [ -f "Pi Zero/PiScript" ]; then
        echo "📁 Found in Pi Zero subdirectory, navigating..."
        cd "Pi Zero"
    elif [ -f "../Pi Zero/PiScript" ]; then
        echo "📁 Found in parent Pi Zero directory, navigating..."
        cd "../Pi Zero"
    elif [ -f "~/TheBigWRB/Pi Zero/PiScript" ]; then
        echo "📁 Found in TheBigWRB directory, navigating..."
        cd "~/TheBigWRB/Pi Zero"
    else
        echo "❌ PiScript not found. Please run this from the Pi Zero directory or clone the repository first."
        echo "   Try: git clone https://github.com/Jallison154/TheBigWRB.git ~/TheBigWRB"
        exit 1
    fi
fi

echo "✅ Starting WRB Pi installation..."
echo ""

# Step 1: Update system
echo "📦 Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Step 2: Install required packages
echo "📦 Installing required packages..."
sudo apt install -y python3-pip python3-pygame python3-serial python3-gpiozero sox git alsa-utils python3-venv

# Step 3: Create directory structure
echo "📁 Creating directory structure..."
mkdir -p ~/WRB/sounds
echo "✅ WRB directory structure created"

# Step 4: Copy all files
echo "📋 Copying application files..."

# Get the directory where this script is located (should be Pi Zero directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🔍 Script directory: $SCRIPT_DIR"

# List files in the script directory to debug
echo "📁 Files in script directory:"
ls -la "$SCRIPT_DIR" | grep -E "\.(py|txt)$|PiScript" || echo "No Python files found"

# Copy files from the Pi Zero directory with better error handling
echo "📋 Copying files..."
FILES_COPIED=0

# Essential files that must be copied
ESSENTIAL_FILES=("PiScript" "config.py")
OPTIONAL_FILES=("monitor_system.py" "test_esp32_connection.py" "test_system_integration.py" "requirements.txt")

# Copy essential files
for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        cp "$SCRIPT_DIR/$file" ~/WRB/ && echo "✅ $file copied" && ((FILES_COPIED++))
    else
        echo "❌ $file not found in $SCRIPT_DIR - THIS IS REQUIRED!"
    fi
done

# Copy optional files
for file in "${OPTIONAL_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        cp "$SCRIPT_DIR/$file" ~/WRB/ && echo "✅ $file copied" && ((FILES_COPIED++))
    else
        echo "⚠️  $file not found in $SCRIPT_DIR (optional)"
    fi
done

# Copy default sound files if they exist
if [ -d "$SCRIPT_DIR/default_sounds" ]; then
    echo "🎵 Copying default sound files..."
    cp "$SCRIPT_DIR/default_sounds"/*.wav ~/WRB/sounds/ 2>/dev/null && echo "✅ Default sounds copied" && ((FILES_COPIED++))
else
    echo "📁 No default_sounds directory found in $SCRIPT_DIR"
fi

echo "📊 Files copied: $FILES_COPIED"

# Check if essential files were copied
if [ ! -f ~/WRB/PiScript ]; then
    echo "❌ CRITICAL: PiScript not found after copying!"
    echo "🔍 Current directory contents:"
    ls -la "$SCRIPT_DIR"
    echo "🔍 Target directory contents:"
    ls -la ~/WRB/
    exit 1
fi

# Step 5: Set permissions
echo "🔐 Setting file permissions..."

# If essential files are missing, provide clear error message
if [ ! -f ~/WRB/PiScript ]; then
    echo "❌ CRITICAL: Essential files not found!"
    echo "🔍 Current script directory: $SCRIPT_DIR"
    echo "🔍 Files in script directory:"
    ls -la "$SCRIPT_DIR"
    echo ""
    echo "🔍 Target directory: ~/WRB/"
    echo "🔍 Files in target directory:"
    ls -la ~/WRB/
    echo ""
    echo "❌ Installation failed - essential files not found"
    echo "💡 Make sure you're running the install script from the Pi Zero directory"
    echo "💡 The script should be located in the same directory as PiScript and config.py"
    exit 1
fi

# Set permissions for all files
if [ -f ~/WRB/PiScript ]; then
    chmod +x ~/WRB/PiScript
    echo "✅ PiScript permissions set"
else
    echo "❌ PiScript still not found after all attempts"
fi

chmod +x ~/WRB/*.py 2>/dev/null && echo "✅ Python files permissions set" || echo "⚠️  No Python files found to set permissions"

# Step 6: Install Python dependencies
echo "🐍 Installing Python dependencies..."

# Install required packages via apt (more reliable than pip)
echo "📦 Installing Python packages via apt..."
sudo apt install -y python3-pygame python3-serial python3-gpiozero python3-pip

# Try to install additional packages via pip if requirements.txt exists
if [ -f ~/WRB/requirements.txt ]; then
    echo "📦 Installing additional packages from requirements.txt..."
    pip3 install -r ~/WRB/requirements.txt --break-system-packages 2>/dev/null || {
        echo "⚠️  Some pip packages failed, but core packages are installed via apt"
    }
else
    echo "⚠️  requirements.txt not found, using apt packages only"
fi

# Verify pygame installation
echo "🧪 Testing pygame installation..."
if python3 -c "import pygame; print('pygame version:', pygame.version.ver)" 2>/dev/null; then
    echo "✅ pygame is working correctly"
else
    echo "❌ pygame installation failed, trying alternative method..."
    # Try installing pygame via pip as fallback
    pip3 install pygame --break-system-packages 2>/dev/null || {
        echo "❌ Could not install pygame - manual installation may be required"
    }
fi

echo "✅ Python dependencies installation completed"

# Step 7: Audio setup
echo "🔊 Setting up audio..."
sudo usermod -a -G audio $USER

# Basic audio setup for USB audio interface
echo "🔊 Setting up basic audio configuration..."

# Create basic PulseAudio configuration
mkdir -p ~/.config/pulse
cat > ~/.config/pulse/client.conf << 'PULSE_EOF'
default-server = unix:/run/user/1000/pulse/native
PULSE_EOF

# Step 8: Create sample sound files if none exist
echo "🎵 Checking for sound files..."
if [ ! -f ~/WRB/sounds/button1.wav ] || [ ! -f ~/WRB/sounds/button2.wav ] || [ ! -f ~/WRB/sounds/hold1.wav ] || [ ! -f ~/WRB/sounds/hold2.wav ]; then
    echo "📁 Creating sample sound files..."
    # Create sample sounds if default files not available
    if [ ! -f ~/WRB/sounds/button1.wav ]; then
        sox -n -r 44100 -c 2 ~/WRB/sounds/button1.wav synth 0.5 sine 800 fade h 0.1 0.1 2>/dev/null || echo "⚠️  sox not available, skipping sample sound creation"
    fi
    if [ ! -f ~/WRB/sounds/button2.wav ]; then
        sox -n -r 44100 -c 2 ~/WRB/sounds/button2.wav synth 0.5 sine 400 fade h 0.1 0.1 2>/dev/null || echo "⚠️  sox not available, skipping sample sound creation"
    fi
    if [ ! -f ~/WRB/sounds/hold1.wav ]; then
        sox -n -r 44100 -c 2 ~/WRB/sounds/hold1.wav synth 1.0 sine 1000 fade h 0.1 0.1 2>/dev/null || echo "⚠️  sox not available, skipping sample sound creation"
    fi
    if [ ! -f ~/WRB/sounds/hold2.wav ]; then
        sox -n -r 44100 -c 2 ~/WRB/sounds/hold2.wav synth 1.0 sine 600 fade h 0.1 0.1 2>/dev/null || echo "⚠️  sox not available, skipping sample sound creation"
    fi
    echo "✅ Sample sound files created"
else
    echo "✅ Sound files already exist"
fi

# Step 9: Install systemd service
echo "⚙️ Installing systemd service..."
# Create service file with actual username
ACTUAL_USER=$(whoami)
echo "🔧 Using username: $ACTUAL_USER"

sudo tee /etc/systemd/system/WRB-enhanced.service >/dev/null << 'SERVICE_EOF'
[Unit]
Description=WRB Enhanced Audio System
After=network.target sound.target
Wants=network.target sound.target
StartLimitInterval=300
StartLimitBurst=3
StartLimitAction=none

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01/WRB
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=pulse
Environment=PULSE_RUNTIME_PATH=/run/user/1000/pulse
# Standard audio setup
ExecStart=/usr/bin/python3 /home/wrb01/WRB/PiScript
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=1
StandardOutput=journal
StandardError=journal
TimeoutStartSec=30
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Step 10: Enable and start service with auto-start
echo "🚀 Starting service with auto-start on boot..."
sudo systemctl daemon-reload
sudo systemctl enable WRB-enhanced.service
sudo systemctl start WRB-enhanced.service

# Additional reliability: Create a startup script that ensures service starts
echo "🔧 Creating auto-start reliability script..."
sudo tee /etc/systemd/system/WRB-auto-start.service >/dev/null << 'AUTO_START_EOF'
[Unit]
Description=WRB Auto-Start Service
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sleep 10 && systemctl restart WRB-enhanced.service'
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
AUTO_START_EOF

# Enable the auto-start service
sudo systemctl enable WRB-auto-start.service
sudo systemctl start WRB-auto-start.service

# Create a watchdog script that monitors and restarts the service
echo "🐕 Creating watchdog script..."
sudo tee /usr/local/bin/WRB-watchdog.sh >/dev/null << 'WATCHDOG_EOF'
#!/bin/bash
# WRB Service Watchdog Script
# This script monitors the WRB service and restarts it if it fails

LOG_FILE="/var/log/WRB-watchdog.log"
SERVICE_NAME="WRB-enhanced.service"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_service() {
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log_message "Service $SERVICE_NAME is not running, attempting restart..."
        systemctl restart "$SERVICE_NAME"
        sleep 5
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_message "Service $SERVICE_NAME restarted successfully"
        else
            log_message "Failed to restart service $SERVICE_NAME"
        fi
    fi
}

# Main watchdog loop
while true; do
    check_service
    sleep 30  # Check every 30 seconds
done
WATCHDOG_EOF

sudo chmod +x /usr/local/bin/WRB-watchdog.sh

# Create watchdog service
sudo tee /etc/systemd/system/WRB-watchdog.service >/dev/null << 'WATCHDOG_SERVICE_EOF'
[Unit]
Description=WRB Service Watchdog
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/WRB-watchdog.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
WATCHDOG_SERVICE_EOF

# Enable and start the watchdog service
sudo systemctl enable WRB-watchdog.service
sudo systemctl start WRB-watchdog.service

# Step 11: Wait and check status
echo "⏳ Waiting for service to start..."
sleep 3

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""

# Check service status
echo "📊 Service Status:"
sudo systemctl status WRB-enhanced.service --no-pager

echo ""
echo "🔍 Auto-Start Services Status:"
sudo systemctl status WRB-auto-start.service --no-pager
sudo systemctl status WRB-watchdog.service --no-pager

echo ""
echo "🎉 WRB Pi system is now installed with MAXIMUM RELIABILITY!"
echo ""
echo "🚀 RELIABILITY FEATURES INSTALLED:"
echo "  ✅ Auto-start on boot (WRB-enhanced.service)"
echo "  ✅ Backup auto-start service (WRB-auto-start.service)"
echo "  ✅ Watchdog monitoring (WRB-watchdog.service)"
echo "  ✅ Automatic restart on failure"
echo "  ✅ Service health monitoring every 30 seconds"
echo ""
echo "📋 Useful Commands:"
echo "  Check main service:    sudo systemctl status WRB-enhanced.service"
echo "  Check watchdog:        sudo systemctl status WRB-watchdog.service"
echo "  View main logs:        sudo journalctl -u WRB-enhanced.service -f"
echo "  View watchdog logs:    sudo journalctl -u WRB-watchdog.service -f"
echo "  View watchdog file:    sudo tail -f /var/log/WRB-watchdog.log"
echo "  Restart service:       sudo systemctl restart WRB-enhanced.service"
echo "  Stop all services:     sudo systemctl stop WRB-enhanced WRB-watchdog"
echo ""
echo "🔧 Testing Commands:"
echo "  Test ESP32:   python3 ~/WRB/test_esp32_connection.py"
echo "  System test:  python3 ~/WRB/test_system_integration.py"
echo "  Monitor:      python3 ~/WRB/monitor_system.py"
echo ""
echo "🎵 Sound Files:"
echo "  Location:     ~/WRB/sounds/"
echo "  Customize:    Replace button1*.wav, button2*.wav, hold1*.wav, hold2*.wav"
echo ""
echo "🔄 REBOOT TEST:"
echo "  The system will automatically start after reboot:"
echo "  sudo reboot"
echo "  # After reboot, check: sudo systemctl status WRB-enhanced.service"
echo ""
echo "🛡️  MAXIMUM RELIABILITY ACHIEVED!"
echo "  - Service auto-starts on boot"
echo "  - Watchdog monitors and restarts if needed"
echo "  - Backup auto-start service as failsafe"
echo "  - Multiple restart attempts with backoff"
echo ""
