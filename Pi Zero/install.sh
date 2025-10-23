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
    
    # Essential packages
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
    pip3 install --user pygame pyserial numpy RPi.GPIO
    
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
    
    # Copy default sounds if they exist
    if [ -d "$REPO_DIR/Pi Zero/default_sounds" ]; then
        cp -r "$REPO_DIR/Pi Zero/default_sounds"/* "$WRB_DEFAULT_SOUNDS/"
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
    print_step "Setting up audio system..."
    
    # Add user to audio group
    sudo usermod -a -G audio "$USER"
    
    # Configure ALSA
    if [ ! -f "$HOME/.asoundrc" ]; then
        cat > "$HOME/.asoundrc" << EOF
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
EOF
        print_info "ALSA configuration created"
    fi
    
    # Configure PulseAudio
    if [ ! -d "$HOME/.config/pulse" ]; then
        mkdir -p "$HOME/.config/pulse"
    fi
    
    # Create PulseAudio configuration
    cat > "$HOME/.config/pulse/default.pa" << EOF
#!/usr/bin/pulseaudio -nF
load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore
load-module module-augment-properties
load-module module-switch-on-port-available
load-module module-udev-detect
load-module module-alsa-sink
load-module module-alsa-source device=hw:1,0
load-module module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulse-socket
load-module module-default-device-restore
load-module module-rescue-streams
load-module module-always-sink
load-module module-suspend-on-idle
load-module module-position-event-sounds
load-module module-filter-heuristics
load-module module-filter-apply
EOF
        print_info "PulseAudio configuration created"
    fi
    
    print_success "Audio system configured"
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
    
    # Permission setup
    setup_permissions
    
    # Service setup
    create_service_file
    enable_service
    
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
