#!/bin/bash
# Quick fix for systemd service creation - run this on your Pi

echo "=== Quick Fix for Systemd Service Creation ==="

# Create the watchdog service file manually with proper permissions
sudo bash -c 'cat > "/etc/systemd/system/wrb-watchdog.service" << EOF
[Unit]
Description=WRB System Watchdog
After=network.target WRB-enhanced.service
Wants=network.target

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01/WRB
Environment=HOME=/home/wrb01
Environment=USER=wrb01
ExecStart=/usr/bin/python3 /home/wrb01/WRB/health_monitor.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF'

# Create the network monitor service file manually
sudo bash -c 'cat > "/etc/systemd/system/wrb-network-monitor.service" << EOF
[Unit]
Description=WRB Network Monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=wrb01
Group=audio
WorkingDirectory=/home/wrb01/WRB
Environment=HOME=/home/wrb01
Environment=USER=wrb01
ExecStart=/usr/bin/python3 /home/wrb01/WRB/network_monitor.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF'

# Create logrotate config
sudo bash -c 'cat > "/etc/logrotate.d/wrb" << EOF
/home/wrb01/WRB/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 wrb01 wrb01
    postrotate
        systemctl reload WRB-enhanced.service > /dev/null 2>&1 || true
    endscript
}
EOF'

# Reload systemd and enable services
sudo systemctl daemon-reload
sudo systemctl enable wrb-watchdog.service
sudo systemctl enable wrb-network-monitor.service

echo "✅ All systemd services created successfully"
echo "✅ Now you can run: ./install.sh"
echo "✅ The install script should complete without errors"
