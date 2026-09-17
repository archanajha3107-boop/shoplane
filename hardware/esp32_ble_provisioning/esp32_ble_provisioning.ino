// esp32_ble_provisioning.ino
// Full flow: first boot with no saved WiFi -> advertises over Bluetooth as
// "ShopLane-Setup" -> app sends {ssid, password, vendorId} once -> saved
// permanently to flash (Preferences/NVS) -> every future boot connects to
// WiFi directly, no Bluetooth needed. Same order-alert + heartbeat logic
// as before, now wrapped with this provisioning layer.

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_GFX.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <time.h>

#define OLED_SDA 21
#define OLED_SCL 22
#define BUZZER_PIN 18
#define RESET_BUTTON_PIN 0 // most ESP32 dev boards have a "BOOT" button on GPIO0 — hold on power-on to reset pairing

// Fixed values you still need to fill in — these don't change per-shop,
// only WiFi credentials and vendorId are set via Bluetooth now.
const String firebaseProjectId = "shoplane-a39b9";
const String apiKey = "AIzaSyBSQSYCqHs33-UB2XPowuVGVTeXePfQm2I";

// Random but fixed UUIDs for the BLE service/characteristic — same on every device you flash
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

Adafruit_SSD1306 display(128, 64, &Wire, -1);
Preferences preferences;
String lastSeenOrderId = "";
String savedSsid, savedPassword, savedVendorId;
bool credentialsReceived = false;

class ProvisioningCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) {
    String value = characteristic->getValue().c_str();
    Serial.println("Received: " + value);

    DynamicJsonDocument doc(512);
    DeserializationError err = deserializeJson(doc, value);
    if (err) {
      Serial.println("Invalid pairing JSON received");
      return;
    }

    savedSsid = doc["ssid"].as<String>();
    savedPassword = doc["password"].as<String>();
    savedVendorId = doc["vendorId"].as<String>();

    preferences.begin("shoplane", false);
    preferences.putString("ssid", savedSsid);
    preferences.putString("password", savedPassword);
    preferences.putString("vendorId", savedVendorId);
    preferences.end();

    Serial.println("Credentials saved. Restarting...");
    credentialsReceived = true;
  }
};

void startBleProvisioning() {
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("Pairing mode");
  display.println("Open ShopLane app");
  display.println("to set up WiFi");
  display.display();

  BLEDevice::init("ShopLane-Setup");
  BLEServer *server = BLEDevice::createServer();
  BLEService *service = server->createService(SERVICE_UUID);

  BLECharacteristic *characteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  characteristic->setCallbacks(new ProvisioningCallback());
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->start();

  Serial.println("BLE provisioning started, advertising as ShopLane-Setup");

  // Wait here until the app sends credentials over Bluetooth
  while (!credentialsReceived) {
    delay(200);
  }

  delay(500);
  ESP.restart(); // clean restart into normal WiFi mode with the new credentials
}

void setup() {
  Serial.begin(115200);
  Wire.begin(OLED_SDA, OLED_SCL);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
  digitalWrite(BUZZER_PIN, LOW);

  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();
  display.display();

  // Hold the BOOT button during power-on to wipe saved credentials and re-pair
  if (digitalRead(RESET_BUTTON_PIN) == LOW) {
    preferences.begin("shoplane", false);
    preferences.clear();
    preferences.end();
    Serial.println("Credentials wiped via reset button.");
  }

  preferences.begin("shoplane", true); // read-only mode
  savedSsid = preferences.getString("ssid", "");
  savedPassword = preferences.getString("password", "");
  savedVendorId = preferences.getString("vendorId", "");
  preferences.end();

  if (savedSsid == "") {
    // No saved WiFi -> enter Bluetooth pairing mode and wait
    startBleProvisioning();
    return; // unreachable in practice, startBleProvisioning() restarts the device
  }

  // Saved credentials exist -> connect straight to WiFi, no Bluetooth at all
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("Connecting WiFi...");
  display.display();

  WiFi.begin(savedSsid.c_str(), savedPassword.c_str());
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    attempts++;
  }

  display.clearDisplay();
  display.setCursor(0, 0);
  if (WiFi.status() == WL_CONNECTED) {
    display.println("Connected");
  } else {
    display.println("WiFi FAILED");
    display.println("Hold BOOT button");
    display.println("+ power to re-pair");
  }
  display.display();

  configTime(0, 0, "pool.ntp.org");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) return; // stuck if WiFi failed — reset button is the recovery path
  checkForNewOrder();
  sendHeartbeat();
  delay(5000);
}

void checkForNewOrder() {
  HTTPClient http;
  String url = "https://firestore.googleapis.com/v1/projects/" + firebaseProjectId +
               "/databases/(default)/documents/orders?pageSize=5&orderBy=createdAt%20desc&key=" + apiKey;
  http.begin(url);
  int httpCode = http.GET();

  if (httpCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(8192);
    if (deserializeJson(doc, payload)) { http.end(); return; }

    JsonArray documents = doc["documents"];
    for (JsonObject orderDoc : documents) {
      JsonObject fields = orderDoc["fields"];
      String orderSellerId = fields["sellerId"]["stringValue"] | "";
      String orderId = orderDoc["name"].as<String>();

      if (orderSellerId == savedVendorId && orderId != lastSeenOrderId) {
        lastSeenOrderId = orderId;
        String customerName = fields["customerName"]["stringValue"] | "Customer";
        String total = fields["total"]["doubleValue"] | "0";

        display.clearDisplay();
        display.setCursor(0, 0);
        display.println("NEW ORDER!");
        display.println(customerName);
        display.print("Total: Rs ");
        display.println(total);
        display.display();

        digitalWrite(BUZZER_PIN, HIGH);
        delay(1000);
        digitalWrite(BUZZER_PIN, LOW);
        break;
      }
    }
  }
  http.end();
}

void sendHeartbeat() {
  HTTPClient http;
  String url = "https://firestore.googleapis.com/v1/projects/" + firebaseProjectId +
               "/databases/(default)/documents/devices/" + savedVendorId +
               "?updateMask.fieldPaths=lastSeen&key=" + apiKey;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  time_t now;
  time(&now);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);

  String body = "{\"fields\":{\"lastSeen\":{\"timestampValue\":\"" + String(buf) + "\"}}}";
  http.PATCH(body);
  http.end();
}
