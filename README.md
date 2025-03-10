# Nano 33 BLE IMU Data Collection System
## Overview
This project creates a power-efficient system for collecting and visualizing accelerometer and gyroscope data from an Arduino Nano 33 BLE. The system transmits sensor data over Bluetooth Low Energy at 5-second intervals and enters sleep mode between transmissions to conserve power.
## Components
Arduino Firmware
The Arduino code handles:

Collection of accelerometer and gyroscope data from the LSM9DS1 IMU
Packaging and transmission of data over Bluetooth LE
Power management through intelligent sleep modes
Visual status indication through the onboard LED

## Mobile Application
The Flutter mobile app provides:

Device discovery and connection to the Arduino
Real-time display of sensor values
Time-series visualization of historical data
3D representation of device orientation based on sensor readings

## Features

Power Efficiency: The Arduino enters deep sleep mode when not connected and light sleep when connected to maximize battery life
Easy Connectivity: BLE connection makes data accessible to most modern smartphones
Rich Visualization: Interactive charts show trends in the sensor data over time
3D Orientation Display: Visual representation of the device's physical orientation
Reliable Communication: Robust connection handling ensures data integrity