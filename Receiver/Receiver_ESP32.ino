/*
 * WRB ESP32 Receiver
 * Seeed Studio XIAO ESP32C3 Wireless Button System
 * 
 * Features:
 * - Multi-transmitter support (up to 10 devices)
 * - Message parsing (button, hold, ping, ack)
 * - LED feedback for connection status
 * - Serial output for debugging and monitoring
 * - Security validation (MAC address checking)
 * - Error handling for malformed messages
 */

#include <esp_now.h>
#include <WiFi.h>

// =============================================================================
// CONFIGURATION SECTION
// =============================================================================

// Pin Configuration
#define LED_PIN D10

// Timing Configuration
const uint32_t PING_INTERVAL_MS = 500;        // Ping interval
const uint32_t LINK_TIMEOUT_MS = 4000;        // Link timeout
const uint8_t MAX_TRANSMITTERS = 10;          // Max transmitters

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

struct TransmitterInfo {
  uint8_t mac[6];
  uint32_t lastSeen;
  bool active;
  uint8_t buttonCount;
} transmitters[MAX_TRANSMITTERS];

// Allowed Transmitter MACs (add your transmitter MACs here)
uint8_t ALLOWED_TX_MACS[][6] = {
  { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAC }, // Transmitter 1
  { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAD }, // Transmitter 2
  { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAE }, // Transmitter 3
  // Add more transmitters as needed
};

const uint8_t ALLOWED_COUNT = sizeof(ALLOWED_TX_MACS) / sizeof(ALLOWED_TX_MACS[0]);

// System state
bool espnowReady = false;
uint32_t lastLEDUpdate = 0;
bool ledState = false;
uint8_t activeTransmitters = 0;
uint32_t lastStatusUpdate = 0;

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

bool isAllowedTransmitter(uint8_t* mac) {
  for (int i = 0; i < ALLOWED_COUNT; i++) {
    if (memcmp(mac, ALLOWED_TX_MACS[i], 6) == 0) {
      return true;
    }
  }
  return false;
}

int findTransmitter(uint8_t* mac) {
  for (int i = 0; i < MAX_TRANSMITTERS; i++) {
    if (memcmp(transmitters[i].mac, mac, 6) == 0) {
      return i;
    }
  }
  return -1;
}

int addTransmitter(uint8_t* mac) {
  for (int i = 0; i < MAX_TRANSMITTERS; i++) {
    if (!transmitters[i].active) {
      memcpy(transmitters[i].mac, mac, 6);
      transmitters[i].lastSeen = millis();
      transmitters[i].active = true;
      transmitters[i].buttonCount = 0;
      activeTransmitters++;
      
      Serial.print("Added transmitter: ");
      printMacAddress(mac);
      Serial.print(" (Total active: ");
      Serial.print(activeTransmitters);
      Serial.println(")");
      
      return i;
    }
  }
  return -1;
}

void updateTransmitter(int index) {
  if (index >= 0 && index < MAX_TRANSMITTERS) {
    transmitters[index].lastSeen = millis();
  }
}

void removeInactiveTransmitters() {
  uint32_t now = millis();
  for (int i = 0; i < MAX_TRANSMITTERS; i++) {
    if (transmitters[i].active && (now - transmitters[i].lastSeen) > LINK_TIMEOUT_MS) {
      Serial.print("Removing inactive transmitter: ");
      printMacAddress(transmitters[i].mac);
      Serial.println();
      
      transmitters[i].active = false;
      activeTransmitters--;
    }
  }
}

void updateLED() {
  uint32_t now = millis();
  
  if (activeTransmitters > 0) {
    // Blink LED when transmitters are active
    if (now - lastLEDUpdate >= 500) { // 500ms blink interval
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState);
      lastLEDUpdate = now;
    }
  } else {
    // Solid LED when no transmitters
    digitalWrite(LED_PIN, HIGH);
    ledState = true;
  }
}

void setLED(bool state) {
  digitalWrite(LED_PIN, state);
  ledState = state;
}

// =============================================================================
// ESP-NOW FUNCTIONS
// =============================================================================

void OnDataRecv(const uint8_t *mac, const uint8_t *incomingData, int len) {
  Serial.print("Received from: ");
  printMacAddress((uint8_t*)mac);
  Serial.print(" (");
  Serial.print(len);
  Serial.print(" bytes) - ");
  
  // Check if transmitter is allowed
  if (!isAllowedTransmitter((uint8_t*)mac)) {
    Serial.println("REJECTED - Unauthorized transmitter");
    return;
  }
  
  // Validate message length
  if (len != sizeof(message)) {
    Serial.print("REJECTED - Invalid message length: ");
    Serial.println(len);
    return;
  }
  
  // Copy and validate message
  memcpy(&message, incomingData, sizeof(message));
  
  // Find or add transmitter
  int txIndex = findTransmitter((uint8_t*)mac);
  if (txIndex == -1) {
    txIndex = addTransmitter((uint8_t*)mac);
    if (txIndex == -1) {
      Serial.println("REJECTED - Too many transmitters");
      return;
    }
  } else {
    updateTransmitter(txIndex);
  }
  
  // Process message
  switch (message.msgType) {
    case MSG_PING:
      Serial.println("PING");
      // Send ACK back
      esp_now_send(mac, (uint8_t*)&message, sizeof(message));
      break;
      
    case MSG_BTN:
      Serial.print("BTN");
      Serial.print(message.button);
      Serial.println(" - Button press detected");
      
      // Output to serial for Raspberry Pi
      Serial.print("BTN");
      Serial.println(message.button);
      
      transmitters[txIndex].buttonCount++;
      break;
      
    case MSG_BTN_HOLD:
      Serial.print("HOLD");
      Serial.print(message.button);
      Serial.println(" - Button hold detected");
      
      // Output to serial for Raspberry Pi
      Serial.print("HOLD");
      Serial.println(message.button);
      
      transmitters[txIndex].buttonCount++;
      break;
      
    default:
      Serial.print("UNKNOWN message type: 0x");
      Serial.println(message.msgType, HEX);
      break;
  }
}

void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  if (status == ESP_NOW_SEND_SUCCESS) {
    Serial.println("ACK sent successfully");
  } else {
    Serial.println("ACK send failed");
  }
}

// =============================================================================
// STATUS AND MONITORING FUNCTIONS
// =============================================================================

void printStatus() {
  Serial.println("\n=== Receiver Status ===");
  Serial.print("Active transmitters: ");
  Serial.println(activeTransmitters);
  Serial.print("ESP-NOW ready: ");
  Serial.println(espnowReady ? "Yes" : "No");
  Serial.print("Uptime: ");
  Serial.print(millis() / 1000);
  Serial.println(" seconds");
  
  Serial.println("\nTransmitter Details:");
  for (int i = 0; i < MAX_TRANSMITTERS; i++) {
    if (transmitters[i].active) {
      Serial.print("  ");
      printMacAddress(transmitters[i].mac);
      Serial.print(" - Buttons: ");
      Serial.print(transmitters[i].buttonCount);
      Serial.print(" - Last seen: ");
      Serial.print((millis() - transmitters[i].lastSeen) / 1000);
      Serial.println("s ago");
    }
  }
  Serial.println("=======================\n");
}

// =============================================================================
// MAIN SETUP AND LOOP
// =============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== WRB ESP32 Receiver Starting ===");
  
  // Initialize pins
  pinMode(LED_PIN, OUTPUT);
  
  // Initialize LED
  setLED(true);
  delay(1000);
  setLED(false);
  
  // Initialize transmitter array
  for (int i = 0; i < MAX_TRANSMITTERS; i++) {
    transmitters[i].active = false;
    transmitters[i].buttonCount = 0;
  }
  
  // Initialize WiFi
  WiFi.mode(WIFI_STA);
  Serial.print("Receiver MAC: ");
  Serial.println(WiFi.macAddress());
  
  // Print allowed transmitters
  Serial.println("Allowed transmitters:");
  for (int i = 0; i < ALLOWED_COUNT; i++) {
    Serial.print("  ");
    printMacAddress((uint8_t*)ALLOWED_TX_MACS[i]);
    Serial.println();
  }
  
  // Initialize ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW initialization failed");
    return;
  }
  
  // Register callbacks
  esp_now_register_recv_cb(OnDataRecv);
  esp_now_register_send_cb(OnDataSent);
  
  espnowReady = true;
  lastStatusUpdate = millis();
  
  Serial.println("Receiver ready!");
  Serial.println("Waiting for transmitter messages...");
}

void loop() {
  if (!espnowReady) {
    delay(1000);
    return;
  }
  
  uint32_t now = millis();
  
  // Update LED status
  updateLED();
  
  // Remove inactive transmitters
  removeInactiveTransmitters();
  
  // Print status every 30 seconds
  if (now - lastStatusUpdate >= 30000) {
    printStatus();
    lastStatusUpdate = now;
  }
  
  // Small delay to prevent overwhelming the system
  delay(10);
}
