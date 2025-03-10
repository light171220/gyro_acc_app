#include <ArduinoBLE.h>
#include <Arduino_LSM9DS1.h>
#include <ArduinoLowPower.h>

// BLE service and characteristics
BLEService imuService("181A"); // Environmental Sensing service

// Characteristics for accelerometer data
BLEFloatCharacteristic accelXChar("2A5A", BLERead | BLENotify); // Position 2D Char
BLEFloatCharacteristic accelYChar("2A5B", BLERead | BLENotify); // Position 3D Char
BLEFloatCharacteristic accelZChar("2A5C", BLERead | BLENotify); // Custom Char

// Characteristics for gyroscope data
BLEFloatCharacteristic gyroXChar("2A5D", BLERead | BLENotify); // Custom Char
BLEFloatCharacteristic gyroYChar("2A5E", BLERead | BLENotify); // Custom Char
BLEFloatCharacteristic gyroZChar("2A5F", BLERead | BLENotify); // Custom Char

// Data variables
float accelX, accelY, accelZ;
float gyroX, gyroY, gyroZ;

// Timing
const unsigned long INTERVAL = 5000; // 5 seconds in milliseconds
unsigned long lastSampleTime = 0;
const unsigned long SLEEP_DURATION = 4500; // Sleep for 4.5 seconds

// Connection status
bool deviceConnected = false;

void setup() {
  Serial.begin(9600);
  // Wait for serial for debugging, but with timeout
  unsigned long startTime = millis();
  while (!Serial && (millis() - startTime < 5000)); // Wait max 5 seconds for serial
  
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);
  
  // Initialize IMU
  Serial.println("Initializing IMU...");
  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1) {
      digitalWrite(LED_BUILTIN, HIGH);
      delay(300);
      digitalWrite(LED_BUILTIN, LOW);
      delay(300);
    }
  }
  
  // Initialize BLE
  Serial.println("Initializing Bluetooth...");
  if (!BLE.begin()) {
    Serial.println("Starting Bluetooth® Low Energy failed!");
    while (1) {
      digitalWrite(LED_BUILTIN, HIGH);
      delay(100);
      digitalWrite(LED_BUILTIN, LOW);
      delay(100);
    }
  }
  
  // Set advertised name and service
  BLE.setLocalName("Nano33BLE IMU");
  BLE.setAdvertisedService(imuService);
  
  // Add characteristics to the service
  imuService.addCharacteristic(accelXChar);
  imuService.addCharacteristic(accelYChar);
  imuService.addCharacteristic(accelZChar);
  imuService.addCharacteristic(gyroXChar);
  imuService.addCharacteristic(gyroYChar);
  imuService.addCharacteristic(gyroZChar);
  
  // Add service
  BLE.addService(imuService);
  
  // Set initial values for characteristics
  accelXChar.writeValue(0.0);
  accelYChar.writeValue(0.0);
  accelZChar.writeValue(0.0);
  gyroXChar.writeValue(0.0);
  gyroYChar.writeValue(0.0);
  gyroZChar.writeValue(0.0);
  
  // Start advertising
  BLE.advertise();
  
  Serial.println("Bluetooth® device active, waiting for connections...");
  
  // Flash LED to indicate successful initialization
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_BUILTIN, HIGH);
    delay(200);
    digitalWrite(LED_BUILTIN, LOW);
    delay(200);
  }
}

void loop() {
  // Listen for BLE events
  BLEDevice central = BLE.central();
  
  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());
    deviceConnected = true;
    digitalWrite(LED_BUILTIN, HIGH);
    
    // Reset timer when connected
    lastSampleTime = millis() - INTERVAL;  // Force immediate data collection
    
    // While connected
    while (central.connected()) {
      unsigned long currentTime = millis();
      
      // Check if it's time to sample and send data
      if (currentTime - lastSampleTime >= INTERVAL) {
        lastSampleTime = currentTime;
        
        // Read IMU sensors
        readSensors();
        
        // Send data via BLE
        sendSensorData();
        
        Serial.println("Data sent!");
        
        // Flash LED to indicate data sent
        digitalWrite(LED_BUILTIN, LOW);
        delay(50);
        digitalWrite(LED_BUILTIN, HIGH);
        
        // Short delay to allow BLE operations to complete
        delay(200);
        
        // Enter low power mode but not for too long to maintain connection
        // Instead of full sleep, we'll use a more BLE-friendly approach
        Serial.println("Entering low power mode...");
        
        // We'll sleep in short bursts to maintain BLE connection
        // Most nRF52 based boards can maintain BLE with short sleep cycles
        for (int i = 0; i < 9; i++) {  // 9 * 500ms = 4.5s
          digitalWrite(LED_BUILTIN, LOW);  // Turn off LED to save power
          delay(500);  // Small delay instead of full sleep
          
          // Check connection status and break if disconnected
          if (!central.connected()) {
            break;
          }
        }
        
        digitalWrite(LED_BUILTIN, HIGH);  // Turn LED back on when active
      }
      
      // Small delay to prevent CPU hogging
      delay(20);
    }
    
    // When disconnected
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
    deviceConnected = false;
    digitalWrite(LED_BUILTIN, LOW);
  }
  
  // If not connected, use deeper sleep between advertisements
  if (!deviceConnected) {
    // Sleep mode between advertisements to save power
    Serial.println("No connection, entering sleep mode...");
    
    // Turn off LED to save power
    digitalWrite(LED_BUILTIN, LOW);
    
    // Stop BLE before sleeping to save more power
    BLE.stopAdvertise();
    BLE.end();
    
    // Deep sleep
    delay(100);  // Short delay to allow serial to flush
    LowPower.deepSleep(INTERVAL);
    
    // Re-initialize BLE after waking
    if (!BLE.begin()) {
      Serial.println("Restarting Bluetooth® failed!");
      return;  // Try again in next loop
    }
    
    // Re-setup BLE services and characteristics
    BLE.setLocalName("Nano33BLE IMU");
    BLE.setAdvertisedService(imuService);
    BLE.addService(imuService);
    
    // Start advertising again
    BLE.advertise();
    Serial.println("Woke up, advertising again");
    
    // Blink once to indicate wake-up
    digitalWrite(LED_BUILTIN, HIGH);
    delay(50);
    digitalWrite(LED_BUILTIN, LOW);
  }
}

void readSensors() {
  // Read accelerometer
  if (IMU.accelerationAvailable()) {
    IMU.readAcceleration(accelX, accelY, accelZ);
  }
  
  // Read gyroscope
  if (IMU.gyroscopeAvailable()) {
    IMU.readGyroscope(gyroX, gyroY, gyroZ);
  }
  
  // Print to Serial
  Serial.println("Accelerometer (g):");
  Serial.print("X = "); Serial.print(accelX);
  Serial.print(", Y = "); Serial.print(accelY);
  Serial.print(", Z = "); Serial.println(accelZ);
  
  Serial.println("Gyroscope (deg/s):");
  Serial.print("X = "); Serial.print(gyroX);
  Serial.print(", Y = "); Serial.print(gyroY);
  Serial.print(", Z = "); Serial.println(gyroZ);
}

void sendSensorData() {
  // Update BLE characteristics
  accelXChar.writeValue(accelX);
  accelYChar.writeValue(accelY);
  accelZChar.writeValue(accelZ);
  gyroXChar.writeValue(gyroX);
  gyroYChar.writeValue(gyroY);
  gyroZChar.writeValue(gyroZ);
}