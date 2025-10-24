# Simple Button + Audio System

Ultra-simple ESP32 button control with audio playback.

## Files
- `ESP32_Simple_Button.ino` - ESP32 code
- `simple_audio_player.py` - Pi audio player
- `simple_install.sh` - Installation script
- `button1.wav`, `button2.wav` - Button press audio files
- `hold1.wav`, `hold2.wav` - Button hold audio files

## Setup

### ESP32
1. Upload `ESP32_Simple_Button.ino` to ESP32
2. Connect buttons to pins 2 and 4
3. Connect ESP32 to Pi via USB

### Pi
1. Run: `./simple_install.sh`
2. Add your audio files: `button1.wav`, `button2.wav`, `hold1.wav`, `hold2.wav`
3. Run: `python3 /home/wrb01/simple_audio_player.py`

## How It Works
1. Button press → ESP32 sends "BTN1" or "BTN2" via serial
2. Button hold → ESP32 sends "HOLD1" or "HOLD2" via serial
3. Pi reads serial → plays corresponding audio file
4. Audio plays through Pi's audio output

That's it! 🎯
