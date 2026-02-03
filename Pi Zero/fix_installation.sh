#!/bin/bash
# Fix installation issues for WRB-enhanced.service

echo "=== Fixing WRB Installation ==="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root"
    print_info "Please run as a regular user (wrb01)"
    exit 1
fi

# Check if PiScript exists
if [ ! -f "/home/wrb01/WRB/PiScript" ]; then
    print_error "PiScript not found at /home/wrb01/WRB/PiScript"
    print_info "Please check the path. Common locations:"
    print_info "  - /home/wrb01/WRB/PiScript"
    print_info "  - /home/wrb01/TheBigWRB/Pi Zero/PiScript"
    read -p "Enter the full path to PiScript (or press Enter to skip): " pscript_path
    
    if [ -z "$pscript_path" ]; then
        print_warning "Skipping service creation. Please create WRB-enhanced.service manually."
        exit 1
    fi
    
    if [ ! -f "$pscript_path" ]; then
        print_error "File not found: $pscript_path"
        exit 1
    fi
    
    # Update service file with correct path
    SERVICE_PATH="/home/wrb01/WRB/PiScript"
    print_info "Using PiScript at: $pscript_path"
else
    SERVICE_PATH="/home/wrb01/WRB/PiScript"
    print_success "Found PiScript at $SERVICE_PATH"
fi

# Create service file
print_info "Creating WRB-enhanced.service..."

sudo tee /etc/systemd/system/WRB-enhanced.service > /dev/null << EOF
[Unit]
Description=WRB Enhanced Audio System
After=local-fs.target network-online.target
Wants=network-online.target
DefaultDependencies=no

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01/WRB
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:1,0
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStart=/usr/bin/python3 $SERVICE_PATH
Restart=on-failure
RestartSec=5
TimeoutStartSec=30
TimeoutStopSec=10
StandardOutput=journal
StandardError=journal

# High priority for faster response
Nice=-10
IOSchedulingClass=1
IOSchedulingPriority=4

[Install]
WantedBy=multi-user.target
EOF

print_success "Service file created"

# Reload systemd
print_info "Reloading systemd daemon..."
sudo systemctl daemon-reload
print_success "Systemd daemon reloaded"

# Enable service
print_info "Enabling WRB-enhanced.service..."
sudo systemctl enable WRB-enhanced.service
print_success "Service enabled"

# Check if service file is correct
if [ -f "/etc/systemd/system/WRB-enhanced.service" ]; then
    print_success "Service file exists"
    
    # Show service status
    echo
    print_info "Service status:"
    sudo systemctl status WRB-enhanced.service --no-pager -l
    
    echo
    print_info "To start the service, run:"
    echo "  sudo systemctl start WRB-enhanced.service"
    echo
    print_info "To view logs, run:"
    echo "  sudo journalctl -u WRB-enhanced.service -f"
else
    print_error "Service file was not created"
    exit 1
fi

echo
print_success "=== Installation Fix Complete ==="
