"""
WRB Enhanced Audio System Configuration
Raspberry Pi ESP32 Wireless Button System

This file contains all configuration parameters for the WRB system.
Modify these values to customize the system behavior.
"""

# =============================================================================
# SERIAL COMMUNICATION CONFIGURATION
# =============================================================================

# Serial port settings
BAUD = 115200
SERIAL_PORT = "/dev/ttyACM0"  # Primary port, will auto-detect if not available

# Alternative serial ports to try (in order of preference)
ALTERNATIVE_PORTS = [
    "/dev/ttyACM1",
    "/dev/ttyUSB0", 
    "/dev/ttyUSB1"
]

# Serial communication timeouts
SERIAL_TIMEOUT = 1.0
SERIAL_WRITE_TIMEOUT = 1.0

# =============================================================================
# GPIO PIN CONFIGURATION
# =============================================================================

# LED pins (BCM numbering)
READY_PIN = 23      # Ready LED (green) - indicates system ready
USB_LED_PIN = 24    # USB LED (blue) - indicates USB drive status

# GPIO settings
GPIO_MODE = "BCM"   # Use BCM numbering (GPIO numbers)

# =============================================================================
# AUDIO CONFIGURATION
# =============================================================================

# Audio mixer settings
MIX_FREQ = 44100    # Sample rate (Hz)
MIX_BUF = 512       # Buffer size (samples)
MIX_CHANNELS = 2    # Stereo (2 channels)
MIX_BITS = 16       # 16-bit audio

# Number of simultaneous audio channels
MAX_AUDIO_CHANNELS = 4

# Audio file settings
SUPPORTED_FORMATS = ['.wav']  # Supported audio file formats
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB maximum file size

# =============================================================================
# FILE PATH CONFIGURATION
# =============================================================================

# Base directory for WRB files
WRB_HOME = "~/WRB"

# Sound file directories (in order of preference)
SOUND_DIRECTORIES = [
    "~/WRB/sounds",           # Local sounds directory
    "~/WRB/default_sounds",   # Default sounds directory
]

# Log file paths
LOG_DIR = "~/WRB/logs"
LOG_FILE = "~/WRB/logs/button_log.txt"
ERROR_LOG = "~/WRB/logs/error_log.txt"

# Configuration file path
CONFIG_FILE = "~/WRB/config.py"

# =============================================================================
# ESP32 MESSAGE CONFIGURATION
# =============================================================================

# ESP32 message types (must match ESP32 code)
MSG_PING = 0xA0     # Ping message
MSG_ACK = 0xA1      # Acknowledgment message
MSG_BTN = 0xB0      # Button press message
MSG_BTN_HOLD = 0xB1 # Button hold message

# Message processing settings
MESSAGE_TIMEOUT = 1.0  # Timeout for message processing
MAX_MESSAGE_LENGTH = 64  # Maximum message length

# =============================================================================
# TIMING CONFIGURATION
# =============================================================================

# Button timing settings
BUTTON_DEBOUNCE_TIME = 0.5  # Debounce time in seconds (500ms)
HOLD_DELAY_MS = 800         # Hold threshold in milliseconds
DOUBLE_TAP_PREVENTION = 0.5 # Prevent double taps within this time

# System timing
STATUS_UPDATE_INTERVAL = 30    # Status update interval in seconds
USB_CHECK_INTERVAL = 5         # USB drive check interval in seconds
SERIAL_RETRY_INTERVAL = 5      # Serial connection retry interval in seconds
LOG_ROTATION_INTERVAL = 86400  # Log rotation interval in seconds (24 hours)

# =============================================================================
# USB DRIVE CONFIGURATION
# =============================================================================

# USB drive mount points (common locations)
USB_MOUNT_POINTS = [
    "/media/*/",
    "/mnt/usb*",
    "/media/usb*",
    "/media/pi/*/"
]

# USB drive detection settings
USB_CHECK_ENABLED = True
USB_AUTO_MOUNT = True
USB_HOT_SWAP = True

# Sound file naming patterns for USB drives
SOUND_FILE_PATTERNS = {
    'button1': ['button1*.wav', 'btn1*.wav'],
    'button2': ['button2*.wav', 'btn2*.wav'],
    'hold1': ['hold1*.wav', 'long1*.wav'],
    'hold2': ['hold2*.wav', 'long2*.wav']
}

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

# Logging levels
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL

# Logging format
LOG_FORMAT = '%(asctime)s - %(levelname)s - %(message)s'
LOG_DATE_FORMAT = '%Y-%m-%d %H:%M:%S'

# Log file settings
LOG_MAX_SIZE = 10 * 1024 * 1024  # 10MB maximum log file size
LOG_BACKUP_COUNT = 5  # Number of backup log files to keep

# Console logging
CONSOLE_LOGGING = True
CONSOLE_LOG_LEVEL = "INFO"

# =============================================================================
# SYSTEM SERVICE CONFIGURATION
# =============================================================================

# Service settings
SERVICE_NAME = "WRB-enhanced.service"
SERVICE_USER = "pi"
SERVICE_GROUP = "audio"
SERVICE_WORKING_DIR = "/home/pi/WRB"

# Service environment variables
SERVICE_ENV_VARS = {
    'WRB_SERIAL': '/dev/ttyACM0',
    'SDL_AUDIODRIVER': 'pulse',
    'PULSE_RUNTIME_PATH': '/run/user/1000/pulse'
}

# Service restart settings
SERVICE_RESTART_POLICY = "on-failure"
SERVICE_RESTART_DELAY = 10  # seconds
SERVICE_START_TIMEOUT = 30  # seconds
SERVICE_STOP_TIMEOUT = 10   # seconds

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

# Allowed ESP32 MAC addresses (transmitters)
# Add your transmitter MAC addresses here
ALLOWED_TRANSMITTER_MACS = [
    "58:8c:81:9f:22:ac",  # Transmitter 1
    "58:8c:81:9f:22:ad",  # Transmitter 2
    "58:8c:81:9f:22:ae",  # Transmitter 3
]

# Security settings
MAC_ADDRESS_VALIDATION = True
MESSAGE_VALIDATION = True
UNAUTHORIZED_DEVICE_LOGGING = True

# =============================================================================
# PERFORMANCE CONFIGURATION
# =============================================================================

# Threading settings
SERIAL_THREAD_PRIORITY = "normal"
MONITOR_THREAD_PRIORITY = "low"
AUDIO_THREAD_PRIORITY = "high"

# Memory management
MAX_SOUND_CACHE_SIZE = 50 * 1024 * 1024  # 50MB maximum sound cache
SOUND_CACHE_CLEANUP_INTERVAL = 300  # 5 minutes

# =============================================================================
# DEBUGGING CONFIGURATION
# =============================================================================

# Debug settings
DEBUG_MODE = False
VERBOSE_LOGGING = False
SERIAL_DEBUG = False
GPIO_DEBUG = False
AUDIO_DEBUG = False

# Test mode settings
TEST_MODE = False
TEST_SOUND_ENABLED = True
TEST_GPIO_ENABLED = True

# =============================================================================
# HARDWARE CONFIGURATION
# =============================================================================

# ESP32 settings
ESP32_CHANNEL = 1  # WiFi channel for ESP-NOW
ESP32_RETRY_COUNT = 3
ESP32_RETRY_DELAY = 50  # milliseconds

# Raspberry Pi settings
PI_MODEL = "auto"  # auto-detect Pi model
PI_GPIO_WARNINGS = False
PI_GPIO_CLEANUP = True

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

# WiFi settings (for ESP32 communication)
WIFI_CHANNEL = 1
WIFI_SSID = ""  # Not used for ESP-NOW
WIFI_PASSWORD = ""  # Not used for ESP-NOW

# Network monitoring
NETWORK_MONITORING = False
NETWORK_CHECK_INTERVAL = 60  # seconds

# =============================================================================
# UPDATE CONFIGURATION
# =============================================================================

# Update settings
AUTO_UPDATE_CHECK = True
UPDATE_CHECK_INTERVAL = 86400  # 24 hours
UPDATE_BRANCH = "Update-1.0"  # Preferred branch
UPDATE_FALLBACK_BRANCH = "main"  # Fallback branch

# Git repository settings
GIT_REPO_URL = "https://github.com/Jallison154/TheBigWRB.git"
GIT_REMOTE = "origin"

# =============================================================================
# CUSTOMIZATION CONFIGURATION
# =============================================================================

# Custom actions (can be extended)
CUSTOM_ACTIONS = {
    'button1_press': None,    # Function to call on button 1 press
    'button2_press': None,    # Function to call on button 2 press
    'button1_hold': None,     # Function to call on button 1 hold
    'button2_hold': None,     # Function to call on button 2 hold
}

# Custom sound settings
CUSTOM_SOUND_ENABLED = True
CUSTOM_SOUND_DIRECTORY = "~/WRB/custom_sounds"

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

def validate_config():
    """Validate configuration parameters"""
    errors = []
    
    # Validate GPIO pins
    if not isinstance(READY_PIN, int) or READY_PIN < 0 or READY_PIN > 27:
        errors.append("READY_PIN must be a valid GPIO pin number (0-27)")
    
    if not isinstance(USB_LED_PIN, int) or USB_LED_PIN < 0 or USB_LED_PIN > 27:
        errors.append("USB_LED_PIN must be a valid GPIO pin number (0-27)")
    
    # Validate audio settings
    if MIX_FREQ not in [22050, 44100, 48000]:
        errors.append("MIX_FREQ must be 22050, 44100, or 48000")
    
    if MIX_BUF < 256 or MIX_BUF > 4096:
        errors.append("MIX_BUF must be between 256 and 4096")
    
    # Validate timing settings
    if BUTTON_DEBOUNCE_TIME < 0.1 or BUTTON_DEBOUNCE_TIME > 2.0:
        errors.append("BUTTON_DEBOUNCE_TIME must be between 0.1 and 2.0 seconds")
    
    if HOLD_DELAY_MS < 500 or HOLD_DELAY_MS > 2000:
        errors.append("HOLD_DELAY_MS must be between 500 and 2000 milliseconds")
    
    return errors

# Validate configuration on import
if __name__ != "__main__":
    config_errors = validate_config()
    if config_errors:
        print("Configuration errors found:")
        for error in config_errors:
            print(f"  - {error}")
        print("Please fix these errors before running the system.")
    else:
        print("Configuration validated successfully")
