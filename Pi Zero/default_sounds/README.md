# Default Sound Files

This directory contains the default sound files for the WRB system. These sounds are automatically generated during installation.

## Sound File Naming Convention

- `button1.wav` - Button 1 quick press (440Hz tone)
- `button2.wav` - Button 2 quick press (523Hz tone)  
- `hold1.wav` - Button 1 hold (A major chord)
- `hold2.wav` - Button 2 hold (C major chord)

## Sound Specifications

- **Format**: WAV
- **Sample Rate**: 44100 Hz
- **Bit Depth**: 16-bit
- **Channels**: Stereo (2-channel)
- **Duration**: 0.3s for buttons, 0.8s for holds

## Custom Sounds

To use custom sounds:
1. Place your WAV files in `~/WRB/sounds/`
2. Follow the naming convention above
3. Ensure files are 44.1kHz, 16-bit WAV format
4. Restart the WRB service

## USB Drive Support

You can also place sound files on a USB drive:
1. Insert USB drive with sound files
2. System automatically detects and loads sounds
3. LED indicator shows USB drive status
