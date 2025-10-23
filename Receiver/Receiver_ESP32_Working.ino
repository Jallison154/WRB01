/*
 * WRB Receiver - Working Version
 * Simple ESP-NOW communication with LED status
 */

#include <WiFi.h>
#include <esp_now.h>

// =============================================================================
// CONFIGURATION
// =============================================================================

// Allowed Transmitter MACs
uint8_t ALLOWED_TX_MACS[][6] = {
  { 0x58, 0x8C, 0x81, 0x9F, 0x22, 0xAC }, // Transmitter 1
};

const uint8_t ALLOWED_COUNT = sizeof(ALLOWED_TX_MACS) / sizeof(ALLOWED_TX_MACS[0]);

// Pin Configuration
#define LED_PIN D10

// Message Types
#define MSG_PING 0xA0
#define MSG_ACK 0xA1
#define MSG_BTN 0xB0
#define MSG_BTN_HOLD 0xB1

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
bool espnowReady = false;
uint32_t lastStatusUpdate = 0;
uint32_t breathingPhase = 0;
uint32_t lastBtnActivityMs = 0;
uint32_t lastHoldActivityMs = 0;
int activeTransmitters = 0;

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

bool isAllowedTransmitter(uint8_t* mac) {
  for (int i = 0; i < ALLOWED_COUNT; i++) {
    if (memcmp(mac, ALLOWED_TX_MACS[i], 6) == 0) {
      return true;
    }
  }
  return false;
}

// =============================================================================
// LED FUNCTIONS
// =============================================================================

void updateLED() {
  uint32_t now = millis();
  
  // Check for recent button activity (1 second after button press)
  bool recentActivity = (now - lastBtnActivityMs) < 1000;
  bool recentHoldActivity = (now - lastHoldActivityMs) < 800;
  
  if (recentHoldActivity) {
    // Double blink for hold commands
    uint32_t t = now % 600;
    if (t < 100) { 
      analogWrite(LED_PIN, 255); // First blink on
      return; 
    }
    if (t < 150) { 
      analogWrite(LED_PIN, 0);   // First blink off
      return; 
    }
    if (t < 250) { 
      analogWrite(LED_PIN, 255); // Second blink on
      return; 
    }
    analogWrite(LED_PIN, 0);     // Second blink off
  } else if (recentActivity) {
    // 100% brightness for recent button activity
    analogWrite(LED_PIN, 255);
  } else if (activeTransmitters > 0) {
    // 25% brightness when transmitters connected
    analogWrite(LED_PIN, 64);
  } else {
    // Breathing effect when no transmitters (3 second cycle)
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

void OnDataRecv(const uint8_t *mac, const uint8_t *incomingData, int len) {
  if (len == sizeof(message)) {
    memcpy(&message, incomingData, sizeof(message));
    
    Serial.print("Received from: ");
    printMacAddress((uint8_t*)mac);
    printMessage("", message.msgType, message.button);
    
    // Check if transmitter is allowed
    if (!isAllowedTransmitter((uint8_t*)mac)) {
      Serial.println("Unauthorized transmitter!");
      return;
    }
    
    // Process message
    switch (message.msgType) {
      case MSG_PING:
        Serial.println("PING received - sending ACK");
        // Send ACK back
        esp_now_send(mac, (uint8_t*)&message, sizeof(message));
        Serial.println("ACK sent");
        activeTransmitters = 1; // Mark as connected
        break;
        
      case MSG_BTN:
        Serial.print("BTN");
        Serial.print(message.button);
        Serial.println(" - Button press detected");
        
        // Output to serial for Raspberry Pi
        Serial.print("BTN");
        Serial.println(message.button);
        
        // Set button activity timestamp
        lastBtnActivityMs = millis();
        break;
        
      case MSG_BTN_HOLD:
        Serial.print("HOLD");
        Serial.print(message.button);
        Serial.println(" - Button hold detected");
        
        // Output to serial for Raspberry Pi
        Serial.print("HOLD");
        Serial.println(message.button);
        
        // Set hold activity timestamp
        lastHoldActivityMs = millis();
        break;
        
      default:
        Serial.print("UNKNOWN message type: 0x");
        Serial.println(message.msgType, HEX);
        break;
    }
  }
}

void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  Serial.print("Send Status: ");
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "Success" : "Failed");
}

// =============================================================================
// MAIN FUNCTIONS
// =============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== WRB Receiver ===");
  
  // Initialize pins
  pinMode(LED_PIN, OUTPUT);
  
  // Initialize LED
  analogWrite(LED_PIN, 0);
  
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
  
  // Add allowed transmitters as peers
  for (int i = 0; i < ALLOWED_COUNT; i++) {
    esp_now_peer_info_t peerInfo;
    memcpy(peerInfo.peer_addr, ALLOWED_TX_MACS[i], 6);
    peerInfo.channel = 1;
    peerInfo.encrypt = false;
    
    if (esp_now_add_peer(&peerInfo) != ESP_OK) {
      Serial.print("Failed to add peer: ");
      printMacAddress((uint8_t*)ALLOWED_TX_MACS[i]);
      Serial.println();
    } else {
      Serial.print("Added peer: ");
      printMacAddress((uint8_t*)ALLOWED_TX_MACS[i]);
      Serial.println();
    }
  }
  
  espnowReady = true;
  lastStatusUpdate = millis();
  
  Serial.println("Receiver ready!");
  Serial.println("Waiting for transmitter messages...");
}

void loop() {
  if (!espnowReady) {
    return;
  }
  
  uint32_t now = millis();
  
  // Update LED status
  updateLED();
  
  // Print status every 30 seconds
  if (now - lastStatusUpdate >= 30000) {
    Serial.print("Status: Active transmitters: ");
    Serial.println(activeTransmitters);
    lastStatusUpdate = now;
  }
  
  // Reset active transmitters if no activity for 10 seconds
  if (now - lastBtnActivityMs >= 10000 && now - lastHoldActivityMs >= 10000) {
    activeTransmitters = 0;
  }
  
  delay(10);
}
