#!/bin/bash
# Diagnostic script for WRB01 installation issues

echo "=== WRB01 Installation Diagnostics ==="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1"
        return 1
    fi
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo "1. Checking Internet Connectivity..."
ping -c 1 google.com >/dev/null 2>&1
check "Internet connection"

echo
echo "2. Checking User Permissions..."
if [ "$EUID" -eq 0 ]; then
    warn "Running as root - script should be run as regular user"
else
    check "Not running as root"
fi

echo
echo "3. Checking Required Packages..."
packages=("python3" "python3-pygame" "python3-serial" "python3-gpiozero" "alsa-utils" "git")
for pkg in "${packages[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg "; then
        check "$pkg installed"
    else
        warn "$pkg NOT installed"
    fi
done

echo
echo "4. Checking wrb01 User..."
if id "wrb01" &>/dev/null; then
    check "wrb01 user exists"
    groups=$(groups wrb01)
    if echo "$groups" | grep -q "audio"; then
        check "wrb01 in audio group"
    else
        warn "wrb01 NOT in audio group"
    fi
    if echo "$groups" | grep -q "gpio"; then
        check "wrb01 in gpio group"
    else
        warn "wrb01 NOT in gpio group"
    fi
    if echo "$groups" | grep -q "dialout"; then
        check "wrb01 in dialout group"
    else
        warn "wrb01 NOT in dialout group"
    fi
else
    warn "wrb01 user does NOT exist"
fi

echo
echo "5. Checking Audio Devices..."
if command -v aplay >/dev/null 2>&1; then
    aplay -l 2>/dev/null | head -5
    info "Audio devices listed above"
else
    warn "aplay command not found"
fi

echo
echo "6. Checking Serial Ports..."
if [ -e /dev/ttyACM0 ]; then
    check "/dev/ttyACM0 exists"
    ls -l /dev/ttyACM0
else
    warn "/dev/ttyACM0 does NOT exist"
fi

if [ -e /dev/ttyACM1 ]; then
    check "/dev/ttyACM1 exists"
    ls -l /dev/ttyACM1
fi

echo
echo "7. Checking Service Status..."
if systemctl list-unit-files | grep -q "wrb-simple.service"; then
    check "wrb-simple.service exists"
    if systemctl is-active --quiet wrb-simple.service; then
        check "wrb-simple.service is running"
    else
        warn "wrb-simple.service is NOT running"
        echo "Recent service logs:"
        sudo journalctl -u wrb-simple.service -n 20 --no-pager
    fi
else
    warn "wrb-simple.service does NOT exist"
fi

echo
echo "8. Checking Installation Files..."
files=(
    "/home/wrb01/simple_audio_player.py"
    "/home/wrb01/audio"
    "/etc/systemd/system/wrb-simple.service"
)
for file in "${files[@]}"; do
    if [ -e "$file" ]; then
        check "$file exists"
    else
        warn "$file does NOT exist"
    fi
done

echo
echo "9. Checking Audio Files..."
if [ -d "/home/wrb01/audio" ]; then
    audio_files=$(ls /home/wrb01/audio/*.wav 2>/dev/null | wc -l)
    if [ "$audio_files" -gt 0 ]; then
        check "$audio_files audio file(s) found"
        ls -1 /home/wrb01/audio/*.wav 2>/dev/null | head -5
    else
        warn "No audio files found in /home/wrb01/audio"
    fi
fi

echo
echo "10. Checking Python Dependencies..."
if python3 -c "import pygame" 2>/dev/null; then
    check "pygame module available"
else
    warn "pygame module NOT available"
fi

if python3 -c "import serial" 2>/dev/null; then
    check "serial module available"
else
    warn "serial module NOT available"
fi

if python3 -c "from gpiozero import LED" 2>/dev/null; then
    check "gpiozero module available"
else
    warn "gpiozero module NOT available"
fi

echo
echo "11. Checking Disk Space..."
df -h / | tail -1
info "Disk space shown above"

echo
echo "12. Checking Repository Access..."
if ping -c 1 github.com >/dev/null 2>&1; then
    check "GitHub is reachable"
else
    warn "GitHub is NOT reachable"
fi

echo
echo "=== Diagnostic Complete ==="
echo
echo "Common Fixes:"
echo "1. If packages missing: sudo apt update && sudo apt install -y python3-pygame python3-serial python3-gpiozero alsa-utils git"
echo "2. If user missing: sudo useradd -m -s /bin/bash wrb01 && sudo usermod -a -G audio,gpio,dialout wrb01"
echo "3. If service not running: sudo systemctl status wrb-simple.service"
echo "4. If audio issues: aplay -l (check audio devices)"
echo "5. If serial issues: ls -l /dev/ttyACM* (check ESP32 connection)"
