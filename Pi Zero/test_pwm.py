#!/usr/bin/env python3
"""
Test PWM LED control for WRB system
"""
import RPi.GPIO as GPIO
import time
import sys

# GPIO pins
READY_PIN = 23
USB_LED_PIN = 24

def test_pwm():
    """Test PWM LED control"""
    try:
        print("Setting up GPIO...")
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(READY_PIN, GPIO.OUT)
        GPIO.setup(USB_LED_PIN, GPIO.OUT)
        
        print("Initializing PWM...")
        ready_pwm = GPIO.PWM(READY_PIN, 1000)  # 1kHz frequency
        usb_pwm = GPIO.PWM(USB_LED_PIN, 1000)
        
        print("Starting PWM...")
        ready_pwm.start(0)  # Start at 0% duty cycle
        usb_pwm.start(0)
        
        print("Testing Ready LED (GPIO 23)...")
        # Test ready LED at 25%
        ready_pwm.ChangeDutyCycle(25)
        print("Ready LED should be at 25% brightness")
        time.sleep(2)
        
        # Test flash
        print("Testing flash...")
        ready_pwm.ChangeDutyCycle(100)
        print("Ready LED should be at 100% brightness")
        time.sleep(0.2)
        ready_pwm.ChangeDutyCycle(25)
        print("Ready LED should be back at 25% brightness")
        time.sleep(2)
        
        print("Testing USB LED (GPIO 24)...")
        # Test USB LED
        usb_pwm.ChangeDutyCycle(100)
        print("USB LED should be at 100% brightness")
        time.sleep(2)
        usb_pwm.ChangeDutyCycle(0)
        print("USB LED should be off")
        time.sleep(1)
        
        print("Stopping PWM...")
        ready_pwm.stop()
        usb_pwm.stop()
        
        print("Cleaning up...")
        GPIO.cleanup()
        
        print("PWM test completed successfully!")
        return True
        
    except Exception as e:
        print(f"PWM test failed: {e}")
        try:
            GPIO.cleanup()
        except:
            pass
        return False

if __name__ == "__main__":
    print("WRB PWM LED Test")
    print("=================")
    print("Make sure LEDs are connected to:")
    print(f"  Ready LED: GPIO {READY_PIN} (Physical Pin 16)")
    print(f"  USB LED: GPIO {USB_LED_PIN} (Physical Pin 18)")
    print("  Both LEDs need 220Ω resistors to 3.3V")
    print()
    
    success = test_pwm()
    sys.exit(0 if success else 1)
