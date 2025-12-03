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
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;
    // Start scan
    await FlutterBluePlus.startScan(
      timeout: timeout ?? const Duration(seconds: 15),
    );
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

    print("ZebraService: Sending ZPL command (${zpl.length} chars)...");
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
      var response = await _connectedPrinter!.sendCommandAndGetResponse(
        '! U1 getvar "device.product_name"\r\n',
      );

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

  Future<SystemStatus> getSystemStatus() async {
    if (!isConnected || _connectedPrinter == null) {
      throw Exception('Printer not connected');
    }

    try {
      final response = await _connectedPrinter!.sendCommandAndGetResponse(
        '! U1 getvar "zpl.system_status"\r\n',
      );

      if (response == null || response.isEmpty || response == '?') {
        throw Exception('No response from printer');
      }

      print('System Status Response: $response');

      return _parseSystemStatus(response);
    } catch (e) {
      print('Error getting system status: $e');
      rethrow;
    }
  }

  SystemStatus _parseSystemStatus(String response) {
    // Response format: "1,1,00000000,00000004,0,00000000,00000000"
    // Already has commas, just need to remove quotes and split

    // Remove quotes and whitespace
    final cleaned = response.replaceAll('"', '').trim();

    // Split by comma - response already has them!
    final parts = cleaned.split(',');

    if (parts.length != 7) {
      print('Warning: Expected 7 parts, got ${parts.length}');
      print('Parts: $parts');
      throw Exception(
        'Invalid system status response format: expected 7 values, got ${parts.length}',
      );
    }

    // Parse the 7 values
    final pauseFlag = parts[0].trim();
    final errorFlag = parts[1].trim();
    final errorGroup2 = parts[2].trim();
    final errorGroup1 = parts[3].trim();
    final warningFlag = parts[4].trim();
    final warningGroup2 = parts[5].trim();
    final warningGroup1 = parts[6].trim();

    print('Parsed values:');
    print('  Pause: $pauseFlag');
    print('  Error Flag: $errorFlag');
    print('  Error Group2: $errorGroup2');
    print('  Error Group1: $errorGroup1');
    print('  Warning Flag: $warningFlag');
    print('  Warning Group2: $warningGroup2');
    print('  Warning Group1: $warningGroup1');

    final hasErrors = errorFlag == '1';
    final hasWarnings = warningFlag == '1';

    final errors = <String>[];
    final warnings = <String>[];

    // Parse errors
    if (hasErrors) {
      errors.addAll(_parseErrorFlags(errorGroup1, errorGroup2));

      // Check pause status
      if (pauseFlag == '1') {
        errors.add('Printer is Paused');
      }
    }

    // Parse warnings
    if (hasWarnings) {
      warnings.addAll(_parseWarningFlags(warningGroup1, warningGroup2));
    }

    print('Found ${errors.length} errors and ${warnings.length} warnings');

    return SystemStatus(
      hasErrors: hasErrors,
      hasWarnings: hasWarnings,
      errors: errors,
      warnings: warnings,
    );
  }

  List<String> _parseErrorFlags(String group1, String group2) {
    final errors = <String>[];

    if (group1.length != 8 || group2.length != 8) {
      errors.add('Invalid error format');
      return errors;
    }

    // Parse Group 1 (nibbles 1-8)
    final nibbles = group1.split('').reversed.toList();

    // Nibble 1 (rightmost)
    final nibble1 = int.tryParse(nibbles[0], radix: 16) ?? 0;
    if (nibble1 & 0x8 != 0) errors.add('Cutter Fault');
    if (nibble1 & 0x4 != 0) errors.add('Head Open');
    if (nibble1 & 0x2 != 0) errors.add('Ribbon Out');
    if (nibble1 & 0x1 != 0) errors.add('Media Out');

    // Nibble 2
    final nibble2 = int.tryParse(nibbles[1], radix: 16) ?? 0;
    if (nibble2 & 0x8 != 0) errors.add('Printhead Detection Error');
    if (nibble2 & 0x4 != 0) errors.add('Bad Printhead Element');
    if (nibble2 & 0x2 != 0) errors.add('Motor Over Temperature');
    if (nibble2 & 0x1 != 0) errors.add('Printhead Over Temperature');

    // Nibble 3
    final nibble3 = int.tryParse(nibbles[2], radix: 16) ?? 0;
    if (nibble3 & 0x2 != 0) errors.add('Printhead Thermistor Open');
    if (nibble3 & 0x1 != 0) errors.add('Invalid Firmware Configuration');

    // Nibble 4
    final nibble4 = int.tryParse(nibbles[3], radix: 16) ?? 0;
    if (nibble4 & 0x8 != 0) errors.add('Clear Paper Path Failed');
    if (nibble4 & 0x4 != 0) errors.add('Paper Feed Error');
    if (nibble4 & 0x2 != 0) errors.add('Presenter Not Running');
    if (nibble4 & 0x1 != 0) errors.add('Paper Jam during Retract');

    // Nibble 5
    final nibble5 = int.tryParse(nibbles[4], radix: 16) ?? 0;
    if (nibble5 & 0x8 != 0) errors.add('Black Mark not Found');
    if (nibble5 & 0x4 != 0) errors.add('Black Mark Calibrate Error');
    if (nibble5 & 0x2 != 0) errors.add('Retract Function Timed Out');

    return errors;
  }

  List<String> _parseWarningFlags(String group1, String group2) {
    final warnings = <String>[];

    if (group1.length != 8 || group2.length != 8) {
      warnings.add('Invalid warning format');
      return warnings;
    }

    // Parse Group 1 (nibbles 1-8)
    final nibbles = group1.split('').reversed.toList();

    // Nibble 1 (rightmost)
    final nibble1 = int.tryParse(nibbles[0], radix: 16) ?? 0;
    if (nibble1 & 0x8 != 0) warnings.add('Paper Near End');
    if (nibble1 & 0x4 != 0) warnings.add('Replace Printhead');
    if (nibble1 & 0x2 != 0) warnings.add('Clean Printhead');
    if (nibble1 & 0x1 != 0) warnings.add('Need to Calibrate Media');

    // Nibble 2 - Sensor warnings (KR403 only)
    final nibble2 = int.tryParse(nibbles[1], radix: 16) ?? 0;
    if (nibble2 & 0x8 != 0) warnings.add('Sensor 4 Warning (Loop Ready)');
    if (nibble2 & 0x4 != 0) warnings.add('Sensor 3 Warning (Paper After Head)');
    if (nibble2 & 0x2 != 0) warnings.add('Sensor 2 Warning (Black Mark)');
    if (nibble2 & 0x1 != 0)
      warnings.add('Sensor 1 Warning (Paper Before Head)');

    // Nibble 3 - More sensor warnings (KR403 only)
    final nibble3 = int.tryParse(nibbles[2], radix: 16) ?? 0;
    if (nibble3 & 0x8 != 0) warnings.add('Sensor 8 Warning (At Bin)');
    if (nibble3 & 0x4 != 0) warnings.add('Sensor 7 Warning (In Retract)');
    if (nibble3 & 0x2 != 0) warnings.add('Sensor 6 Warning (Retract Ready)');
    if (nibble3 & 0x1 != 0) warnings.add('Sensor 5 Warning (Presenter)');

    return warnings;
  }
}

// Add this class at the top of the file (outside ZebraService class)
class SystemStatus {
  final bool hasErrors;
  final bool hasWarnings;
  final List<String> errors;
  final List<String> warnings;

  SystemStatus({
    required this.hasErrors,
    required this.hasWarnings,
    required this.errors,
    required this.warnings,
  });

  bool get hasIssues => hasErrors || hasWarnings;
}
