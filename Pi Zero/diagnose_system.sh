#!/bin/bash
# WRB System Diagnostic Script
# Quick diagnostic tool for troubleshooting WRB issues

echo "WRB System Diagnostic Tool"
echo "========================="
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "WARNING: Running as root. Some checks may not work correctly."
    echo "Consider running as a regular user."
    echo
fi

# Check system info
echo "System Information:"
echo "-------------------"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo

# Check service status
echo "Service Status:"
echo "---------------"
if systemctl is-active --quiet WRB-enhanced.service; then
    echo "✓ WRB service is running"
else
    echo "✗ WRB service is not running"
fi

if systemctl is-enabled --quiet WRB-enhanced.service; then
    echo "✓ WRB service is enabled"
else
    echo "✗ WRB service is not enabled"
fi
echo

# Check serial ports
echo "Serial Ports:"
echo "-------------"
for port in /dev/ttyACM0 /dev/ttyACM1 /dev/ttyUSB0 /dev/ttyUSB1; do
    if [ -e "$port" ]; then
        echo "✓ $port exists"
        # Check permissions
        if [ -r "$port" ] && [ -w "$port" ]; then
            echo "  ✓ Read/write permissions OK"
        else
            echo "  ✗ Permission issues"
        fi
    else
        echo "✗ $port not found"
    fi
done
echo

# Check audio system
echo "Audio System:"
echo "-------------"
if command -v aplay >/dev/null 2>&1; then
    echo "✓ ALSA available"
    aplay -l | head -5
else
    echo "✗ ALSA not available"
fi

if command -v pactl >/dev/null 2>&1; then
    echo "✓ PulseAudio available"
    pactl info | grep "Server Name" | head -1
else
    echo "✗ PulseAudio not available"
fi
echo

# Check GPIO
echo "GPIO System:"
echo "------------"
if [ -e "/dev/gpiomem" ]; then
    echo "✓ GPIO memory device exists"
    if [ -r "/dev/gpiomem" ] && [ -w "/dev/gpiomem" ]; then
        echo "✓ GPIO permissions OK"
    else
        echo "✗ GPIO permission issues"
    fi
else
    echo "✗ GPIO memory device not found"
fi
echo

# Check user groups
echo "User Groups:"
echo "------------"
echo "Current user: $(whoami)"
echo "Groups: $(groups)"
if groups | grep -q audio; then
    echo "✓ User in audio group"
else
    echo "✗ User not in audio group"
fi
if groups | grep -q gpio; then
    echo "✓ User in gpio group"
else
    echo "✗ User not in gpio group"
fi
if groups | grep -q dialout; then
    echo "✓ User in dialout group"
else
    echo "✗ User not in dialout group"
fi
echo

# Check WRB files
echo "WRB Files:"
echo "----------"
WRB_HOME="$HOME/WRB"
if [ -d "$WRB_HOME" ]; then
    echo "✓ WRB directory exists"
    if [ -f "$WRB_HOME/PiScript" ]; then
        echo "✓ PiScript found"
        if [ -x "$WRB_HOME/PiScript" ]; then
            echo "✓ PiScript executable"
        else
            echo "✗ PiScript not executable"
        fi
    else
        echo "✗ PiScript not found"
    fi
    if [ -f "$WRB_HOME/config.py" ]; then
        echo "✓ config.py found"
    else
        echo "✗ config.py not found"
    fi
else
    echo "✗ WRB directory not found"
fi
echo

# Check sound files
echo "Sound Files:"
echo "------------"
if [ -d "$WRB_HOME/sounds" ]; then
    sound_count=$(find "$WRB_HOME/sounds" -name "*.wav" | wc -l)
    echo "✓ Local sounds directory: $sound_count files"
else
    echo "✗ Local sounds directory not found"
fi

if [ -d "$WRB_HOME/default_sounds" ]; then
    default_count=$(find "$WRB_HOME/default_sounds" -name "*.wav" | wc -l)
    echo "✓ Default sounds directory: $default_count files"
else
    echo "✗ Default sounds directory not found"
fi
echo

# Check USB drives
echo "USB Drives:"
echo "-----------"
if lsblk -J >/dev/null 2>&1; then
    usb_count=$(lsblk -J | jq -r '.blockdevices[] | select(.tran=="usb") | .name' 2>/dev/null | wc -l)
    if [ "$usb_count" -gt 0 ]; then
        echo "✓ USB drives detected: $usb_count"
        lsblk -J | jq -r '.blockdevices[] | select(.tran=="usb") | "  \(.name): \(.size) - \(.mountpoint // "not mounted")"' 2>/dev/null
    else
        echo "✗ No USB drives detected"
    fi
else
    echo "✗ Unable to check USB drives"
fi
echo

# Check recent logs
echo "Recent Logs:"
echo "------------"
if [ -f "$WRB_HOME/logs/button_log.txt" ]; then
    echo "✓ Button log file exists"
    echo "Last 5 log entries:"
    tail -5 "$WRB_HOME/logs/button_log.txt" 2>/dev/null | sed 's/^/  /'
else
    echo "✗ Button log file not found"
fi
echo

# Check system resources
echo "System Resources:"
echo "-----------------"
echo "Memory usage:"
free -h | grep -E "(Mem|Swap)"
echo
echo "Disk usage:"
df -h / | tail -1
echo
echo "CPU load:"
uptime | awk -F'load average:' '{print $2}'
echo

echo "Diagnostic complete!"
echo "===================="
echo
echo "If you see any ✗ marks above, those are potential issues to investigate."
echo "Run 'python3 ~/WRB/test_system.py' for more detailed testing."
