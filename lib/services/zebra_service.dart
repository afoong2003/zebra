import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'zebra_ble_printer.dart';
import 'printer_settings_helper.dart';

class ZebraService {
  static final ZebraService _instance = ZebraService._internal();
  factory ZebraService() => _instance;
  ZebraService._internal();

  ZebraBlePrinter? _connectedPrinter;
  String? _cachedModelName; 

  // Public getter
  ZebraBlePrinter? get connectedPrinter => _connectedPrinter;

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
        _cachedModelName = null;
        return false;
      }
      
      // Immediately fetch and cache the model name after successful connection
      print('Fetching and caching model name...');
      _cachedModelName = await _fetchModelNameFromPrinter();
      print('Cached model name: $_cachedModelName');
      
      return true;
    } catch (e) {
      print("Error connecting to printer: $e");
      _connectedPrinter = null;
      _cachedModelName = null;
      return false;
    }
  }

  Future<void> printZpl(String zpl) async {
    if (_connectedPrinter == null) {
      throw Exception("No printer connected");
    }
    print("ZebraService: Sending ZPL command...");
    await _connectedPrinter!.sendCommand(zpl);
    print("ZebraService: Command sent.");
  }

  Future<void> disconnect() async {
    await _connectedPrinter?.disconnect();
    _connectedPrinter = null;
    _cachedModelName = null;
    
    // Reset printer settings cache when disconnecting
    PrinterSettingsHelper().resetCachedKeys();
    print('Cleared all printer caches on disconnect');
  }

  bool get isConnected => _connectedPrinter != null;

  // Private method to fetch model name from printer
  Future<String?> _fetchModelNameFromPrinter() async {
    if (_connectedPrinter == null) return null;
    try {
      var response = await _connectedPrinter!.sendCommandAndGetResponse('! U1 getvar "device.product_name"\r\n');
      

      
      if (response != null && response.isNotEmpty && response != '?') {
        String model = response.trim();
        if (model.startsWith('"') && model.endsWith('"') && model.length > 1) {
          model = model.substring(1, model.length - 1);
        }
        
        if (model.contains(' ')) {
          model = model.split(' ').first;
        }
        
        return model;
      }
    } catch (e) {
      print("Error fetching model name from printer: $e");
    }
    return null;
  }

  // Public method to get model name (returns cached value if available)
  Future<String?> getModelName() async {
    // Return cached value if available
    if (_cachedModelName != null) {
      print('Using cached model name: $_cachedModelName');
      return _cachedModelName;
    }
    
    print('Model name not cached, fetching...');
    _cachedModelName = await _fetchModelNameFromPrinter();
    return _cachedModelName;
  }
}