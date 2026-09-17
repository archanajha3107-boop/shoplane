#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// ─── PINS ────────────────────────────────────────────────────
#define BUZZER_PIN     18
#define BUTTON_PIN     15
#define BOOT_BUTTON     0
#define OLED_SDA       21
#define OLED_SCL       22
#define JSON_BUFFER_SIZE 16384

// ─── OLED ────────────────────────────────────────────────────
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT  64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ─── FIREBASE ────────────────────────────────────────────────
const String FIREBASE_PROJECT = "shoplane-a39b9";
const String FIREBASE_API_KEY = "AIzaSyBSQSYCqHs33-UB2XPowuVGVTeXePfQm2I"; 
// Get from: Firebase Console → Project Settings → Web API Key

// ─── GLOBALS ─────────────────────────────────────────────────
Preferences prefs;
WebServer   server(80);

String savedSSID     = "";
String savedPassword = "";
String savedVendorId = "";
String deviceId      = "";
String devicePin     = "";
bool   provisionMode = false;
String lastAlertedOrderId = "";

// ─── OLED HELPER ─────────────────────────────────────────────
void oled(String l1, String l2 = "", String l3 = "", String l4 = "") {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);  display.println(l1);
  display.setCursor(0, 18); display.println(l2);
  display.setCursor(0, 36); display.println(l3);
  display.setCursor(0, 52); display.println(l4);
  display.display();
}

// ─── BUZZER ──────────────────────────────────────────────────
void buzz(int times = 1, int durationMs = 300) {
  for (int i = 0; i < times; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(durationMs);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < times - 1) delay(150);
  }
}

// ─── GENERATE DEVICE ID + PIN ────────────────────────────────
void generateDeviceId() {
  uint64_t mac = ESP.getEfuseMac();
  char buf[9];
  snprintf(buf, sizeof(buf), "%04X%04X",
           (uint16_t)(mac >> 32),
           (uint16_t)(mac));
  deviceId = String(buf);

  // 4-digit PIN from last 4 digits of chip ID
  uint32_t chip = (uint32_t)mac;
  devicePin = String(chip % 10000);
  while (devicePin.length() < 4) devicePin = "0" + devicePin;
}

// ─── AP MODE (PROVISION MODE) ────────────────────────────────
void startAPMode() {
  provisionMode = true;
  String apName = "ShopLane-" + deviceId;

  WiFi.softAP(apName.c_str(), ""); // open network, no password
  delay(500);

  oled("ShopLane Setup",
       "Connect to WiFi:",
       apName,
       "PIN: " + devicePin);

  Serial.println("AP started: " + apName);
  Serial.println("PIN: " + devicePin);
  Serial.println("Config page: http://192.168.4.1");

  // ── HTTP server routes ──────────────────────────────────────

  // Health check — app uses this to confirm connection
  server.on("/ping", HTTP_GET, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "application/json",
                "{\"deviceId\":\"" + deviceId + "\","
                "\"status\":\"ready\"}");
  });

  // Verify PIN — app sends PIN before credentials
  server.on("/verify", HTTP_POST, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    if (!server.hasArg("plain")) {
      server.send(400, "application/json", "{\"error\":\"no body\"}");
      return;
    }
    DynamicJsonDocument doc(256);
    deserializeJson(doc, server.arg("plain"));
    String pin = doc["pin"] | "";
    if (pin == devicePin) {
      server.send(200, "application/json", "{\"verified\":true}");
      oled("PIN Verified!", "Send WiFi", "credentials now");
    } else {
      server.send(403, "application/json", "{\"verified\":false}");
    }
  });

  // Receive credentials — final step
  server.on("/configure", HTTP_POST, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    if (!server.hasArg("plain")) {
      server.send(400, "application/json", "{\"error\":\"no body\"}");
      return;
    }
    DynamicJsonDocument doc(512);
    deserializeJson(doc, server.arg("plain"));

    String ssid     = doc["ssid"]     | "";
    String password = doc["password"] | "";
    String vendorId = doc["vendorId"] | "";

    if (ssid == "" || vendorId == "") {
      server.send(400, "application/json", "{\"error\":\"missing fields\"}");
      return;
    }

    server.send(200, "application/json", "{\"success\":true}");
    oled("Credentials", "received!", "Restarting...", "");
    buzz(2);
    delay(1500);

    // Save to flash
    prefs.begin("shoplane", false);
    prefs.putString("ssid",     ssid);
    prefs.putString("password", password);
    prefs.putString("vendorId", vendorId);
    prefs.end();

    delay(500);
    ESP.restart();
  });

  // OPTIONS preflight for CORS
  server.on("/ping",      HTTP_OPTIONS, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    server.send(204);
  });
  server.on("/verify",    HTTP_OPTIONS, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    server.send(204);
  });
  server.on("/configure", HTTP_OPTIONS, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    server.send(204);
  });

  server.begin();
  Serial.println("HTTP server started");
}

// ─── CONNECT TO SAVED WIFI ───────────────────────────────────
bool connectWiFi() {
  oled("Connecting...", savedSSID, "", "");
  WiFi.begin(savedSSID.c_str(), savedPassword.c_str());
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 24) {
    delay(500);
    tries++;
  }
  return WiFi.status() == WL_CONNECTED;
}

// ─── POLL FIRESTORE FOR NEW ORDERS ──────────────────────────
void pollOrders() {
  if (WiFi.status() != WL_CONNECTED) {
    oled("WiFi lost", "Reconnecting...");
    WiFi.reconnect();
    delay(5000);
    return;
  }

  HTTPClient http;
  // Use Firestore structured query (POST) instead of GET
  // This filters server-side: sellerId == vendorId AND status == new
  String url = "https://firestore.googleapis.com/v1/projects/"
               + FIREBASE_PROJECT
               + "/databases/(default)/documents:runQuery"
               + "?key=" + FIREBASE_API_KEY;

  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);

  // Structured query body
  String body = R"({
    "structuredQuery": {
      "from": [{"collectionId": "orders"}],
      "where": {
        "compositeFilter": {
          "op": "AND",
          "filters": [
            {
              "fieldFilter": {
                "field": {"fieldPath": "sellerId"},
                "op": "EQUAL",
                "value": {"stringValue": ")" + savedVendorId + R"("}
              }
            },
            {
              "fieldFilter": {
                "field": {"fieldPath": "status"},
                "op": "EQUAL",
                "value": {"stringValue": "new"}
              }
            }
          ]
        }
      }
    }
  })";

  int code = http.POST(body);

  if (code == 200) {
    String payload = http.getString();
    Serial.println("Query response: " + payload.substring(0, 200));

    DynamicJsonDocument doc(JSON_BUFFER_SIZE);
    DeserializationError err = deserializeJson(doc, payload);

    if (!err) {
      JsonArray results = doc.as<JsonArray>();
      for (JsonObject result : results) {
        // Skip if no document (empty result)
        if (!result.containsKey("document")) continue;

        JsonObject orderDoc = result["document"];
        JsonObject fields   = orderDoc["fields"];

        String name     = orderDoc["name"].as<String>();
        String orderId  = name.substring(name.lastIndexOf('/') + 1);
        String custName = fields["customerName"]["stringValue"] | "Customer";
        float  total    = 0;

        // total can be doubleValue or integerValue
        if (fields["total"].containsKey("doubleValue")) {
          total = fields["total"]["doubleValue"].as<float>();
        } else if (fields["total"].containsKey("integerValue")) {
          total = fields["total"]["integerValue"].as<float>();
        }

        Serial.println("New order found: " + orderId);

        if (orderId != lastAlertedOrderId) {
          lastAlertedOrderId = orderId;

          String line1 = custName;
          if (line1.length() > 16) line1 = line1.substring(0, 16);

          oled("NEW ORDER!",
               line1,
               "Rs." + String((int)total),
               "Press to Accept");

          buzz(3, 200);
        }
      }
    } else {
      Serial.println("JSON parse error: " + String(err.c_str()));
    }
  } else {
    Serial.println("Query failed: " + String(code));
    Serial.println(http.getString().substring(0, 200));
  }

  http.end();
}

// ─── ACCEPT ORDER ────────────────────────────────────────────
void acceptOrder() {
  if (lastAlertedOrderId == "" || WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = "https://firestore.googleapis.com/v1/projects/"
               + FIREBASE_PROJECT
               + "/databases/(default)/documents/orders/"
               + lastAlertedOrderId
               + "?updateMask.fieldPaths=status"
               + "&key=" + FIREBASE_API_KEY;

  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  String body = "{\"fields\":{\"status\":{\"stringValue\":\"accepted\"}}}";
  int code = http.PATCH(body);
  http.end();

  if (code == 200) {
    oled("Accepted!", "", "Order confirmed", "");
    buzz(1, 500);
    lastAlertedOrderId = "";
    delay(2000);
    oled("ShopLane", savedVendorId.substring(0, min(16, (int)savedVendorId.length())), "Watching...", "");
  } else {
    oled("Accept failed", "Try again", "", "");
    delay(2000);
  }
}

// ─── SETUP ───────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BOOT_BUTTON, INPUT_PULLUP);
  digitalWrite(BUZZER_PIN, LOW);

  Wire.begin(OLED_SDA, OLED_SCL);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED init failed");
    while (true) delay(100);
  }
  display.clearDisplay();
  display.display();

  generateDeviceId();
  oled("ShopLane", "Device: " + deviceId, "Starting...", "");
  delay(1500);

  // Hold BOOT button on power-on → wipe all credentials
  if (digitalRead(BOOT_BUTTON) == LOW) {
    prefs.begin("shoplane", false);
    prefs.clear();
    prefs.end();
    oled("RESET!", "All credentials", "wiped.", "Restarting...");
    buzz(3, 100);
    delay(2000);
    ESP.restart();
  }

  // Load saved credentials
  prefs.begin("shoplane", true);
  savedSSID     = prefs.getString("ssid",     "");
  savedPassword = prefs.getString("password", "");
  savedVendorId = prefs.getString("vendorId", "");
  prefs.end();

  if (savedSSID == "" || savedVendorId == "") {
    // No credentials — start AP provisioning mode
    startAPMode();
  } else {
    // Credentials exist — connect to WiFi
    bool ok = connectWiFi();
    if (ok) {
      oled("Connected!", savedSSID.substring(0, 16), "ShopLane Active", "Watching orders...");
      buzz(1, 300);
    } else {
      oled("WiFi failed", "Hold BOOT btn", "to reset &", "re-configure");
    }
  }
}

// ─── LOOP ────────────────────────────────────────────────────
void loop() {
  if (provisionMode) {
    server.handleClient(); // Handle app HTTP requests
    delay(10);
    return;
  }

  // Normal order-polling mode
  pollOrders();

  // Check accept button
  if (digitalRead(BUTTON_PIN) == LOW) {
    delay(50); // debounce
    if (digitalRead(BUTTON_PIN) == LOW) {
      acceptOrder();
      while (digitalRead(BUTTON_PIN) == LOW); // wait for release
    }
  }

  delay(5000); // poll every 5 seconds
}