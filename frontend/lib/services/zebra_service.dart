import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'zebra_ble_printer.dart';

class ZebraService {
  // Singleton pattern
  static final ZebraService _instance = ZebraService._internal();
  factory ZebraService() => _instance;
  ZebraService._internal();

  ZebraBlePrinter? _connectedPrinter;

  // Stream of scan results (ScanResult objects)
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  // Stream for scanning state
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  // Start scanning for Bluetooth devices
  Future<void> startScan({Duration? timeout}) async {
    // Wait for Bluetooth to be enabled
    await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;
    // Start scan
    await FlutterBluePlus.startScan(timeout: timeout ?? const Duration(seconds: 15));
  }

  // Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // Connect to a Zebra printer via BLE
  Future<bool> connectToPrinter(BluetoothDevice device) async {
    try {
      _connectedPrinter = ZebraBlePrinter(device);
      final success = await _connectedPrinter!.connectAndDiscover();
      if (!success) {
        _connectedPrinter = null;
      }
      return success;
    } catch (e) {
      print("Error connecting to printer: $e");
      _connectedPrinter = null;
      return false;
    }
  }

  // Send ZPL command to connected printer
  Future<void> printZpl(String zpl) async {
    if (_connectedPrinter == null) {
      throw Exception("No printer connected");
    }
    print("ZebraService: Sending ZPL command...");
    await _connectedPrinter!.sendCommand(zpl);
    print("ZebraService: Command sent.");
  }

  // Disconnect from printer
  Future<void> disconnect() async {
    await _connectedPrinter?.disconnect();
    _connectedPrinter = null;
  }

  bool get isConnected => _connectedPrinter != null;
}