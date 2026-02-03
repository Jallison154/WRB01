#!/bin/bash
# Install WRB-enhanced.service and missing files from git repository
# This script pulls the latest files from the WRB01 repository and sets up the service

echo "=== WRB Installation from Git ==="
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

# Repository URL
REPO_URL="https://github.com/Jallison154/WRB01.git"
REPO_BRANCH="WRB01"
TEMP_DIR="/tmp/wrb_install_$$"

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Check internet connectivity
print_info "Checking internet connectivity..."
if ! ping -c 1 github.com >/dev/null 2>&1; then
    print_error "No internet connection detected"
    print_info "Please ensure your Raspberry Pi is connected to the internet"
    exit 1
fi
print_success "Internet connection verified"

# Clone or update repository
print_info "Fetching files from git repository..."
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

if git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" . 2>/dev/null; then
    print_success "Repository cloned"
else
    print_error "Failed to clone repository"
    print_info "Trying alternative method..."
    git clone "$REPO_URL" . 2>/dev/null
    if [ $? -eq 0 ]; then
        git checkout "$REPO_BRANCH" 2>/dev/null
        print_success "Repository cloned and branch checked out"
    else
        print_error "Failed to clone repository"
        exit 1
    fi
fi

# Check if service file exists in repo
SERVICE_FILE="Pi Zero/WRB-enhanced.service"
if [ ! -f "$SERVICE_FILE" ]; then
    print_error "Service file not found in repository: $SERVICE_FILE"
    exit 1
fi
print_success "Found service file in repository"

# Find PiScript location
print_info "Locating PiScript..."
PSCRIPT_PATHS=(
    "/home/wrb01/WRB/PiScript"
    "/home/wrb01/TheBigWRB/Pi Zero/PiScript"
    "$HOME/WRB/PiScript"
    "$HOME/TheBigWRB/Pi Zero/PiScript"
)

PSCRIPT_PATH=""
for path in "${PSCRIPT_PATHS[@]}"; do
    if [ -f "$path" ]; then
        PSCRIPT_PATH="$path"
        print_success "Found PiScript at: $path"
        break
    fi
done

if [ -z "$PSCRIPT_PATH" ]; then
    print_warning "PiScript not found in common locations"
    print_info "Please enter the full path to PiScript:"
    read -p "Path: " PSCRIPT_PATH
    
    if [ ! -f "$PSCRIPT_PATH" ]; then
        print_error "PiScript not found at: $PSCRIPT_PATH"
        print_info "You can update the service file later with:"
        print_info "  sudo nano /etc/systemd/system/WRB-enhanced.service"
        # Use default path
        PSCRIPT_PATH="/home/wrb01/WRB/PiScript"
    fi
fi

# Create service file with correct PiScript path
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
WorkingDirectory=$(dirname "$PSCRIPT_PATH")
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:1,0
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStart=/usr/bin/python3 $PSCRIPT_PATH
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

print_success "Service file created at /etc/systemd/system/WRB-enhanced.service"

# Copy missing test files if they exist in repo
print_info "Checking for missing test files..."
TEST_FILES=(
    "Pi Zero/test_esp32_connection.py"
    "Pi Zero/test_system_integration.py"
)

WRB_DIR="/home/wrb01/WRB"
if [ ! -d "$WRB_DIR" ]; then
    # Try alternative location
    if [ -d "/home/wrb01/TheBigWRB/Pi Zero" ]; then
        WRB_DIR="/home/wrb01/TheBigWRB/Pi Zero"
    else
        print_warning "WRB directory not found, skipping test file copy"
        WRB_DIR=""
    fi
fi

if [ -n "$WRB_DIR" ]; then
    for test_file in "${TEST_FILES[@]}"; do
        if [ -f "$TEMP_DIR/$test_file" ]; then
            dest_file="$WRB_DIR/$(basename "$test_file")"
            sudo cp "$TEMP_DIR/$test_file" "$dest_file"
            sudo chown wrb01:wrb01 "$dest_file"
            sudo chmod +x "$dest_file"
            print_success "Copied $(basename "$test_file") to $dest_file"
        fi
    done
fi

# Reload systemd
print_info "Reloading systemd daemon..."
sudo systemctl daemon-reload
print_success "Systemd daemon reloaded"

# Enable service
print_info "Enabling WRB-enhanced.service..."
sudo systemctl enable WRB-enhanced.service
print_success "Service enabled"

# Show service status
echo
print_info "Service configuration:"
echo "  Service file: /etc/systemd/system/WRB-enhanced.service"
echo "  PiScript path: $PSCRIPT_PATH"
echo "  Working directory: $(dirname "$PSCRIPT_PATH")"
echo

# Check service status
print_info "Checking service status..."
if systemctl is-enabled WRB-enhanced.service >/dev/null 2>&1; then
    print_success "Service is enabled"
else
    print_warning "Service may not be enabled"
fi

echo
print_success "=== Installation Complete ==="
echo
print_info "Useful commands:"
echo "  Start service:    sudo systemctl start WRB-enhanced.service"
echo "  Stop service:    sudo systemctl stop WRB-enhanced.service"
echo "  Restart service: sudo systemctl restart WRB-enhanced.service"
echo "  Check status:    sudo systemctl status WRB-enhanced.service"
echo "  View logs:        sudo journalctl -u WRB-enhanced.service -f"
echo

# Ask if user wants to start the service now
read -p "Start the service now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Starting service..."
    sudo systemctl start WRB-enhanced.service
    sleep 2
    sudo systemctl status WRB-enhanced.service --no-pager -l
fi
