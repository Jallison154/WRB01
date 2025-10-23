/*
 * WRB Transmitter - Working Version
 * Simple ESP-NOW communication with LED status
 */

#include <WiFi.h>
#include <esp_now.h>

// =============================================================================
// CONFIGURATION
// =============================================================================

// MAC Address Configuration
uint8_t RX_MAC[] = { 0x58, 0x8C, 0x81, 0x9E, 0x30, 0x10 };

// Pin Configuration
#define LED_PIN D10
#define BTN1_PIN D1
#define BTN2_PIN D2

// Message Types
#define MSG_PING 0xA0
#define MSG_ACK 0xA1
#define MSG_BTN 0xB0
#define MSG_BTN_HOLD 0xB1

// Timing
#define PING_INTERVAL 5000
#define HOLD_THRESHOLD 800

// =============================================================================
// GLOBAL VARIABLES
// =============================================================================

// Message structure
typedef struct {
  uint8_t msgType;
  uint8_t button;
  uint32_t timestamp;
} Message;

Message message;
bool receiverConnected = false;
uint32_t lastPing = 0;
uint32_t lastActivity = 0;
uint32_t breathingPhase = 0;

// Button states
struct Button {
  bool pressed;
  bool lastState;
  uint32_t pressTime;
  bool holdSent;
};

Button btn1 = {false, true, 0, false};
Button btn2 = {false, true, 0, false};

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

void printMacAddress(uint8_t* mac) {
  for (int i = 0; i < 6; i++) {
    if (i > 0) Serial.print(":");
    if (mac[i] < 16) Serial.print("0");
    Serial.print(mac[i], HEX);
  }
}

void printMessage(const char* prefix, uint8_t msgType, uint8_t button) {
  Serial.print(prefix);
  Serial.print("Type: 0x");
  Serial.print(msgType, HEX);
  if (button > 0) {
    Serial.print(", Button: ");
    Serial.print(button);
  }
  Serial.println();
}

// =============================================================================
// LED FUNCTIONS
// =============================================================================

void updateLED() {
  uint32_t now = millis();
  
  // Check if any button is currently pressed
  bool anyButtonPressed = !digitalRead(BTN1_PIN) || !digitalRead(BTN2_PIN);
  
  if (anyButtonPressed) {
    // Button is pressed - 100% brightness
    analogWrite(LED_PIN, 255);
    return;
  }
  
  // No button pressed - check connection state
  if (receiverConnected) {
    // Connected - 25% brightness
    analogWrite(LED_PIN, 64);
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
  }
}

// =============================================================================
// ESP-NOW FUNCTIONS
// =============================================================================

void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  Serial.print("Send Status: ");
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "Success" : "Failed");
  
  if (status == ESP_NOW_SEND_SUCCESS) {
    lastActivity = millis();
  }
}

void OnDataRecv(const uint8_t *mac, const uint8_t *incomingData, int len) {
  if (len == sizeof(message)) {
    memcpy(&message, incomingData, sizeof(message));
    
    Serial.print("Received from: ");
    printMacAddress((uint8_t*)mac);
    printMessage("", message.msgType, message.button);
    
    if (message.msgType == MSG_ACK) {
      Serial.println("Received ACK - connection established!");
      lastActivity = millis();
      receiverConnected = true;
    }
  }
}

bool sendMessage(uint8_t msgType, uint8_t button = 0) {
  message.msgType = msgType;
  message.button = button;
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
// BUTTON FUNCTIONS
// =============================================================================

void updateButton(Button &btn, uint8_t buttonNum, uint8_t pin) {
  bool currentState = !digitalRead(pin); // Inverted logic (pressed = LOW)
  
  if (currentState != btn.lastState) {
    btn.lastState = currentState;
    
    if (currentState) {
      // Button pressed
      btn.pressed = true;
      btn.pressTime = millis();
      btn.holdSent = false;
      Serial.print("Button ");
      Serial.print(buttonNum);
      Serial.println(" pressed");
    } else {
      // Button released
      if (btn.pressed) {
        uint32_t pressDuration = millis() - btn.pressTime;
        
        if (pressDuration < HOLD_THRESHOLD) {
          // Quick press
          Serial.print("Button ");
          Serial.print(buttonNum);
          Serial.println(" quick press");
          sendMessage(MSG_BTN, buttonNum);
        } else {
          // Hold
          Serial.print("Button ");
          Serial.print(buttonNum);
          Serial.println(" hold");
          sendMessage(MSG_BTN_HOLD, buttonNum);
        }
        
        btn.pressed = false;
      }
    }
  }
  
  // Check for hold while pressed
  if (btn.pressed && !btn.holdSent) {
    if (millis() - btn.pressTime >= HOLD_THRESHOLD) {
      Serial.print("Button ");
      Serial.print(buttonNum);
      Serial.println(" hold detected");
      sendMessage(MSG_BTN_HOLD, buttonNum);
      btn.holdSent = true;
    }
  }
}

// =============================================================================
// MAIN FUNCTIONS
// =============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== WRB Transmitter ===");
  
  // Initialize pins
  pinMode(LED_PIN, OUTPUT);
  pinMode(BTN1_PIN, INPUT_PULLUP);
  pinMode(BTN2_PIN, INPUT_PULLUP);
  
  // Initialize LED
  analogWrite(LED_PIN, 0);
  
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
  
  Serial.println("Transmitter ready!");
}

void loop() {
  uint32_t now = millis();
  
  // Check connection timeout
  if (now - lastActivity >= 10000) {
    receiverConnected = false;
  }
  
  // Send periodic ping
  if (now - lastPing >= PING_INTERVAL) {
    sendMessage(MSG_PING);
    lastPing = now;
  }
  
  // Update buttons
  updateButton(btn1, 1, BTN1_PIN);
  updateButton(btn2, 2, BTN2_PIN);
  
  // Update LED
  updateLED();
  
  delay(10);
}
