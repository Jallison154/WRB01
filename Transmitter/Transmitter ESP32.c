#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <esp_sleep.h>
#include "driver/gpio.h"   // <-- needed for gpio_wakeup_enable()

// ---------- Pins (use Dx aliases) ----------
#define LED_PIN  D10               // status LED on header D10
const bool LED_ACTIVE_LOW = false; // set true if LED looks inverted

#define BTN1_PIN D1                // button 1 on header D1 -> GND
#define BTN2_PIN D2                // button 2 on header D2 -> GND
const bool USE_BTN2 = true;
const bool BTN_ACTIVE_LOW = true;  // true = button to GND with INPUT_PULLUP

// ---------- Peer (Receiver) MAC ----------
uint8_t RX_MAC[] = { 0x58,0x8C,0x81,0x9E,0x30,0x10 }; // <-- your RX MAC (58:8c:81:9e:30:10)

// ---------- Messages ----------
enum : uint8_t { MSG_PING=0xA0, MSG_ACK=0xA1, MSG_BTN=0xB0, MSG_BTN_HOLD=0xB1 };

// ---------- Link / timing ----------
uint32_t lastAckMs = 0;
bool linked = false;

// ---------- Power policy ----------
const bool     ENABLE_SLEEP     = true;
// go to LIGHT sleep at 5 min idle, DEEP sleep at 15 min idle
const uint32_t IDLE_LIGHT_MS    = 5UL  * 60UL * 1000UL;  // 5 minutes
const uint32_t IDLE_DEEP_MS     = 15UL * 60UL * 1000UL;  // 15 minutes
uint32_t lastActivityMs         = 0;

// Light-sleep breathing parameters
const uint32_t BREATH_PERIOD_MS = 2000;   // 2s up/down
const uint8_t  BREATH_MAX_RAW   = 51;     // ~20% of 255

// Transmission retry parameters
const uint8_t  MAX_RETRIES      = 3;
const uint16_t RETRY_DELAY_MS   = 50;

// Wake cause (for logging only; we do NOT send on deep wake anymore)
esp_sleep_wakeup_cause_t wakeCause = ESP_SLEEP_WAKEUP_UNDEFINED;

// ---------- Button debouncer ----------
struct BtnDeb {
  uint8_t pin;
  bool activeLow;
  int lastLevel;
  uint32_t lastFlip;
  bool armed;
  bool pressed;           // Track if button is currently pressed
  uint32_t pressStartMs; // When button was first pressed
  bool holdSent;          // Whether we've already sent the hold message
};
const uint16_t DEBOUNCE_MS = 40;
const uint16_t HOLD_DELAY_MS = 500;  // 500ms to trigger hold
BtnDeb b1{BTN1_PIN, BTN_ACTIVE_LOW, HIGH, 0, true, false, 0, false};
BtnDeb b2{BTN2_PIN, BTN_ACTIVE_LOW, HIGH, 0, true, false, 0, false};

bool pressEvent(BtnDeb& b){
  int lvl = digitalRead(b.pin);
  uint32_t now = millis();
  if (lvl != b.lastLevel){ b.lastLevel = lvl; b.lastFlip = now; }
  bool active = b.activeLow ? (lvl==LOW) : (lvl==HIGH);
  
  if (!active && b.pressed) {
    // Button released
    b.pressed = false;
    b.armed = true;
    // Don't reset holdSent here - we need to track if hold was sent
    return false;
  }
  
  if (active && !b.pressed && b.armed && (now - b.lastFlip) > DEBOUNCE_MS) {
    // Button pressed
    b.pressed = true;
    b.pressStartMs = now;
    b.armed = false;
    b.holdSent = false;  // Reset hold flag for new press
    return true;
  }
  
  return false;
}

bool checkHoldEvent(BtnDeb& b) {
  if (!b.pressed || b.holdSent) return false;
  
  uint32_t now = millis();
  if ((now - b.pressStartMs) >= HOLD_DELAY_MS) {
    b.holdSent = true;
    return true;
  }
  return false;
}

bool isBtnActive(uint8_t pin){
  int lvl = digitalRead(pin);
  return BTN_ACTIVE_LOW ? (lvl == LOW) : (lvl == HIGH);
}

// ---------- LED helpers ----------
inline void ledWriteRaw(uint8_t v){ if(LED_ACTIVE_LOW) v = 255 - v; analogWrite(LED_PIN, v); }
inline void ledOn(){     ledWriteRaw(255); } // 100% when a button is held
inline void ledLinked(){ ledWriteRaw(64);  } // ~25% when linked
inline void ledOff(){    ledWriteRaw(0);   } // off

void showNoLinkBreathing(uint32_t now){
  // Create a smooth breathing animation between 0% and 25% brightness
  // Using a sine wave with 3 second period (3000ms)
  float phase = (now % 3000) / 3000.0f * 2.0f * PI;
  float sine = sin(phase);
  
  // Map sine wave (-1 to 1) to brightness range (0% to 25%)
  // sine goes from -1 to 1, we want 0.0 to 0.25
  // (sine + 1) / 2 goes from 0 to 1
  // Then scale to 0.0 to 0.25: 0.0 + (0.25 - 0.0) * value
  float brightness = 0.25f * ((sine + 1.0f) / 2.0f);
  
  // Convert to 0-255 range and write to LED
  uint8_t ledValue = (uint8_t)(brightness * 255);
  ledWriteRaw(ledValue);
}


void ledTask(){
  uint32_t now = millis();
  bool anyLocalHeld = b1.pressed || (USE_BTN2 && b2.pressed);
  
  if (anyLocalHeld) {
    ledOn();               // 100% while a button is held
  } else if (linked) {
    ledLinked();           // 25% when linked
  } else {
    showNoLinkBreathing(now);  // Breathing animation when no links
  }
}

// ---------- ESP-NOW handlers ----------
void onRecv(const esp_now_recv_info_t* info, const uint8_t* data, int len){
  if (!data || len <= 0) return;
  if (data[0] == MSG_ACK){
    lastAckMs = millis();  // link health only (DO NOT touch lastActivityMs)
  }
}

void addPeer(const uint8_t mac[6], uint8_t channel=1){
  esp_now_peer_info_t p{};
  memcpy(p.peer_addr, mac, 6);
  p.channel = channel; p.encrypt = false; p.ifidx = WIFI_IF_STA;
  esp_now_del_peer(mac);
  esp_now_add_peer(&p);
}

void sendPing(){
  uint8_t m = MSG_PING;
  esp_err_t result = esp_now_send(RX_MAC, &m, 1);
  if (result != ESP_OK) {
    Serial.println("TX: Ping failed to send");
  }
}

void sendBtn(uint8_t id){
  uint8_t m[2] = { MSG_BTN, id };
  
  // Retry mechanism for better reliability
  for (uint8_t retry = 0; retry < MAX_RETRIES; retry++) {
    esp_err_t result = esp_now_send(RX_MAC, m, sizeof(m));
    if (result == ESP_OK) {
      Serial.printf("TX: BTN%u pressed (local) - sent\n", id);
      lastActivityMs = millis(); // reset idle timer on local activity
      return;
    }
    if (retry < MAX_RETRIES - 1) {
      delay(RETRY_DELAY_MS);
    }
  }
  Serial.printf("TX: BTN%u failed to send after %d retries\n", id, MAX_RETRIES);
}

void sendBtnHold(uint8_t id){
  uint8_t m[2] = { MSG_BTN_HOLD, id };
  
  // Retry mechanism for better reliability
  for (uint8_t retry = 0; retry < MAX_RETRIES; retry++) {
    esp_err_t result = esp_now_send(RX_MAC, m, sizeof(m));
    if (result == ESP_OK) {
      Serial.printf("TX: BTN%u held (local) - sent\n", id);
      lastActivityMs = millis(); // reset idle timer on local activity
      return;
    }
    if (retry < MAX_RETRIES - 1) {
      delay(RETRY_DELAY_MS);
    }
  }
  Serial.printf("TX: BTN%u hold failed to send after %d retries\n", id, MAX_RETRIES);
}

// ---------- Sleep helpers ----------
// Light sleep: enable GPIO wake on LOW using the new API pattern (IDF v5).
void enableGpioWakeLow_Light(){
  gpio_wakeup_enable((gpio_num_t)BTN1_PIN, GPIO_INTR_LOW_LEVEL);
  if (USE_BTN2) gpio_wakeup_enable((gpio_num_t)BTN2_PIN, GPIO_INTR_LOW_LEVEL);
  esp_sleep_enable_gpio_wakeup(); // no args in IDF v5
}

// Deep sleep: keep using mask+level helper (still valid).
uint64_t gpioWakeMask(){
  uint64_t mask = (1ULL << BTN1_PIN);
  if (USE_BTN2) mask |= (1ULL << BTN2_PIN);
  return mask;
}
void enableGpioWakeLow_Deep(){
  esp_deep_sleep_disable_rom_logging(); // optional: quieter boot logs
  esp_deep_sleep_enable_gpio_wakeup(gpioWakeMask(), ESP_GPIO_WAKEUP_GPIO_LOW);
}

void goToDeepSleep(){
  Serial.println("Entering DEEP sleep… (wake on D1/D2 LOW)");
  ledOff();
  pinMode(BTN1_PIN, INPUT_PULLUP);
  if (USE_BTN2) pinMode(BTN2_PIN, INPUT_PULLUP);
  enableGpioWakeLow_Deep();
  esp_deep_sleep_start();
}

// One light-sleep "tick": sleeps ~50 ms with GPIO+timer wake, returns cause.
esp_sleep_wakeup_cause_t lightSleepTick(uint64_t us){
  pinMode(BTN1_PIN, INPUT_PULLUP);
  if (USE_BTN2) pinMode(BTN2_PIN, INPUT_PULLUP);

  enableGpioWakeLow_Light();
  esp_sleep_enable_timer_wakeup(us);
  return (esp_sleep_wakeup_cause_t) esp_light_sleep_start();
}

// ---------- Setup ----------
void setup(){
  wakeCause = esp_sleep_get_wakeup_cause();

  Serial.begin(115200);
  delay(150);

  Serial.printf("Pins: D1=%d, D2=%d, D10=%d\n", D1, D2, D10);
  Serial.printf("Wake cause: %d (GPIO=%d, Timer=%d)\n",
                (int)wakeCause, (int)ESP_SLEEP_WAKEUP_GPIO, (int)ESP_SLEEP_WAKEUP_TIMER);

  // LED PWM
  pinMode(LED_PIN, OUTPUT);
  analogWriteResolution(LED_PIN, 8);     // 0..255
  analogWriteFrequency(LED_PIN, 2000);   // Hz
  ledOff();

  // Buttons
  pinMode(BTN1_PIN, INPUT_PULLUP);
  if (USE_BTN2) pinMode(BTN2_PIN, INPUT_PULLUP);
  b1.lastLevel = digitalRead(BTN1_PIN);
  if (USE_BTN2) b2.lastLevel = digitalRead(BTN2_PIN);

  // WiFi/ESP-NOW init
  WiFi.mode(WIFI_STA);
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  if (esp_now_init() != ESP_OK){
    Serial.println("ESP-NOW init failed");
    while(true){ ledOn(); delay(120); ledOff(); delay(600); }
  }
  esp_now_register_recv_cb(onRecv);
  addPeer(RX_MAC, 1);

  lastActivityMs = millis(); // start idle timer
}

// ---------- Loop ----------
void loop(){
  uint32_t now = millis();
  linked = (now - lastAckMs) < 4000;

  // If we're before 5 min idle: normal active mode
  if (ENABLE_SLEEP && (now - lastActivityMs) < IDLE_LIGHT_MS){
    if (pressEvent(b1) && !b1.holdSent) sendBtn(1);
    if (USE_BTN2 && pressEvent(b2) && !b2.holdSent) sendBtn(2);

    // Check for hold events
    if (checkHoldEvent(b1)) sendBtnHold(1);
    if (USE_BTN2 && checkHoldEvent(b2)) sendBtnHold(2);

    static uint32_t lastPing = 0;
    if (now - lastPing >= 500){ lastPing = now; sendPing(); }

    ledTask();
    delay(1);
    return;
  }

  // Between 5 and 15 minutes idle: breathing + light-sleep bursts
  if (ENABLE_SLEEP && (now - lastActivityMs) < IDLE_DEEP_MS){
    // If user presses during this phase, send immediately
    if (isBtnActive(BTN1_PIN)) { sendBtn(1); return; }
    if (USE_BTN2 && isBtnActive(BTN2_PIN)) { sendBtn(2); return; }

    // Breathing LED 0..20% - smoother calculation
    uint32_t t = (now - lastActivityMs) % BREATH_PERIOD_MS;
    uint32_t half = BREATH_PERIOD_MS / 2;
    uint8_t val = (t < half)
                  ? (uint8_t)((BREATH_MAX_RAW * t) / half)
                  : (uint8_t)((BREATH_MAX_RAW * (BREATH_PERIOD_MS - t)) / half);
    ledWriteRaw(val);

    // Use longer sleep periods to reduce flickering
    // Sleep for 500ms to make breathing pattern smoother
    esp_sleep_wakeup_cause_t cause = lightSleepTick(500000ULL); // 500 ms
    if (cause == ESP_SLEEP_WAKEUP_GPIO){
      delay(20); // settle
      if (isBtnActive(BTN1_PIN)) { sendBtn(1); return; }
      if (USE_BTN2 && isBtnActive(BTN2_PIN)) { sendBtn(2); return; }
    }
    return;
  }

  // >= 15 minutes idle: DEEP SLEEP
  if (ENABLE_SLEEP && (now - lastActivityMs) >= IDLE_DEEP_MS){
    goToDeepSleep(); // does not return
  }
}
