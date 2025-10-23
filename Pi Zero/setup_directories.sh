#!/bin/bash
# Setup directories and copy files for WRB system

echo "Setting up WRB directories..."

# Create directories
mkdir -p ~/WRB01/Pi\ Zero/logs
mkdir -p ~/WRB01/Pi\ Zero/sounds
mkdir -p ~/WRB01/Pi\ Zero/default_sounds

# Copy default sounds if they exist
if [ -d "Default Sounds" ]; then
    echo "Copying default sounds..."
    cp -r "Default Sounds"/* ~/WRB01/Pi\ Zero/default_sounds/
fi

# Set permissions
chmod +x ~/WRB01/Pi\ Zero/PiScript
chmod +x ~/WRB01/Pi\ Zero/test_pwm.py
chmod +x ~/WRB01/Pi\ Zero/startup_test.py

echo "Directories created:"
echo "  ~/WRB01/Pi Zero/logs"
echo "  ~/WRB01/Pi Zero/sounds" 
echo "  ~/WRB01/Pi Zero/default_sounds"

echo "Setup complete!"
