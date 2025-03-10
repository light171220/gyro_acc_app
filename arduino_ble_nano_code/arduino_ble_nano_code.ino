#include <ArduinoBLE.h>
#include <Arduino_LSM9DS1.h>
#include <MadgwickAHRS.h>

// Create the Madgwick filter
Madgwick filter;
unsigned long microsPerReading, microsPrevious;

// BLE service and characteristics - using standard UUIDs
BLEService imuService("180A"); // Device Information service

// Characteristics for raw accelerometer data
BLEFloatCharacteristic accelXChar("2A58", BLERead | BLENotify);
BLEFloatCharacteristic accelYChar("2A59", BLERead | BLENotify);
BLEFloatCharacteristic accelZChar("2A5A", BLERead | BLENotify);

// Characteristics for raw gyroscope data
BLEFloatCharacteristic gyroXChar("2A5B", BLERead | BLENotify);
BLEFloatCharacteristic gyroYChar("2A5C", BLERead | BLENotify);
BLEFloatCharacteristic gyroZChar("2A5D", BLERead | BLENotify);

// Characteristics for orientation (roll, pitch, yaw)
BLEFloatCharacteristic rollChar("2A5E", BLERead | BLENotify);
BLEFloatCharacteristic pitchChar("2A5F", BLERead | BLENotify);
BLEFloatCharacteristic yawChar("2A60", BLERead | BLENotify);

// Data variables
float accelX, accelY, accelZ;
float gyroX, gyroY, gyroZ;
float roll, pitch, yaw;

// Sampling rate (25Hz = 40000 microseconds per reading)
const int samplingRate = 25;
bool deviceConnected = false;

void setup() {
  Serial.begin(9600);
  // Wait for serial for debugging, but with timeout
  unsigned long startTime = millis();
  while (!Serial && (millis() - startTime < 5000)); // Wait max 5 seconds for serial
  
  // Set up built-in LEDs to indicate status
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(LEDR, OUTPUT);
  pinMode(LEDG, OUTPUT);
  pinMode(LEDB, OUTPUT);
  
  // LEDs on Nano are active LOW
  digitalWrite(LED_BUILTIN, LOW);
  digitalWrite(LEDR, HIGH);
  digitalWrite(LEDG, HIGH);
  digitalWrite(LEDB, HIGH);
  
  // Initialize IMU
  Serial.println("Initializing IMU...");
  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1) {
      digitalWrite(LEDR, LOW);  // Red LED on indicates error
      delay(300);
      digitalWrite(LEDR, HIGH);
      delay(300);
    }
  }
  
  // Initialize Madgwick filter
  filter.begin(samplingRate);
  
  // Initialize timing for consistent sampling
  microsPerReading = 1000000 / samplingRate;
  microsPrevious = micros();
  
  // Initialize BLE
  Serial.println("Initializing Bluetooth...");
  if (!BLE.begin()) {
    Serial.println("Starting Bluetooth® Low Energy failed!");
    while (1) {
      digitalWrite(LEDR, LOW);  // Red LED on indicates error
      delay(100);
      digitalWrite(LEDR, HIGH);
      delay(100);
    }
  }
  
  // Set advertised name and service
  BLE.setLocalName("Nano33BLE Orientation");
  BLE.setAdvertisedService(imuService);
  
  // Add characteristics to the service
  imuService.addCharacteristic(accelXChar);
  imuService.addCharacteristic(accelYChar);
  imuService.addCharacteristic(accelZChar);
  imuService.addCharacteristic(gyroXChar);
  imuService.addCharacteristic(gyroYChar);
  imuService.addCharacteristic(gyroZChar);
  imuService.addCharacteristic(rollChar);
  imuService.addCharacteristic(pitchChar);
  imuService.addCharacteristic(yawChar);
  
  // Add service
  BLE.addService(imuService);
  
  // Set initial values for characteristics
  accelXChar.writeValue(0.0);
  accelYChar.writeValue(0.0);
  accelZChar.writeValue(0.0);
  gyroXChar.writeValue(0.0);
  gyroYChar.writeValue(0.0);
  gyroZChar.writeValue(0.0);
  rollChar.writeValue(0.0);
  pitchChar.writeValue(0.0);
  yawChar.writeValue(0.0);
  
  // Start advertising
  BLE.advertise();
  
  Serial.println("Bluetooth® device active, waiting for connections...");
  
  // Flash GREEN LED to indicate successful initialization
  for (int i = 0; i < 3; i++) {
    digitalWrite(LEDG, LOW);  // Green LED on
    delay(200);
    digitalWrite(LEDG, HIGH);  // Green LED off
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
    digitalWrite(LED_BUILTIN, HIGH);  // Turn on built-in LED to indicate connection
    digitalWrite(LEDB, LOW);  // Blue LED on indicates connection
    
    // Reset timer when connected
    microsPrevious = micros();
    
    // While connected
    while (central.connected()) {
      // Check if it's time to read data and update the filter
      unsigned long microsNow = micros();
      
      if (microsNow - microsPrevious >= microsPerReading) {
        // Read sensor data and update orientation
        updateOrientation();
        
        // Send data via BLE
        sendSensorData();
        
        // Blink green LED briefly to indicate data transmission
        digitalWrite(LEDG, LOW);  // Green LED on
        delayMicroseconds(100);
        digitalWrite(LEDG, HIGH);  // Green LED off
        
        // Update previous time, so we keep proper pace
        microsPrevious += microsPerReading;
      }
    }
    
    // When disconnected
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
    deviceConnected = false;
    digitalWrite(LED_BUILTIN, LOW);  // Turn off built-in LED
    digitalWrite(LEDB, HIGH);  // Turn off blue LED
  }
  
  // If not connected, just keep advertising
  if (!deviceConnected) {
    // Blink LED occasionally to show we're alive and advertising
    digitalWrite(LEDR, LOW);  // Red LED on
    delay(50);
    digitalWrite(LEDR, HIGH);  // Red LED off
    delay(2000);
  }
}

void updateOrientation() {
  // Read accelerometer
  if (IMU.accelerationAvailable()) {
    IMU.readAcceleration(accelX, accelY, accelZ);
  }
  
  // Read gyroscope
  if (IMU.gyroscopeAvailable()) {
    IMU.readGyroscope(gyroX, gyroY, gyroZ);
  }
  
  // Convert gyroscope from deg/s to rad/s
  float gyroXrad = gyroX * DEG_TO_RAD;
  float gyroYrad = gyroY * DEG_TO_RAD;
  float gyroZrad = gyroZ * DEG_TO_RAD;
  
  // Update the Madgwick filter
  filter.updateIMU(gyroXrad, gyroYrad, gyroZrad, accelX, accelY, accelZ);
  
  // Get the orientation
  roll = filter.getRoll();
  pitch = filter.getPitch();
  yaw = filter.getYaw();
  
  // Print orientation data occasionally (every ~1 second)
  static int printCounter = 0;
  if (++printCounter >= samplingRate) {
    printCounter = 0;
    Serial.print("Orientation: ");
    Serial.print("Yaw = "); Serial.print(yaw);
    Serial.print(", Pitch = "); Serial.print(pitch);
    Serial.print(", Roll = "); Serial.println(roll);
    
    Serial.print("Accel: ");
    Serial.print(accelX); Serial.print(", ");
    Serial.print(accelY); Serial.print(", ");
    Serial.println(accelZ);
    
    Serial.print("Gyro: ");
    Serial.print(gyroX); Serial.print(", ");
    Serial.print(gyroY); Serial.print(", ");
    Serial.println(gyroZ);
  }
}

void sendSensorData() {
  // Update BLE characteristics with raw data
  accelXChar.writeValue(accelX);
  accelYChar.writeValue(accelY);
  accelZChar.writeValue(accelZ);
  gyroXChar.writeValue(gyroX);
  gyroYChar.writeValue(gyroY);
  gyroZChar.writeValue(gyroZ);
  
  // Update BLE characteristics with orientation data
  rollChar.writeValue(roll);
  pitchChar.writeValue(pitch);
  yawChar.writeValue(yaw);
}