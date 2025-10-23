#!/bin/bash
"""
WRB Audio Setup Script for Pi Zero W
Configures audio system for optimal performance
"""

set -e

echo "=== WRB Audio Setup for Pi Zero W ==="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as a regular user (not root)"
    exit 1
fi

# Update system packages
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install required audio packages
echo "Installing audio packages..."
sudo apt install -y \
    alsa-utils \
    pulseaudio \
    pulseaudio-utils \
    python3-pygame \
    python3-numpy \
    python3-serial \
    python3-rpi.gpio

# Install additional audio tools
sudo apt install -y \
    sox \
    libsox-fmt-all \
    pavucontrol

# Configure ALSA for Pi Zero W
echo "Configuring ALSA..."
sudo tee /etc/asound.conf > /dev/null <<EOF
# ALSA configuration for Pi Zero W
pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}

# USB audio support
pcm.usb {
    type hw
    card 1
    device 0
}

ctl.usb {
    type hw
    card 1
}
EOF

# Configure PulseAudio for Pi Zero W
echo "Configuring PulseAudio..."
mkdir -p ~/.config/pulse
cat > ~/.config/pulse/daemon.conf <<EOF
# PulseAudio daemon configuration for Pi Zero W
default-sample-rate = 44100
default-sample-format = s16le
default-sample-channels = 2
default-fragments = 4
default-fragment-size-msec = 25
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 9
rlimit-rt = 9
daemonize = no
EOF

# Configure systemd user service for PulseAudio
echo "Configuring PulseAudio user service..."
systemctl --user enable pulseaudio
systemctl --user start pulseaudio

# Set up audio groups
echo "Adding user to audio groups..."
sudo usermod -a -G audio $USER
sudo usermod -a -G pulse $USER
sudo usermod -a -G pulse-access $USER

# Configure HDMI audio (if using HDMI display)
echo "Configuring HDMI audio..."
if [ -f /boot/config.txt ]; then
    # Enable HDMI audio
    if ! grep -q "hdmi_drive=2" /boot/config.txt; then
        echo "hdmi_drive=2" | sudo tee -a /boot/config.txt
    fi
    
    # Disable audio jack (if using HDMI)
    if ! grep -q "dtparam=audio=off" /boot/config.txt; then
        echo "dtparam=audio=off" | sudo tee -a /boot/config.txt
    fi
fi

# Create audio test script
echo "Creating audio test script..."
cat > ~/test_audio.sh <<'EOF'
#!/bin/bash
echo "=== Audio System Test ==="

echo "Testing ALSA devices..."
aplay -l

echo "Testing PulseAudio..."
pactl info

echo "Testing audio output..."
speaker-test -c2 -t wav -l1

echo "Audio test complete!"
EOF

chmod +x ~/test_audio.sh

# Create audio optimization script
echo "Creating audio optimization script..."
cat > ~/optimize_audio.sh <<'EOF'
#!/bin/bash
echo "=== Audio Optimization for Pi Zero W ==="

# Set audio thread priority
echo "Setting audio thread priority..."
sudo tee /etc/security/limits.d/audio.conf > /dev/null <<'LIMITS'
@audio   -  rtprio     95
@audio   -  memlock    unlimited
LIMITS

# Optimize PulseAudio for Pi Zero W
echo "Optimizing PulseAudio..."
cat > ~/.config/pulse/daemon.conf <<'PAEOF'
# Optimized PulseAudio configuration for Pi Zero W
default-sample-rate = 44100
default-sample-format = s16le
default-sample-channels = 2
default-fragments = 4
default-fragment-size-msec = 25
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 9
rlimit-rt = 9
daemonize = no
avoid-resampling = yes
PAEOF

echo "Audio optimization complete!"
EOF

chmod +x ~/optimize_audio.sh

# Set up audio environment variables
echo "Setting up audio environment..."
cat >> ~/.bashrc <<'EOF'

# WRB Audio Environment Variables
export SDL_AUDIODRIVER=pulse
export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
export AUDIODEV=plughw:0,0
EOF

# Create systemd service for audio optimization
echo "Creating audio optimization service..."
sudo tee /etc/systemd/system/wrb-audio-optimize.service > /dev/null <<EOF
[Unit]
Description=WRB Audio Optimization
After=pulseaudio.service

[Service]
Type=oneshot
User=$USER
ExecStart=/home/$USER/optimize_audio.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable wrb-audio-optimize.service

echo "=== Audio Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Reboot your Pi Zero W: sudo reboot"
echo "2. Test audio: ~/test_audio.sh"
echo "3. Run the WRB system: python3 PiScript"
echo ""
echo "If you have audio issues:"
echo "- Check HDMI connection and enable HDMI audio"
echo "- Connect a USB audio device"
echo "- Run audio diagnostics: python3 test_audio.py"
echo ""
echo "Audio setup complete!"
