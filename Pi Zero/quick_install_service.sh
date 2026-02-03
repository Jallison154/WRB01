#!/bin/bash
# Quick one-command installation of WRB-enhanced.service from git
# Usage: curl -sSL https://raw.githubusercontent.com/Jallison154/WRB01/WRB01/Pi%20Zero/quick_install_service.sh | bash

set -e

echo "=== Quick WRB Service Installation from Git ==="

# Find PiScript
PSCRIPT=$(find /home/wrb01 -name "PiScript" -type f 2>/dev/null | head -1)
if [ -z "$PSCRIPT" ]; then
    echo "ERROR: PiScript not found. Please ensure PiScript is installed."
    exit 1
fi

echo "Found PiScript at: $PSCRIPT"

# Create service file
sudo tee /etc/systemd/system/WRB-enhanced.service > /dev/null << EOF
[Unit]
Description=WRB Enhanced Audio System
After=local-fs.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=$(dirname "$PSCRIPT")
Environment=HOME=/home/wrb01
Environment=USER=wrb01
Environment=WRB_SERIAL=/dev/ttyACM0
Environment=SDL_AUDIODRIVER=alsa
Environment=AUDIODEV=plughw:1,0
Environment=PYGAME_HIDE_SUPPORT_PROMPT=1
ExecStart=/usr/bin/python3 $PSCRIPT
Restart=on-failure
RestartSec=5
TimeoutStartSec=30
StandardOutput=journal
StandardError=journal
Nice=-10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable WRB-enhanced.service
sudo systemctl start WRB-enhanced.service

echo "✓ Service installed and started"
echo "Check status: sudo systemctl status WRB-enhanced.service"
