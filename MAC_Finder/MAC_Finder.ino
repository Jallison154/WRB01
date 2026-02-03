/*
 * WRB MAC Address Finder
 * Utility to find MAC addresses of ESP32 devices
 * 
 * Upload this to your ESP32 devices to find their MAC addresses
 * for configuration in the main WRB system.
 */

#include <WiFi.h>

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== WRB MAC Address Finder ===");
  Serial.println();
  
  // Initialize WiFi to get MAC address
  WiFi.mode(WIFI_STA);
  
  // Get and display MAC address
  String macAddress = WiFi.macAddress();
  
  Serial.println("Device Information:");
  Serial.println("==================");
  Serial.print("MAC Address: ");
  Serial.println(macAddress);
  
  // Convert to byte array format for easy copying
  Serial.println();
  Serial.println("For use in WRB configuration:");
  Serial.println("=============================");
  
  // Parse MAC address and convert to byte array format
  String macStr = macAddress;
  macStr.replace(":", "");
  
  Serial.print("Byte Array Format: ");
  Serial.print("{ 0x");
  for (int i = 0; i < 12; i += 2) {
    if (i > 0) Serial.print(", 0x");
    Serial.print(macStr.substring(i, i + 2));
  }
  Serial.println(" }");
  
  // Also show as individual bytes
  Serial.println();
  Serial.println("Individual Bytes:");
  Serial.println("================");
  for (int i = 0; i < 12; i += 2) {
    String byteStr = macStr.substring(i, i + 2);
    Serial.print("Byte ");
    Serial.print(i / 2);
    Serial.print(": 0x");
    Serial.print(byteStr);
    Serial.print(" (");
    Serial.print(byteStr);
    Serial.println(")");
  }
  
  Serial.println();
  Serial.println("Copy the byte array format above for use in your WRB configuration.");
  Serial.println("This MAC address can be used in:");
  Serial.println("- Receiver ESP32: ALLOWED_TX_MACS array");
  Serial.println("- Transmitter ESP32: RX_MAC array");
  Serial.println();
  Serial.println("Press RESET to run again or upload different code.");
}

void loop() {
  // Nothing to do in loop
  delay(1000);
}
