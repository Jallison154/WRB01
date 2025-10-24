#!/bin/bash
# Quick fix for systemd service creation permissions

echo "=== Fixing Systemd Service Permissions ==="

# Create the watchdog service file manually
sudo tee "/etc/systemd/system/wrb-watchdog.service" > /dev/null << 'EOF'
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
EOF

# Create the network monitor service file manually
sudo tee "/etc/systemd/system/wrb-network-monitor.service" > /dev/null << 'EOF'
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
EOF

# Create logrotate config
sudo tee "/etc/logrotate.d/wrb" > /dev/null << 'EOF'
/home/wrb01/WRB/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 wrb01 wrb01
}
EOF

# Reload systemd and enable services
sudo systemctl daemon-reload
sudo systemctl enable wrb-watchdog.service
sudo systemctl enable wrb-network-monitor.service

echo "✅ Systemd services created successfully"
echo "✅ Now run: ./install.sh"
