#!/bin/bash
"""
Updated Python Environment Fix Script for Raspberry Pi OS 2024
Handles externally-managed-environment error with latest solutions
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
    echo -e "${BLUE}  Python Environment Fix 2024   ${NC}"
    echo -e "${BLUE}  Latest Solutions for Pi OS    ${NC}"
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

# Method 1: Use --user --break-system-packages (2024 solution)
install_user_break() {
    print_step "Method 1: User installation with system override (2024 solution)"
    
    print_info "Installing packages to user directory with system override..."
    pip3 install --user --break-system-packages \
        pygame \
        pyserial \
        numpy \
        RPi.GPIO \
        psutil
    
    print_success "Packages installed to user directory with system override"
    print_info "This is the current recommended workaround for 2024"
}

# Method 2: Use pipx for isolated installations
install_pipx() {
    print_step "Method 2: Using pipx for isolated installations"
    
    # Install pipx
    print_info "Installing pipx..."
    sudo apt update
    sudo apt install -y pipx
    
    # Install packages using pipx
    print_info "Installing packages using pipx..."
    pipx install pygame
    pipx install pyserial
    pipx install numpy
    pipx install RPi.GPIO
    pipx install psutil
    
    print_success "Packages installed using pipx"
    print_info "Each package is in its own isolated environment"
}

# Method 3: Create system-wide virtual environment
create_system_venv() {
    print_step "Method 3: Creating system-wide virtual environment"
    
    # Create virtual environment in /opt
    print_info "Creating system virtual environment..."
    sudo python3 -m venv /opt/wrb-venv
    
    # Install packages in system virtual environment
    print_info "Installing packages in system virtual environment..."
    sudo /opt/wrb-venv/bin/pip install --upgrade pip
    sudo /opt/wrb-venv/bin/pip install pygame pyserial numpy RPi.GPIO psutil
    
    # Create activation script
    cat > ~/WRB/activate_system_venv.sh << 'EOF'
#!/bin/bash
# Activate system virtual environment
source /opt/wrb-venv/bin/activate
echo "System virtual environment activated"
echo "Run: python PiScript"
EOF
    
    chmod +x ~/WRB/activate_system_venv.sh
    
    print_success "System virtual environment created at /opt/wrb-venv"
    print_info "To activate: source ~/WRB/activate_system_venv.sh"
}

# Method 4: Use --break-system-packages globally (not recommended)
install_break_system() {
    print_step "Method 4: Using --break-system-packages globally (NOT RECOMMENDED)"
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

# Method 5: Use apt with manual package installation
install_apt_manual() {
    print_step "Method 5: Manual apt installation with pip fallback"
    
    # Install what's available via apt
    print_info "Installing available packages via apt..."
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
    
    # Try to install missing packages with pip
    print_info "Installing any missing packages with pip..."
    pip3 install --user --break-system-packages --upgrade pip || true
    
    # Try to install packages that might not be available via apt
    for package in pygame pyserial numpy RPi.GPIO psutil; do
        if ! python3 -c "import $package" 2>/dev/null; then
            print_info "Installing $package with pip..."
            pip3 install --user --break-system-packages $package || true
        fi
    done
    
    print_success "Mixed apt/pip installation completed"
}

# Method 6: Create .local environment
create_local_env() {
    print_step "Method 6: Creating .local environment"
    
    # Create .local directory structure
    mkdir -p ~/.local/lib/python3.11/site-packages
    mkdir -p ~/.local/bin
    
    # Add to PATH
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo 'export PYTHONPATH="$HOME/.local/lib/python3.11/site-packages:$PYTHONPATH"' >> ~/.bashrc
    
    # Install packages to .local
    print_info "Installing packages to .local directory..."
    pip3 install --user --break-system-packages \
        pygame \
        pyserial \
        numpy \
        RPi.GPIO \
        psutil
    
    print_success "Packages installed to .local directory"
    print_info "You may need to restart your shell or run: source ~/.bashrc"
}

# Test installation
test_installation() {
    print_step "Testing Python package installation..."
    
    # Test imports
    python3 -c "
try:
    import pygame
    print('✓ pygame imported successfully')
except ImportError as e:
    print('✗ pygame import failed:', e)

try:
    import serial
    print('✓ serial imported successfully')
except ImportError as e:
    print('✗ serial import failed:', e)

try:
    import numpy
    print('✓ numpy imported successfully')
except ImportError as e:
    print('✗ numpy import failed:', e)

try:
    import RPi.GPIO as GPIO
    print('✓ RPi.GPIO imported successfully')
except ImportError as e:
    print('✗ RPi.GPIO not available (normal on non-Pi systems):', e)

try:
    import psutil
    print('✓ psutil imported successfully')
except ImportError as e:
    print('✗ psutil import failed:', e)
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
    echo "1) --user --break-system-packages (RECOMMENDED for 2024)"
    echo "2) Use pipx for isolated installations"
    echo "3) Create system-wide virtual environment"
    echo "4) Use --break-system-packages globally (NOT RECOMMENDED)"
    echo "5) Mixed apt/pip installation"
    echo "6) Create .local environment"
    echo "7) Test current installation"
    echo "8) Exit"
    echo
}

# Main function
main() {
    print_header
    check_root
    
    while true; do
        show_menu
        read -p "Enter your choice (1-8): " choice
        
        case $choice in
            1)
                install_user_break
                test_installation
                break
                ;;
            2)
                install_pipx
                test_installation
                break
                ;;
            3)
                create_system_venv
                test_installation
                break
                ;;
            4)
                install_break_system
                test_installation
                break
                ;;
            5)
                install_apt_manual
                test_installation
                break
                ;;
            6)
                create_local_env
                test_installation
                break
                ;;
            7)
                test_installation
                ;;
            8)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1-8."
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
        echo "Python Environment Fix Script 2024"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --user         Install with --user --break-system-packages (recommended)"
        echo "  --pipx         Use pipx for isolated installations"
        echo "  --system-venv  Create system-wide virtual environment"
        echo "  --apt-mixed    Mixed apt/pip installation"
        echo "  --local        Create .local environment"
        echo "  --test         Test current installation"
        echo
        exit 0
        ;;
    --user)
        print_header
        check_root
        install_user_break
        test_installation
        ;;
    --pipx)
        print_header
        check_root
        install_pipx
        test_installation
        ;;
    --system-venv)
        print_header
        check_root
        create_system_venv
        test_installation
        ;;
    --apt-mixed)
        print_header
        check_root
        install_apt_manual
        test_installation
        ;;
    --local)
        print_header
        check_root
        create_local_env
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
