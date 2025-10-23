#!/bin/bash
# Quick update script for WRB system

echo "=== WRB Quick Update ==="

# Get current directory
CURRENT_DIR=$(pwd)
HOME_DIR=$(eval echo ~$USER)

echo "Current directory: $CURRENT_DIR"
echo "Home directory: $HOME_DIR"

# Update from git if in repository
if [ -d ".git" ]; then
    echo "Updating from git..."
    git pull origin main
    echo "✅ Git update complete"
else
    echo "⚠️  Not in git repository, manual update needed"
fi

# Copy files to working directory
echo "Copying files to working directory..."
mkdir -p "$HOME_DIR/WRB01/Pi Zero"

# Copy all files
cp -r * "$HOME_DIR/WRB01/Pi Zero/" 2>/dev/null || true

# Set permissions
chmod +x "$HOME_DIR/WRB01/Pi Zero"/*.py 2>/dev/null || true
chmod +x "$HOME_DIR/WRB01/Pi Zero"/*.sh 2>/dev/null || true

echo "✅ Files copied to $HOME_DIR/WRB01/Pi Zero/"

# Update service if it exists
if [ -f "WRB-enhanced.service" ]; then
    echo "Updating service file..."
    sudo cp "WRB-enhanced.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    echo "✅ Service updated"
fi

echo "=== Update Complete ==="
echo "Run: python3 fix_debian_packages.py"
