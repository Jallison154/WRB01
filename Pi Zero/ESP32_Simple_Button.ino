/*
 * Simple ESP32 Button System
 * Button press → Send "BUTTON1" or "BUTTON2" via serial
 */

// Button pins
#define BUTTON1_PIN 2
#define BUTTON2_PIN 4

// Button state tracking
bool button1Pressed = false;
bool button2Pressed = false;

void setup() {
  Serial.begin(115200);
  
  // Setup button pins
  pinMode(BUTTON1_PIN, INPUT_PULLUP);
  pinMode(BUTTON2_PIN, INPUT_PULLUP);
  
  Serial.println("Simple Button System Ready");
}

void loop() {
  // Check Button 1
  if (digitalRead(BUTTON1_PIN) == LOW && !button1Pressed) {
    button1Pressed = true;
    Serial.println("BUTTON1");
    delay(100); // Debounce
  }
  if (digitalRead(BUTTON1_PIN) == HIGH) {
    button1Pressed = false;
  }
  
  // Check Button 2
  if (digitalRead(BUTTON2_PIN) == LOW && !button2Pressed) {
    button2Pressed = true;
    Serial.println("BUTTON2");
    delay(100); // Debounce
  }
  if (digitalRead(BUTTON2_PIN) == HIGH) {
    button2Pressed = false;
  }
  
  delay(10); // Small delay
}
