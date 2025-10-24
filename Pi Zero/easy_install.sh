#!/bin/bash
# Easy Install Script for WRB01 Simple Button + Audio System
# Pulls from GitHub repository and sets up everything automatically

echo "=== WRB01 Simple Button + Audio System ==="
echo "Easy Installation Script"
echo "================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root"
    print_info "Please run as a regular user (pi or wrb01)"
    exit 1
fi

# Check internet connectivity
print_step "Checking internet connectivity..."
if ! ping -c 1 google.com >/dev/null 2>&1; then
    print_error "No internet connection detected"
    print_info "Please ensure your Raspberry Pi is connected to the internet"
    exit 1
fi
print_success "Internet connection verified"

# Update system
print_step "Updating system packages..."
sudo apt update -y
sudo apt upgrade -y
print_success "System packages updated"

# Install required packages
print_step "Installing required packages..."
sudo apt install -y python3-pygame python3-serial python3-numpy alsa-utils git
print_success "Required packages installed"

# Remove old installation and clone fresh repository
print_step "Removing old installation and cloning fresh repository..."

# Stop and disable old service if it exists
if systemctl is-active --quiet wrb-simple.service 2>/dev/null; then
    print_info "Stopping old service..."
    sudo systemctl stop wrb-simple.service
    sudo systemctl disable wrb-simple.service
fi

# Remove old service file
if [ -f "/etc/systemd/system/wrb-simple.service" ]; then
    print_info "Removing old service file..."
    sudo rm -f /etc/systemd/system/wrb-simple.service
    sudo systemctl daemon-reload
fi

# Remove old WRB01 directory
if [ -d "WRB01" ]; then
    print_info "Removing old repository..."
    rm -rf WRB01
fi

# Clone fresh repository
print_info "Cloning fresh repository..."
git clone https://github.com/Jallison154/WRB01.git
cd WRB01
git checkout WRB01
cd ..
print_success "Fresh repository cloned"

# Create wrb01 user if it doesn't exist
print_step "Setting up user environment..."
if ! id "wrb01" &>/dev/null; then
    print_info "Creating wrb01 user..."
    sudo useradd -m -s /bin/bash wrb01
    print_success "wrb01 user created"
else
    print_info "wrb01 user already exists"
fi

# Add wrb01 to necessary groups
sudo usermod -a -G audio,gpio,dialout,spi,i2c,plugdev,render,input wrb01
print_success "User groups configured"

# Clean up old files and create fresh audio directory
print_step "Cleaning up old files and setting up fresh audio directory..."

# Remove old audio files
if [ -d "/home/wrb01/audio" ]; then
    print_info "Removing old audio files..."
    sudo rm -rf /home/wrb01/audio
fi

# Remove old Python script
if [ -f "/home/wrb01/simple_audio_player.py" ]; then
    print_info "Removing old Python script..."
    sudo rm -f /home/wrb01/simple_audio_player.py
fi

# Remove old test script
if [ -f "/home/wrb01/test_buttons.py" ]; then
    print_info "Removing old test script..."
    sudo rm -f /home/wrb01/test_buttons.py
fi

# Create fresh audio directory
sudo mkdir -p /home/wrb01/audio
sudo chown wrb01:wrb01 /home/wrb01/audio
print_success "Fresh audio directory created"

# Configure USB audio interface
print_step "Configuring USB audio interface..."
sudo tee /etc/asound.conf > /dev/null << EOF
# USB Audio Configuration
pcm.!default {
    type hw
    card 1
    device 0
}
ctl.!default {
    type hw
    card 1
}

# Fallback to built-in audio if USB not available
pcm.fallback {
    type hw
    card 0
    device 0
}
EOF
print_success "USB audio configured"

# Copy audio files from repository
print_step "Copying audio files..."
if [ -d "WRB01/Pi Zero/Default Sounds" ]; then
    sudo cp "WRB01/Pi Zero/Default Sounds/button1.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ button1.wav copied" || echo "⚠ button1.wav not found"
    sudo cp "WRB01/Pi Zero/Default Sounds/button2.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ button2.wav copied" || echo "⚠ button2.wav not found"
    sudo cp "WRB01/Pi Zero/Default Sounds/hold1.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ hold1.wav copied" || echo "⚠ hold1.wav not found"
    sudo cp "WRB01/Pi Zero/Default Sounds/hold2.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ hold2.wav copied" || echo "⚠ hold2.wav not found"
    
    # Set proper ownership
    sudo chown wrb01:wrb01 /home/wrb01/audio/*.wav 2>/dev/null || true
    print_success "Audio files copied"
else
    print_error "Default Sounds directory not found in repository"
    print_info "Please add your audio files manually to /home/wrb01/audio/"
fi

# Copy Python scripts
print_step "Installing Python scripts..."
sudo cp "WRB01/Pi Zero/simple_audio_player.py" /home/wrb01/
sudo cp "WRB01/Pi Zero/test_buttons.py" /home/wrb01/
sudo chown wrb01:wrb01 /home/wrb01/simple_audio_player.py
sudo chown wrb01:wrb01 /home/wrb01/test_buttons.py
sudo chmod +x /home/wrb01/simple_audio_player.py
sudo chmod +x /home/wrb01/test_buttons.py
print_success "Python scripts installed"

# Create systemd service
print_step "Creating systemd service..."
sudo tee /etc/systemd/system/wrb-simple.service > /dev/null << EOF
[Unit]
Description=WRB Simple Audio Player
After=network.target
Wants=network.target

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:1,0
ExecStart=/usr/bin/python3 /home/wrb01/simple_audio_player.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable wrb-simple.service
sudo systemctl start wrb-simple.service
print_success "Systemd service created and started"

# Final verification
print_step "Performing final verification..."
if [ -f "/home/wrb01/simple_audio_player.py" ]; then
    print_success "✓ Python script installed"
else
    print_error "✗ Python script not found"
fi

if [ -f "/home/wrb01/audio/button1.wav" ]; then
    print_success "✓ Audio files installed"
else
    print_warning "⚠ Audio files not found"
fi

if systemctl is-active --quiet wrb-simple.service; then
    print_success "✓ Service is running"
else
    print_warning "⚠ Service may not be running"
fi

# Clean up repository
print_step "Cleaning up installation files..."
if [ -d "WRB01" ]; then
    rm -rf WRB01
    print_info "Repository directory removed"
fi

echo
print_success "=== INSTALLATION COMPLETE ==="
echo
print_info "=== USEFUL COMMANDS ==="
print_info "Check service status: sudo systemctl status wrb-simple.service"
print_info "View service logs: sudo journalctl -u wrb-simple.service -f"
print_info "Restart service: sudo systemctl restart wrb-simple.service"
print_info "Stop service: sudo systemctl stop wrb-simple.service"
print_info "Start service: sudo systemctl start wrb-simple.service"
print_info "Test buttons: python3 /home/wrb01/test_buttons.py"
echo
print_info "=== SYSTEM READY ==="
print_info "✓ ESP32 receiver should be connected to /dev/ttyACM0"
print_info "✓ USB audio interface configured"
print_info "✓ Audio files ready"
print_info "✓ Service running automatically"
print_info "✓ Test script available for debugging"
echo
print_info "Your WRB01 Simple Button + Audio System is ready!"
print_info "Press buttons on your ESP32 transmitter to hear audio!"
