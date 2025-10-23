/*
 * WRB ESP32 Transmitter
 * Seeed Studio XIAO ESP32C3 Wireless Button System
 * 
 * Features:
 * - Release-based triggering (no double triggers)
 * - Hold detection (800ms threshold)
 * - LED status indicators
 * - Power management (light/deep sleep)
 * - Retry mechanism for failed transmissions
 * - MAC address security
 * - Comprehensive logging
 */

#include <esp_now.h>
#include <WiFi.h>
#include <esp_sleep.h>

// =============================================================================
// CONFIGURATION SECTION
// =============================================================================

// MAC Address Configuration (Receiver MAC)
uint8_t RX_MAC[] = { 0x58, 0x8C, 0x81, 0x9E, 0x30, 0x10 };

// Pin Configuration
#define LED_PIN D10
#define BTN1_PIN D1
#define BTN2_PIN D2

// Timing Configuration
const uint32_t HOLD_DELAY_MS = 800;           // Hold threshold
const uint32_t IDLE_LIGHT_MS = 5 * 60 * 1000; // Light sleep delay (5 minutes)
const uint32_t IDLE_DEEP_MS = 15 * 60 * 1000; // Deep sleep delay (15 minutes)
const uint8_t MAX_RETRIES = 3;                 // Retry count
const uint32_t RETRY_DELAY_MS = 50;           // Retry interval
const uint32_t DEBOUNCE_TIME_MS = 50;         // Button debounce
const uint32_t LED_BLINK_MS = 100;            // LED blink duration

// Message Types
#define MSG_PING 0xA0
#define MSG_ACK 0xA1
#define MSG_BTN 0xB0
#define MSG_BTN_HOLD 0xB1

// =============================================================================
// GLOBAL VARIABLES
// =============================================================================

struct Message {
  uint8_t msgType;
  uint8_t button;
  uint8_t retryCount;
  uint32_t timestamp;
} message;

// Button state tracking
struct ButtonState {
  bool pressed;
  bool holdDetected;
  uint32_t pressTime;
  uint32_t lastDebounce;
  bool processed;
} btn1, btn2;

// System state
bool espnowReady = false;
uint32_t lastActivity = 0;
uint32_t lastPing = 0;
uint32_t lastLEDUpdate = 0;
bool ledState = false;
uint8_t retryCount = 0;

// LED behavior states
enum LEDState {
  LED_BREATHING,    // No connection to receiver
  LED_CONNECTED,    // Connected to receiver (25% brightness)
  LED_BUTTON_PRESS, // Button press (100% brightness)
  LED_BUTTON_HOLD,  // Button hold (double blink at 100%)
  LED_LIGHT_SLEEP,  // Light sleep (double blink at 10%)
  LED_DEEP_SLEEP    // Deep sleep (off)
};

LEDState currentLEDState = LED_BREATHING;
uint32_t ledStateStartTime = 0;
uint32_t breathingPhase = 0;
bool receiverConnected = false;

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

void printMacAddress(uint8_t* mac) {
  char macStr[18];
  snprintf(macStr, sizeof(macStr), "%02x:%02x:%02x:%02x:%02x:%02x",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  Serial.print(macStr);
}

void printMessage(const char* prefix, uint8_t type, uint8_t button = 0) {
  Serial.print(prefix);
  Serial.print(" Type: 0x");
  Serial.print(type, HEX);
  if (button > 0) {
    Serial.print(" Button: ");
    Serial.print(button);
  }
  Serial.println();
}

void updateLED() {
  uint32_t now = millis();
  
  // Check if any button is currently pressed
  bool anyButtonPressed = !digitalRead(BTN1_PIN) || !digitalRead(BTN2_PIN);
  
  if (anyButtonPressed) {
    // Button is pressed - 100% brightness
    analogWrite(LED_PIN, 255);
    Serial.println("LED: Button pressed - 100% brightness");
    return;
  }
  
  // No button pressed - check connection state
  if (receiverConnected) {
    // Connected - 25% brightness
    analogWrite(LED_PIN, 64);
    Serial.println("LED: Connected - 25% brightness");
  } else {
    // Not connected - breathing effect (3 second cycle)
    breathingPhase = (now / 15) % 200; // 3 second cycle (200 * 15ms)
    if (breathingPhase < 100) {
      // Fade in (0-25% of 255 = 0-64)
      analogWrite(LED_PIN, breathingPhase * 0.64); // 0-64 range
    } else {
      // Fade out (0-25% of 255 = 0-64)
      analogWrite(LED_PIN, (200 - breathingPhase) * 0.64);
    }
    Serial.println("LED: Not connected - breathing");
  }
}

void setLEDState(LEDState newState) {
  currentLEDState = newState;
  ledStateStartTime = millis();
  Serial.print("setLEDState called: ");
  Serial.println(newState);
}

void setLED(bool state) {
  digitalWrite(LED_PIN, state ? HIGH : LOW);
  ledState = state;
}

// =============================================================================
// ESP-NOW FUNCTIONS
// =============================================================================

void OnDataSent(const wifi_tx_info_t *tx_info, esp_now_send_status_t status) {
  printMessage("Send Status: ", status == ESP_NOW_SEND_SUCCESS ? MSG_ACK : MSG_PING);
  
  if (status == ESP_NOW_SEND_SUCCESS) {
    Serial.println("Message sent successfully");
    retryCount = 0;
    lastActivity = millis();
    receiverConnected = true;
    // Don't change LED state here - let button handlers manage it
  } else {
    Serial.println("Message send failed");
    receiverConnected = false;
    if (retryCount < MAX_RETRIES) {
      retryCount++;
      delay(RETRY_DELAY_MS);
      // Resend the message
      esp_now_send(RX_MAC, (uint8_t*)&message, sizeof(message));
    } else {
      Serial.println("Max retries reached, giving up");
      retryCount = 0;
    }
  }
}

void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
  if (len == sizeof(message)) {
    memcpy(&message, incomingData, sizeof(message));
    
    Serial.print("Received from: ");
    printMacAddress((uint8_t*)recv_info->src_addr);
    printMessage("", message.msgType, message.button);
    
    if (message.msgType == MSG_ACK) {
      Serial.println("Received ACK");
      lastActivity = millis();
      receiverConnected = true;
      // Don't change LED state here - let main loop manage it
    }
  }
}

bool sendMessage(uint8_t msgType, uint8_t button = 0) {
  message.msgType = msgType;
  message.button = button;
  message.retryCount = retryCount;
  message.timestamp = millis();
  
  printMessage("Sending: ", msgType, button);
  
  esp_err_t result = esp_now_send(RX_MAC, (uint8_t*)&message, sizeof(message));
  
  if (result != ESP_OK) {
    Serial.print("ESP-NOW send failed: ");
    Serial.println(result);
    return false;
  }
  
  return true;
}

// =============================================================================
// BUTTON HANDLING FUNCTIONS
// =============================================================================

void updateButton(ButtonState& btn, uint8_t buttonNum, uint8_t pin) {
  uint32_t now = millis();
  bool currentState = !digitalRead(pin); // Inverted because buttons pull to GND
  
  // Debounce logic
  if (currentState != btn.pressed) {
    btn.lastDebounce = now;
  }
  
  if ((now - btn.lastDebounce) > DEBOUNCE_TIME_MS) {
    if (currentState && !btn.pressed) {
      // Button pressed
      btn.pressed = true;
      btn.pressTime = now;
      btn.holdDetected = false;
      btn.processed = false;
      Serial.print("Button ");
      Serial.print(buttonNum);
      Serial.println(" pressed");
    } else if (!currentState && btn.pressed) {
      // Button released
      btn.pressed = false;
      uint32_t pressDuration = now - btn.pressTime;
      
      Serial.print("Button ");
      Serial.print(buttonNum);
      Serial.print(" released after ");
      Serial.print(pressDuration);
      Serial.println(" ms");
      
      if (!btn.holdDetected && !btn.processed) {
        // Send regular button press
        sendMessage(MSG_BTN, buttonNum);
        btn.processed = true;
        // LED will be handled by updateLED() based on button state
        Serial.print("Button ");
        Serial.print(buttonNum);
        Serial.println(" press detected");
      }
    }
    
    // Check for hold detection
    if (btn.pressed && !btn.holdDetected && !btn.processed) {
      if ((now - btn.pressTime) >= HOLD_DELAY_MS) {
        btn.holdDetected = true;
        btn.processed = true;
        Serial.print("Button ");
        Serial.print(buttonNum);
        Serial.println(" hold detected");
        sendMessage(MSG_BTN_HOLD, buttonNum);
        // Set LED to button hold state
        setLEDState(LED_BUTTON_HOLD);
      }
    }
  }
}

// =============================================================================
// POWER MANAGEMENT FUNCTIONS
// =============================================================================

void enterLightSleep() {
  Serial.println("Entering light sleep...");
  setLEDState(LED_LIGHT_SLEEP);
  
  // Configure wake-up sources for ESP32C3
  esp_deep_sleep_enable_gpio_wakeup((1ULL << BTN1_PIN) | (1ULL << BTN2_PIN), ESP_GPIO_WAKEUP_GPIO_LOW);
  
  // Enter light sleep
  esp_light_sleep_start();
  
  Serial.println("Woke up from light sleep");
  lastActivity = millis();
}

void enterDeepSleep() {
  Serial.println("Entering deep sleep...");
  setLEDState(LED_DEEP_SLEEP);
  
  // Configure wake-up sources for ESP32C3
  esp_deep_sleep_enable_gpio_wakeup((1ULL << BTN1_PIN) | (1ULL << BTN2_PIN), ESP_GPIO_WAKEUP_GPIO_LOW);
  
  // Enter deep sleep
  esp_deep_sleep_start();
}

void checkPowerManagement() {
  uint32_t now = millis();
  uint32_t idleTime = now - lastActivity;
  
  if (idleTime >= IDLE_DEEP_MS) {
    enterDeepSleep();
  } else if (idleTime >= IDLE_LIGHT_MS) {
    enterLightSleep();
  }
}

// =============================================================================
// MAIN SETUP AND LOOP
// =============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== WRB ESP32 Transmitter Starting ===");
  
  // Initialize pins
  pinMode(LED_PIN, OUTPUT);
  pinMode(BTN1_PIN, INPUT_PULLUP);
  pinMode(BTN2_PIN, INPUT_PULLUP);
  
  // Initialize button states
  btn1.pressed = false;
  btn1.holdDetected = false;
  btn1.processed = false;
  btn2.pressed = false;
  btn2.holdDetected = false;
  btn2.processed = false;
  
  // Initialize LED
  setLED(true);
  delay(500);
  setLED(false);
  
  // Initialize WiFi
  WiFi.mode(WIFI_STA);
  Serial.print("Transmitter MAC: ");
  Serial.println(WiFi.macAddress());
  
  // Initialize ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW initialization failed");
    return;
  }
  
  // Register callbacks
  esp_now_register_send_cb(OnDataSent);
  esp_now_register_recv_cb(OnDataRecv);
  
  // Add receiver peer
  esp_now_peer_info_t peerInfo;
  memcpy(peerInfo.peer_addr, RX_MAC, 6);
  peerInfo.channel = 1;
  peerInfo.encrypt = false;
  
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add peer");
    return;
  }
  
  Serial.print("Added peer: ");
  printMacAddress(RX_MAC);
  
  // Send initial ping
  sendMessage(MSG_PING);
  
  espnowReady = true;
  lastActivity = millis();
  
  Serial.println("Transmitter ready!");
}

void loop() {
  if (!espnowReady) {
    delay(1000);
    return;
  }
  
  uint32_t now = millis();
  
  // Update buttons
  updateButton(btn1, 1, BTN1_PIN);
  updateButton(btn2, 2, BTN2_PIN);
  
  // Send periodic ping
  if (now - lastPing >= 5000) { // Every 5 seconds
    sendMessage(MSG_PING);
    lastPing = now;
  }
  
  // Update LED status (simplified direct control)
  updateLED();
  
  // Check power management
  checkPowerManagement();
  
  // Small delay to prevent overwhelming the system
  delay(10);
}
