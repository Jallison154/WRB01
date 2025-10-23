#!/bin/bash
"""
Fix for externally-managed-environment error on Raspberry Pi
This script provides multiple solutions for Python package installation issues
"""

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Python Environment Fix Script  ${NC}"
    echo -e "${BLUE}  For Externally Managed Error  ${NC}"
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

# Method 1: Install via apt (recommended)
install_via_apt() {
    print_step "Method 1: Installing Python packages via apt (recommended)"
    
    print_info "Installing required packages via apt..."
    sudo apt update
    sudo apt install -y \
        python3-pygame \
        python3-serial \
        python3-numpy \
        python3-rpi.gpio \
        python3-psutil \
        python3-pip \
        python3-venv \
        python3-full
    
    print_success "Python packages installed via apt"
    print_info "This is the recommended method for Raspberry Pi OS"
}

# Method 2: Create virtual environment
create_venv() {
    print_step "Method 2: Creating Python virtual environment"
    
    # Create virtual environment
    print_info "Creating virtual environment..."
    python3 -m venv ~/WRB/venv
    
    # Activate and install packages
    print_info "Installing packages in virtual environment..."
    source ~/WRB/venv/bin/activate
    pip install --upgrade pip
    pip install pygame pyserial numpy RPi.GPIO psutil
    
    # Create activation script
    cat > ~/WRB/activate_venv.sh << 'EOF'
#!/bin/bash
# Activate WRB virtual environment
source ~/WRB/venv/bin/activate
echo "Virtual environment activated"
echo "Run: python PiScript"
EOF
    
    chmod +x ~/WRB/activate_venv.sh
    
    print_success "Virtual environment created at ~/WRB/venv"
    print_info "To activate: source ~/WRB/activate_venv.sh"
}

# Method 3: Use --break-system-packages (not recommended)
break_system_packages() {
    print_step "Method 3: Using --break-system-packages (NOT RECOMMENDED)"
    print_warning "This method can break your system Python installation"
    print_info "Only use this if other methods don't work"
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing packages with --break-system-packages..."
        pip3 install --break-system-packages pygame pyserial numpy RPi.GPIO psutil
        print_success "Packages installed (system packages may be affected)"
    else
        print_info "Skipping --break-system-packages method"
    fi
}

# Method 4: Use --user flag with override
user_install() {
    print_step "Method 4: Using --user flag with override"
    
    print_info "Installing packages to user directory..."
    pip3 install --user --break-system-packages pygame pyserial numpy RPi.GPIO psutil
    
    print_success "Packages installed to user directory"
    print_info "This method installs packages to ~/.local/lib/python3.x/site-packages"
}

# Test installation
test_installation() {
    print_step "Testing Python package installation..."
    
    # Test imports
    python3 -c "
import pygame
import serial
import numpy
try:
    import RPi.GPIO as GPIO
    print('✓ RPi.GPIO imported successfully')
except ImportError:
    print('✗ RPi.GPIO not available (normal on non-Pi systems)')
import psutil
print('✓ All packages imported successfully')
"
    
    if [ $? -eq 0 ]; then
        print_success "Python packages are working correctly"
    else
        print_error "Some packages failed to import"
        return 1
    fi
}

# Main menu
show_menu() {
    echo "Choose a method to fix the externally-managed-environment error:"
    echo
    echo "1) Install via apt (RECOMMENDED)"
    echo "2) Create virtual environment"
    echo "3) Use --break-system-packages (NOT RECOMMENDED)"
    echo "4) Use --user flag with override"
    echo "5) Test current installation"
    echo "6) Exit"
    echo
}

# Main function
main() {
    print_header
    check_root
    
    while true; do
        show_menu
        read -p "Enter your choice (1-6): " choice
        
        case $choice in
            1)
                install_via_apt
                test_installation
                break
                ;;
            2)
                create_venv
                test_installation
                break
                ;;
            3)
                break_system_packages
                test_installation
                break
                ;;
            4)
                user_install
                test_installation
                break
                ;;
            5)
                test_installation
                ;;
            6)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1-6."
                ;;
        esac
    done
    
    echo
    print_success "Python environment fix completed!"
    print_info "You can now run the WRB system"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Python Environment Fix Script"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --apt          Install via apt (recommended)"
        echo "  --venv         Create virtual environment"
        echo "  --user         Install to user directory"
        echo "  --test         Test current installation"
        echo
        exit 0
        ;;
    --apt)
        print_header
        check_root
        install_via_apt
        test_installation
        ;;
    --venv)
        print_header
        check_root
        create_venv
        test_installation
        ;;
    --user)
        print_header
        check_root
        user_install
        test_installation
        ;;
    --test)
        print_header
        test_installation
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        print_info "Use --help for usage information"
        exit 1
        ;;
esac
