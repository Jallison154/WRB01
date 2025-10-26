# WRB01 Boot Speed Optimizations

## Current Situation
- Boot time: ~60 seconds (too slow for production)
- Target: < 15 seconds to service ready

## Optimization Strategy

### 1. **Service Dependencies** (CRITICAL) ⚡
**Problem**: Service waits for network/udev which can take 30-60 seconds

**Solution**: Make service start immediately without network dependencies

```ini
[Unit]
Description=WRB Simple Audio Player
After=local-fs.target
DefaultDependencies=no

[Service]
Type=simple
# Don't wait for network - we don't need it!
# Remove: After=network-online.target
# Remove: Wants=network-online.target
```

### 2. **Disable Network Wait** (HIGH IMPACT) 🚀
**Problem**: systemd waits for network which can take 30+ seconds

**Solution**: 
```bash
sudo systemctl mask systemd-networkd-wait-online.service
sudo systemctl mask NetworkManager-wait-online.service
```

### 3. **Optimize systemd Timeouts** ⏱️
```ini
[Unit]
DefaultDependencies=no
# Start immediately after filesystem mounts
After=local-fs.target
# Don't wait for any other services
```

### 4. **Python Import Optimization** 🐍
**Problem**: pygame imports take 2-5 seconds

**Solution**: Use module caching and eager imports
- Pre-compile Python modules
- Use -O flag for optimized bytecode
- Cache pygame initialization

### 5. **Filesystem Optimizations** 💾
```bash
# Add to /etc/fstab for faster access
noatime,nodiratime

# Use faster filesystem journaling
sudo tune2fs -o journal_data_writeback /dev/mmcblk0p2
```

### 6. **Disable Unnecessary Services** 🎯
```bash
# Services that can be disabled for faster boot:
sudo systemctl disable avahi-daemon.service  # mDNS (not needed)
sudo systemctl disable triggerhappy.service  # Input hotkey daemon
sudo systemctl disable ModemManager.service  # Mobile broadband
sudo systemctl disable ofono.service         # Mobile telephony
sudo systemctl disable dphys-swapfile.service # Swap file creation
```

### 7. **Disable Splash Screen** ⚡
```bash
# In /boot/cmdline.txt add:
quiet logo.nologo
```

### 8. **Overclock for Faster Boot** ⚡⚡
```bash
# Add to /boot/config.txt:
arm_freq=1200
over_voltage=2
```

### 9. **Faster SD Card Access** 💿
- Use Class 10 or faster SD card
- Use Raspberry Pi 4 instead of Pi Zero (much faster)
- Consider USB boot for even faster access

### 10. **Parallel Service Startup** 🔄
```bash
# Enable in /etc/systemd/system.conf.d/10-wrb.conf
[Manager]
DefaultTimeoutStartSec=5s
# Allow parallel service startup
```

## Expected Results

### Before Optimizations:
- Boot to service ready: ~60 seconds
- Network wait: ~30-40 seconds
- Python imports: ~2-5 seconds
- Service start: ~5-10 seconds

### After Optimizations:
- Boot to service ready: **~10-15 seconds** ✅
- Network wait: **0 seconds** (bypassed)
- Python imports: **~1-2 seconds** (cached)
- Service start: **~2-3 seconds** (no dependencies)

## Implementation Priority

### Critical (Do First):
1. ✅ Remove network dependencies
2. ✅ Set DefaultDependencies=no
3. ✅ Disable network-wait services
4. ✅ Optimize service unit file

### High Priority:
5. ⚠️ Disable unnecessary services
6. ⚠️ Add filesystem optimizations
7. ⚠️ Python import optimization

### Nice to Have:
8. ⚠️ Disable splash screen
9. ⚠️ Overclock
10. ⚠️ Faster SD card

## Testing Commands

```bash
# Check current boot time
systemd-analyze
systemd-analyze critical-chain wrb-simple.service
systemd-analyze blame

# Measure service start time
time systemctl start wrb-simple.service

# Check what's blocking boot
journalctl -b | grep -i "delay\|timeout\|wait"
```

## Target Metrics
- System boot: < 10 seconds
- Service ready: < 15 seconds total
- Audio playback ready: < 18 seconds total
