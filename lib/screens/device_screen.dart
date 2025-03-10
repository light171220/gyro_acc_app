import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano33_ble_imu/screens/home_screen.dart';
import 'package:nano33_ble_imu/services/imu_data_point.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool isConnected = false;
  List<BluetoothService> services = [];
  
  // Data storage
  double accelX = 0.0, accelY = 0.0, accelZ = 0.0;
  double gyroX = 0.0, gyroY = 0.0, gyroZ = 0.0;
  
  // Data history for charts
  List<IMUDataPoint> accelXHistory = [];
  List<IMUDataPoint> accelYHistory = [];
  List<IMUDataPoint> accelZHistory = [];
  List<IMUDataPoint> gyroXHistory = [];
  List<IMUDataPoint> gyroYHistory = [];
  List<IMUDataPoint> gyroZHistory = [];
  
  // Maximum points to keep in history
  static const int MAX_HISTORY = 50;
  
  // UUIDs matching the Arduino code
  final String IMU_SERVICE_UUID = "181A";
  final Map<String, String> CHARACTERISTIC_UUIDS = {
    "accelX": "2A5A",
    "accelY": "2A5B",
    "accelZ": "2A5C",
    "gyroX": "2A5D",
    "gyroY": "2A5E",
    "gyroZ": "2A5F",
  };
  
  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }
  
  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() {
        isConnected = true;
      });
      
      // Discover services
      services = await widget.device.discoverServices();
      
      // Set up notifications for characteristics
      _setupCharacteristicNotifications();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to device: $e'))
      );
      print("Error connecting: $e");
    }
  }
  
  void _setupCharacteristicNotifications() {
    for (BluetoothService service in services) {
      if (service.uuid.toString().toUpperCase().contains(IMU_SERVICE_UUID)) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toUpperCase();
          
          if (CHARACTERISTIC_UUIDS.values.any((uuid) => charUuid.contains(uuid))) {
            // Set up notification
            characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                _updateValue(characteristic, value);
              }
            });
          }
        }
      }
    }
  }
  
  void _updateValue(BluetoothCharacteristic characteristic, List<int> value) {
    String charUuid = characteristic.uuid.toString().toUpperCase();
    
    // Convert bytes to float (Arduino uses little-endian IEEE-754)
    double floatValue = _bytesToFloat(value);
    DateTime now = DateTime.now();
    
    setState(() {
      if (charUuid.contains(CHARACTERISTIC_UUIDS["accelX"]!)) {
        accelX = floatValue;
        _addToHistory(accelXHistory, floatValue, now);
      } else if (charUuid.contains(CHARACTERISTIC_UUIDS["accelY"]!)) {
        accelY = floatValue;
        _addToHistory(accelYHistory, floatValue, now);
      } else if (charUuid.contains(CHARACTERISTIC_UUIDS["accelZ"]!)) {
        accelZ = floatValue;
        _addToHistory(accelZHistory, floatValue, now);
      } else if (charUuid.contains(CHARACTERISTIC_UUIDS["gyroX"]!)) {
        gyroX = floatValue;
        _addToHistory(gyroXHistory, floatValue, now);
      } else if (charUuid.contains(CHARACTERISTIC_UUIDS["gyroY"]!)) {
        gyroY = floatValue;
        _addToHistory(gyroYHistory, floatValue, now);
      } else if (charUuid.contains(CHARACTERISTIC_UUIDS["gyroZ"]!)) {
        gyroZ = floatValue;
        _addToHistory(gyroZHistory, floatValue, now);
      }
    });
  }
  
  void _addToHistory(List<IMUDataPoint> history, double value, DateTime time) {
    history.add(IMUDataPoint(time, value));
    if (history.length > MAX_HISTORY) {
      history.removeAt(0);
    }
  }
  
  double _bytesToFloat(List<int> bytes) {
    if (bytes.length < 4) return 0.0;
    
    // Convert 4 bytes to a 32-bit float
    ByteData byteData = ByteData(4);
    for (int i = 0; i < 4; i++) {
      byteData.setUint8(i, bytes[i]);
    }
    return byteData.getFloat32(0, Endian.little);
  }
  
  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: isConnected 
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accelerometer Data:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDataCard('X', accelX, Colors.red),
                    _buildDataCard('Y', accelY, Colors.green),
                    _buildDataCard('Z', accelZ, Colors.blue),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  child: _buildAccelerometerChart(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gyroscope Data:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDataCard('X', gyroX, Colors.red),
                    _buildDataCard('Y', gyroY, Colors.green),
                    _buildDataCard('Z', gyroZ, Colors.blue),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  child: _buildGyroscopeChart(),
                ),
                const SizedBox(height: 24),
                _build3DOrientationVisualizer(),
              ],
            ),
          )
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to device...'),
              ],
            ),
          ),
    );
  }
  
  Widget _buildDataCard(String axis, double value, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              axis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.toStringAsFixed(3),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAccelerometerChart() {
    return charts.TimeSeriesChart(
      [
        _createTimeSeriesData(accelXHistory, Colors.red, "X"),
        _createTimeSeriesData(accelYHistory, Colors.green, "Y"),
        _createTimeSeriesData(accelZHistory, Colors.blue, "Z"),
      ],
      animate: false,
      dateTimeFactory: const charts.LocalDateTimeFactory(),
      behaviors: [
        charts.SeriesLegend(),
        charts.PanAndZoomBehavior(),
      ],
      domainAxis: const charts.DateTimeAxisSpec(
        tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
          second: charts.TimeFormatterSpec(
            format: 'ss',
            transitionFormat: 'HH:mm:ss',
          ),
        ),
      ),
      title: 'Accelerometer Readings (g)',
    );
  }
  
  Widget _buildGyroscopeChart() {
    return charts.TimeSeriesChart(
      [
        _createTimeSeriesData(gyroXHistory, Colors.red, "X"),
        _createTimeSeriesData(gyroYHistory, Colors.green, "Y"),
        _createTimeSeriesData(gyroZHistory, Colors.blue, "Z"),
      ],
      animate: false,
      dateTimeFactory: const charts.LocalDateTimeFactory(),
      behaviors: [
        charts.SeriesLegend(),
        charts.PanAndZoomBehavior(),
      ],
      domainAxis: const charts.DateTimeAxisSpec(
        tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
          second: charts.TimeFormatterSpec(
            format: 'ss',
            transitionFormat: 'HH:mm:ss',
          ),
        ),
      ),
      title: 'Gyroscope Readings (deg/s)',
    );
  }
  
  charts.Series<IMUDataPoint, DateTime> _createTimeSeriesData(
    List<IMUDataPoint> data, 
    Color color,
    String id
  ) {
    return charts.Series<IMUDataPoint, DateTime>(
      id: id,
      colorFn: (_, __) => charts.ColorUtil.fromDartColor(color),
      domainFn: (IMUDataPoint point, _) => point.time,
      measureFn: (IMUDataPoint point, _) => point.value,
      data: data,
    );
  }
  
  Widget _build3DOrientationVisualizer() {
    return Container(
      width: double.infinity,
      height: 200,
      child: CustomPaint(
        painter: OrientationPainter(
          accelX: accelX,
          accelY: accelY,
          accelZ: accelZ,
          gyroX: gyroX,
          gyroY: gyroY,
          gyroZ: gyroZ,
        ),
      ),
    );
  }
}