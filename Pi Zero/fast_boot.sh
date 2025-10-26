#!/bin/bash
# Fast Boot Optimizations for WRB01
# Apply aggressive boot speed optimizations

echo "=== WRB01 Fast Boot Optimizations ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "Applying aggressive boot speed optimizations..."

# 1. Disable network wait services (MAJOR impact)
echo "1. Disabling network wait services..."
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask NetworkManager-wait-online.service 2>/dev/null || true
systemctl mask wait-online.service 2>/dev/null || true
echo "   ✓ Network wait services disabled"

# 2. Disable unnecessary services
echo "2. Disabling unnecessary services..."
systemctl disable avahi-daemon.service 2>/dev/null || true
systemctl disable triggerhappy.service 2>/dev/null || true
systemctl disable ModemManager.service 2>/dev/null || true
systemctl disable dphys-swapfile.service 2>/dev/null || true
systemctl disable rpi-eeprom-update.service 2>/dev/null || true
echo "   ✓ Unnecessary services disabled"

# 3. Optimize /boot/config.txt
echo "3. Optimizing /boot/config.txt..."
if [ -f /boot/config.txt ]; then
    # Disable splash
    if ! grep -q "disable_splash=1" /boot/config.txt; then
        echo "disable_splash=1" >> /boot/config.txt
    fi
    # Faster CPU
    if ! grep -q "arm_freq=1200" /boot/config.txt; then
        echo "arm_freq=1200" >> /boot/config.txt
    fi
fi
echo "   ✓ config.txt optimized"

# 4. Optimize systemd timeouts
echo "4. Optimizing systemd timeouts..."
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/20-wrb-fast.conf << 'EOF'
[Manager]
DefaultTimeoutStartSec=3s
DefaultTimeoutStopSec=2s
DefaultRestartSec=0.5s
EOF
echo "   ✓ systemd timeouts optimized"

# 5. Optimize WRB service
echo "5. Optimizing WRB service..."
cat > /etc/systemd/system/wrb-simple.service << 'EOF'
[Unit]
Description=WRB Simple Audio Player
After=local-fs.target
DefaultDependencies=no

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:1,0
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStart=/usr/bin/python3 /home/wrb01/simple_audio_player.py
Restart=on-failure
RestartSec=0.5
TimeoutStartSec=3
TimeoutStopSec=2
Nice=-10
IOSchedulingClass=1
IOSchedulingPriority=4
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
echo "   ✓ WRB service optimized"

# 6. Pre-compile Python modules for faster startup
echo "6. Pre-compiling Python modules..."
python3 -m py_compile /home/wrb01/simple_audio_player.py 2>/dev/null || true
echo "   ✓ Python modules pre-compiled"

echo
echo "=== Optimization Complete ==="
echo
echo "Expected results:"
echo "  - Boot time: 10-15 seconds (down from 60s)"
echo "  - Service ready: ~12-18 seconds"
echo
echo "To apply changes, reboot:"
echo "  sudo reboot"
echo
echo "After reboot, check boot time:"
echo "  systemd-analyze"
echo "  systemd-analyze critical-chain wrb-simple.service"
echo
