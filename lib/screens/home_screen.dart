import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano33_ble_imu/screens/device_screen.dart';
import 'package:nano33_ble_imu/screens/home_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  
  // Controller for refreshing the scan
  final StreamController<bool> _scanningStateController = StreamController<bool>.broadcast();
  
  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _setupBluetooth();
  }
  
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    if (statuses.values.any((status) => status != PermissionStatus.granted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions are required to scan for devices'))
      );
    }
  }
  
  void _setupBluetooth() {
    // Listen to scan results
    flutterBlue.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    }, onError: (e) {
      print("Scanning error: $e");
    });
    
    // Listen to BlueTooth state changes
    flutterBlue.state.listen((state) {
      if (state == BluetoothState.off) {
        setState(() {
          scanResults = [];
          isScanning = false;
          _scanningStateController.add(false);
        });
      }
    });
  }

  void startScan() async {
    setState(() {
      scanResults = [];
      isScanning = true;
      _scanningStateController.add(true);
    });
    
    try {
      await flutterBlue.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid("181A")], // Environmental Sensing service UUID
      );
    } catch (e) {
      print("Error starting scan: $e");
    }
    
    setState(() {
      isScanning = false;
      _scanningStateController.add(false);
    });
  }
  
  void stopScan() {
    flutterBlue.stopScan();
    setState(() {
      isScanning = false;
      _scanningStateController.add(false);
    });
  }

  @override
  void dispose() {
    _scanningStateController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nano 33 BLE IMU Data'),
        actions: [
          StreamBuilder<bool>(
            stream: _scanningStateController.stream,
            initialData: isScanning,
            builder: (c, snapshot) {
              if (snapshot.data ?? false) {
                return IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: stopScan,
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: startScan,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!isScanning) {
            startScan();
          }
        },
        child: ListView.builder(
          itemCount: scanResults.length,
          itemBuilder: (context, index) {
            final result = scanResults[index];
            final device = result.device;
            final name = device.name.isNotEmpty 
                ? device.name 
                : "Unknown Device";
            
            // Only show devices with names containing "Nano33BLE IMU"
            if (!name.contains("Nano33BLE IMU")) {
              return Container(); // Skip this device
            }
            
            return ListTile(
              title: Text(name),
              subtitle: Text(device.id.toString()),
              trailing: Text("${result.rssi} dBm"),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DeviceScreen(device: device),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: startScan,
        child: const Icon(Icons.search),
      ),
    );
  }
}