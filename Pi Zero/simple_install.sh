#!/bin/bash
# Simple Button + Audio System Installation

echo "=== Simple Button + Audio System ==="
echo "Installing basic ESP32 button control with audio playback..."

# Create audio directory
sudo mkdir -p /home/wrb01/audio
sudo chown wrb01:wrb01 /home/wrb01/audio

# Install required packages
sudo apt update
sudo apt install -y python3-pygame python3-serial python3-numpy alsa-utils

# Configure USB audio interface
echo "Configuring USB audio interface..."
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

# Set USB audio as default
echo "Setting USB audio as default output..."
sudo alsactl store

# Copy audio files from Default Sounds directory
if [ -d "Default Sounds" ]; then
    echo "Copying audio files from Default Sounds directory..."
    sudo cp "Default Sounds/button1.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ button1.wav copied" || echo "⚠ button1.wav not found"
    sudo cp "Default Sounds/button2.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ button2.wav copied" || echo "⚠ button2.wav not found"
    sudo cp "Default Sounds/hold1.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ hold1.wav copied" || echo "⚠ hold1.wav not found"
    sudo cp "Default Sounds/hold2.wav" /home/wrb01/audio/ 2>/dev/null && echo "✓ hold2.wav copied" || echo "⚠ hold2.wav not found"
    
    # Set proper ownership
    sudo chown wrb01:wrb01 /home/wrb01/audio/*.wav 2>/dev/null || true
else
    echo "⚠ Default Sounds directory not found"
    echo "Please add your audio files manually to /home/wrb01/audio/"
fi

# Copy Python script
sudo cp simple_audio_player.py /home/wrb01/
sudo chown wrb01:wrb01 /home/wrb01/simple_audio_player.py
sudo chmod +x /home/wrb01/simple_audio_player.py

echo "✓ Installation complete!"
echo
echo "To run the system:"
echo "  python3 /home/wrb01/simple_audio_player.py"
echo
echo "Make sure your ESP32 is connected to /dev/ttyACM0"
