#!/usr/bin/env python3
"""
Configuration file for ESP32 Wireless Button System
This file documents the MAC addresses and pin configurations used in the system.
"""

# MAC Address Configuration
# IMPORTANT: These must match between transmitter and receiver
# 
# Receiver MAC: 0x58,0x8C,0x81,0x9E,0x30,0x10 (58:8c:81:9e:30:10)
# Transmitter MAC: 0x58,0x8C,0x81,0x9F,0x22,0xAC (58:8c:81:9f:22:ac)
#
# In the Receiver ESP32 code:
# ALLOWED_TX_MACS[][6] = { { 0x58,0x8C,0x81,0x9F,0x22,0xAC } }; // Transmitter MAC
#
# In the Transmitter ESP32 code:
# RX_MAC[] = { 0x58,0x8C,0x81,0x9E,0x30,0x10 }; // Receiver MAC

# Pi Script Configuration
BAUD = 115200
SERIAL = "/dev/ttyACM0"
READY_PIN = 23
USB_LED_PIN = 24
READY_ACTIVE_LOW = True
USB_LED_ACTIVE_LOW = True

# Audio Configuration
MIX_FREQ = 44100
MIX_BUF = 512
RESCAN_SEC = 1.0
IDLE_SHUTOFF_SEC = 1.0

# File Paths
LOG_FILE = "/home/pi/WRB/button_log.txt"
HEALTH_LOG = "/home/pi/WRB/health_log.txt"

# ESP32 Message Types
MSG_PING = 0xA0
MSG_ACK = 0xA1
MSG_BTN = 0xB0

# Hardware Pin Configuration
# ESP32 Pins (using Dx aliases for XIAO ESP32C3)
LED_PIN = "D10"           # Status LED
BTN1_PIN = "D1"           # Button 1
BTN2_PIN = "D2"           # Button 2

# Power Management Settings
IDLE_LIGHT_MS = 5 * 60 * 1000    # 5 minutes to light sleep
IDLE_DEEP_MS = 15 * 60 * 1000    # 15 minutes to deep sleep
MAX_RETRIES = 3                   # Button press retry count
RETRY_DELAY_MS = 50              # Delay between retries

# Link Management
LINK_TIMEOUT_MS = 4000           # 4 second link timeout
PING_INTERVAL_MS = 500           # 500ms ping interval
STATUS_INTERVAL_MS = 10000       # 10 second status interval

# Security
MAX_TRANSMITTERS = 10            # Maximum number of transmitters
