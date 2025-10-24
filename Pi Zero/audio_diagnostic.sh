#!/bin/bash
# Audio Diagnostic Script for WRB01
# Helps troubleshoot USB audio card issues

echo "=== WRB01 Audio Diagnostic ==="
echo "=============================="
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root"
    print_info "Please run as a regular user (pi or wrb01)"
    exit 1
fi

echo "🔍 DIAGNOSING AUDIO SETUP..."
echo

# 1. Check ALSA devices
print_step "1. Checking ALSA audio devices..."
echo "Available audio cards:"
aplay -l 2>/dev/null || echo "No audio devices found"
echo

# 2. Check USB audio specifically
print_step "2. Checking USB audio devices..."
echo "USB audio devices:"
lsusb | grep -i audio || echo "No USB audio devices found"
echo

# 3. Check current ALSA configuration
print_step "3. Checking current ALSA configuration..."
if [ -f "/etc/asound.conf" ]; then
    echo "Current /etc/asound.conf:"
    cat /etc/asound.conf
else
    echo "No /etc/asound.conf found"
fi
echo

# 4. Test audio output
print_step "4. Testing audio output..."
echo "Testing built-in audio (card 0):"
if aplay -D plughw:0,0 /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    print_success "✓ Built-in audio works"
else
    print_error "✗ Built-in audio failed"
fi

echo "Testing USB audio (card 1):"
if aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    print_success "✓ USB audio works"
else
    print_error "✗ USB audio failed"
fi

echo "Testing default audio:"
if aplay -D default /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    print_success "✓ Default audio works"
else
    print_error "✗ Default audio failed"
fi
echo

# 5. Check Python audio environment
print_step "5. Checking Python audio environment..."
echo "Testing Python audio with different devices:"
python3 -c "
import os
import pygame

# Test built-in audio
os.environ['SDL_AUDIODRIVER'] = 'alsa'
os.environ['AUDIODEV'] = 'plughw:0,0'
try:
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=256)
    print('✓ Python built-in audio works')
    pygame.mixer.quit()
except Exception as e:
    print(f'✗ Python built-in audio failed: {e}')

# Test USB audio
os.environ['AUDIODEV'] = 'plughw:1,0'
try:
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=256)
    print('✓ Python USB audio works')
    pygame.mixer.quit()
except Exception as e:
    print(f'✗ Python USB audio failed: {e}')

# Test default audio
os.environ['AUDIODEV'] = 'default'
try:
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=256)
    print('✓ Python default audio works')
    pygame.mixer.quit()
except Exception as e:
    print(f'✗ Python default audio failed: {e}')
"
echo

# 6. Check service status
print_step "6. Checking WRB service status..."
if systemctl is-active --quiet wrb-simple.service; then
    print_success "✓ WRB service is running"
    echo "Service logs (last 10 lines):"
    sudo journalctl -u wrb-simple.service -n 10 --no-pager
else
    print_error "✗ WRB service is not running"
    echo "Service status:"
    sudo systemctl status wrb-simple.service --no-pager
fi
echo

# 7. Recommendations
print_step "7. Recommendations..."
echo "Based on the diagnostic results:"
echo

# Check if USB audio is working
if aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null; then
    print_success "USB audio is working - configuration should be correct"
    echo "If you're still not getting audio, check:"
    echo "  - USB audio card volume levels"
    echo "  - Physical connections"
    echo "  - Service logs: sudo journalctl -u wrb-simple.service -f"
else
    print_warning "USB audio is not working - trying fallback configuration"
    echo "Recommendations:"
    echo "  1. Check USB audio card is properly connected"
    echo "  2. Try different USB port"
    echo "  3. Check if USB audio card is recognized: lsusb"
    echo "  4. Try built-in audio as fallback"
fi

echo
print_info "=== DIAGNOSTIC COMPLETE ==="
print_info "Run this script again after making changes to verify fixes"
