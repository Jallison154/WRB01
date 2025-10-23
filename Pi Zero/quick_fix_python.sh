#!/bin/bash
"""
Quick Fix for externally-managed-environment error
This script provides the most direct solutions that work in 2024
"""

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Quick Python Fix for externally-managed-environment ===${NC}"
echo

# Method 1: Direct fix with --user --break-system-packages
echo -e "${YELLOW}Method 1: Installing with --user --break-system-packages${NC}"
echo "This is the current 2024 workaround that works:"
echo

pip3 install --user --break-system-packages pygame pyserial numpy RPi.GPIO psutil

echo
echo -e "${GREEN}✓ Method 1 completed${NC}"
echo

# Test the installation
echo -e "${YELLOW}Testing installation...${NC}"
python3 -c "
try:
    import pygame
    print('✓ pygame works')
except ImportError as e:
    print('✗ pygame failed:', e)

try:
    import serial
    print('✓ serial works')
except ImportError as e:
    print('✗ serial failed:', e)

try:
    import numpy
    print('✓ numpy works')
except ImportError as e:
    print('✗ numpy failed:', e)

try:
    import RPi.GPIO as GPIO
    print('✓ RPi.GPIO works')
except ImportError as e:
    print('✗ RPi.GPIO failed (normal on non-Pi):', e)

try:
    import psutil
    print('✓ psutil works')
except ImportError as e:
    print('✗ psutil failed:', e)
"

echo
echo -e "${GREEN}=== Quick Fix Complete ===${NC}"
echo "If you still have issues, try:"
echo "1. Restart your terminal"
echo "2. Run: source ~/.bashrc"
echo "3. Try the full fix script: ./fix_python_2024.sh"
