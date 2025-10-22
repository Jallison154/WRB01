#!/bin/bash
# Quick WRB Button Diagnosis Script
# Run this to quickly check button trigger issues

echo "=========================================="
echo "  WRB Button Trigger Quick Diagnosis"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please don't run this script as root. Run as pi user instead."
    exit 1
fi

echo "🔍 Checking system services..."
echo ""

# Check main service
echo "📊 WRB Service Status:"
sudo systemctl status WRB-enhanced.service --no-pager -l
echo ""

# Check other services
echo "📊 All WRB Services:"
sudo systemctl status WRB-enhanced WRB-health-check WRB-watchdog WRB-auto-start --no-pager
echo ""

# Check recent logs
echo "📋 Recent Service Logs (last 20 lines):"
sudo journalctl -u WRB-enhanced.service -n 20 --no-pager
echo ""

# Check for serial ports
echo "🔌 Serial Ports:"
ls -la /dev/ttyACM* /dev/ttyUSB* /dev/serial* 2>/dev/null || echo "No serial ports found"
echo ""

# Check sound files
echo "🎵 Sound Files:"
if [ -d "/home/pi/WRB/sounds" ]; then
    echo "Local sounds directory:"
    ls -la /home/pi/WRB/sounds/
else
    echo "❌ No local sounds directory found"
fi
echo ""

# Check USB drives
echo "💾 USB Drives:"
if [ -d "/media" ]; then
    echo "Mounted USB drives:"
    ls -la /media/
else
    echo "No USB drives mounted"
fi
echo ""

# Check for button messages in logs
echo "📨 Recent Button Messages:"
sudo journalctl -u WRB-enhanced.service --since "1 hour ago" | grep -i "btn\|button\|hold" | tail -10
echo ""

# Check ESP32 connection
echo "🔗 ESP32 Connection Test:"
if [ -e "/dev/ttyACM0" ]; then
    echo "✅ /dev/ttyACM0 exists"
    echo "📡 Testing serial communication (5 seconds)..."
    timeout 5s cat /dev/ttyACM0 2>/dev/null | head -5 || echo "❌ No data from ESP32"
elif [ -e "/dev/ttyUSB0" ]; then
    echo "✅ /dev/ttyUSB0 exists"
    echo "📡 Testing serial communication (5 seconds)..."
    timeout 5s cat /dev/ttyUSB0 2>/dev/null | head -5 || echo "❌ No data from ESP32"
else
    echo "❌ No ESP32 serial ports found"
    echo "💡 Check ESP32 connection and power"
fi
echo ""

echo "=========================================="
echo "  Quick Diagnosis Complete"
echo "=========================================="
echo ""
echo "🔧 If buttons aren't working:"
echo "  1. Check ESP32 power and connections"
echo "  2. Verify transmitter and receiver are paired"
echo "  3. Restart service: sudo systemctl restart WRB-enhanced"
echo "  4. Check logs: sudo journalctl -u WRB-enhanced.service -f"
echo "  5. Run full diagnosis: python3 /home/pi/WRB/troubleshoot_buttons.py"
echo ""
echo "📋 Useful Commands:"
echo "  Service status: sudo systemctl status WRB-enhanced.service"
echo "  View logs: sudo journalctl -u WRB-enhanced.service -f"
echo "  Restart: sudo systemctl restart WRB-enhanced.service"
echo "  Monitor: python3 /home/pi/WRB/monitor_system.py"
