#!/usr/bin/env python3
"""
WRB Simple Audio Player for ESP32 Button System
Based on working mattsfx code with proper audio handling
"""

import os, glob, time, random, sys, serial

# ALSA device configuration
os.environ.setdefault("SDL_AUDIODRIVER", "alsa")
os.environ.setdefault("AUDIODEV", "plughw:1,0")  # USB audio device

BAUD = 115200
SERIAL = os.getenv("WRB_SERIAL", "/dev/ttyACM0")
READY_PIN = 18
READY_ACTIVE_LOW = True
MIX_FREQ = 44100
MIX_BUF = 256
RESCAN_SEC = 1.0
IDLE_SHUTOFF_SEC = 1.0   # close audio device this long after last cue

# --- LED (simple on/off, active-low wiring) ---
from gpiozero import LED
led = LED(READY_PIN, active_high=(not READY_ACTIVE_LOW))

def usb_mount_dirs():
    base = "/media"
    return [os.path.join(base, d) for d in sorted(os.listdir(base))
            if os.path.isdir(os.path.join(base, d)) and os.path.ismount(os.path.join(base, d))] if os.path.isdir(base) else []

def pick_source():
    # Check USB drives first
    for mnt in usb_mount_dirs():
        button1 = sorted(glob.glob(os.path.join(mnt, "button1*.wav")))
        button2 = sorted(glob.glob(os.path.join(mnt, "button2*.wav")))
        hold1 = sorted(glob.glob(os.path.join(mnt, "hold1*.wav")))
        hold2 = sorted(glob.glob(os.path.join(mnt, "hold2*.wav")))
        if button1 or button2 or hold1 or hold2:
            return (f"USB:{mnt}", button1[:1], button2[:1], hold1[:1], hold2[:1])
    
    # Fallback to local directory
    local = "/home/wrb01/audio"
    os.makedirs(local, exist_ok=True)
    button1 = sorted(glob.glob(os.path.join(local, "button1*.wav")))
    button2 = sorted(glob.glob(os.path.join(local, "button2*.wav")))
    hold1 = sorted(glob.glob(os.path.join(local, "hold1*.wav")))
    hold2 = sorted(glob.glob(os.path.join(local, "hold2*.wav")))
    return ("LOCAL", button1[:1], button2[:1], hold1[:1], hold2[:1])

def classify(s):
    u = s.strip().upper()
    if "BTN1" in u or "BUTTON1" in u: return 'BTN1'
    if "BTN2" in u or "BUTTON2" in u: return 'BTN2'
    if "HOLD1" in u: return 'HOLD1'
    if "HOLD2" in u: return 'HOLD2'
    return None

# --- on-demand audio helpers (no background output) ---
_mixer_ready = False
_last_play = 0
_button1_paths = []
_button2_paths = []
_hold1_paths = []
_hold2_paths = []

def set_paths(btn1, btn2, h1, h2):
    global _button1_paths, _button2_paths, _hold1_paths, _hold2_paths
    _button1_paths, _button2_paths, _hold1_paths, _hold2_paths = btn1, btn2, h1, h2

def ensure_mixer():
    global _mixer_ready
    if _mixer_ready: return
    import pygame
    for i in range(8):
        try:
            pygame.mixer.init(frequency=MIX_FREQ, size=-16, channels=2, buffer=MIX_BUF)
            _mixer_ready = True
            print("[wrb] audio: mixer ready", flush=True)
            return
        except Exception as e:
            print(f"[wrb] audio init retry {i+1}: {e}", flush=True)
            time.sleep(0.2)
    raise SystemExit("audio init failed")

def shutdown_mixer_if_idle():
    global _mixer_ready
    if not _mixer_ready: return
    import pygame
    if (time.time() - _last_play) > IDLE_SHUTOFF_SEC and not pygame.mixer.get_busy():
        pygame.mixer.quit()
        _mixer_ready = False
        print("[wrb] audio: mixer closed (idle)", flush=True)

def play_button1():
    global _last_play
    if not _button1_paths:
        print("[wrb] BUTTON1 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_button1_paths[0])
    pygame.mixer.Channel(0).play(s)
    _last_play = time.time()

def play_button2():
    global _last_play
    if not _button2_paths:
        print("[wrb] BUTTON2 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_button2_paths[0])
    pygame.mixer.Channel(1).play(s)
    _last_play = time.time()

def play_hold1():
    global _last_play
    if not _hold1_paths:
        print("[wrb] HOLD1 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_hold1_paths[0])
    pygame.mixer.Channel(2).play(s)
    _last_play = time.time()

def play_hold2():
    global _last_play
    if not _hold2_paths:
        print("[wrb] HOLD2 (no file)", flush=True)
        return
    ensure_mixer()
    import pygame
    s = pygame.mixer.Sound(_hold2_paths[0])
    pygame.mixer.Channel(3).play(s)
    _last_play = time.time()

def wait_serial():
    print("[wrb] waiting for serial…", flush=True)
    prefs = [SERIAL, "/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"]
    while True:
        for p in prefs:
            try:
                return serial.Serial(p, BAUD, timeout=0.1)
            except:
                pass
        time.sleep(0.3)

def main():
    led.off()  # OFF until ready

    # source scan + initial paths (no mixer init yet)
    tag, btn1, btn2, h1, h2 = pick_source()
    set_paths(btn1, btn2, h1, h2)
    print(f"[wrb] source={tag} btn1={btn1} btn2={btn2} hold1={h1} hold2={h2}", flush=True)

    ser = wait_serial()
    print(f"[wrb] serial: {ser.port}", flush=True)

    led.on()
    print("[wrb] READY", flush=True)
    last_scan = time.time()

    while True:
        # hot-swap (update file paths only)
        if time.time() - last_scan > RESCAN_SEC:
            ntag, nbtn1, nbtn2, nh1, nh2 = pick_source()
            if (ntag != tag) or (nbtn1 != btn1) or (nbtn2 != btn2) or (nh1 != h1) or (nh2 != h2):
                tag, btn1, btn2, h1, h2 = ntag, nbtn1, nbtn2, nh1, nh2
                set_paths(btn1, btn2, h1, h2)
                print(f"[wrb] reloaded: source={tag} btn1={btn1} btn2={btn2} hold1={h1} hold2={h2}", flush=True)
            last_scan = time.time()

        # read serial and play
        try:
            line = ser.readline().decode(errors="ignore")
        except Exception:
            time.sleep(0.05)
            continue
        if not line:
            shutdown_mixer_if_idle()
            continue

        t = classify(line)
        if t == 'BTN1':
            print("[wrb] BUTTON1", flush=True)
            play_button1()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass
        elif t == 'BTN2':
            print("[wrb] BUTTON2", flush=True)
            play_button2()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass
        elif t == 'HOLD1':
            print("[wrb] HOLD1", flush=True)
            play_hold1()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass
        elif t == 'HOLD2':
            print("[wrb] HOLD2", flush=True)
            play_hold2()
            try:
                led.off()
                time.sleep(0.04)
                led.on()
            except:
                pass

        shutdown_mixer_if_idle()

if __name__ == "__main__":
    main()