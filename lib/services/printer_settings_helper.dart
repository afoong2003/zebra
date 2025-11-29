import '../services/zebra_service.dart';

class PrinterSettingsHelper {
  static final PrinterSettingsHelper _instance =
      PrinterSettingsHelper._internal();
  factory PrinterSettingsHelper() => _instance;
  PrinterSettingsHelper._internal();

  final ZebraService _zebraService = ZebraService();

  // Store which keys actually worked for this printer
  String? _workingDarknessKey;
  String? _workingSpeedKey;
  String? _workingPrintMethodKey;

  // Cached settings
  Map<String, String?>? _cachedSettings;
  bool _settingsCached = false;

  bool _printMethodsCached = false;
  List<String> _cachedPrintMethods = [];

  // Get SGD value from the printer
  Future<String?> getSgdValue(String key) async {
    try {
      if (!_zebraService.isConnected) {
        throw Exception("Printer not connected");
      }

      final command = '! U1 getvar "$key"\r\n';
      print('Sending SGD command: $command');
      final response = await _zebraService.connectedPrinter
          ?.sendCommandAndGetResponse(command);

      if (response != null && response.isNotEmpty) {
        String value = response.trim();
        print('Raw SGD response for $key: "$value"');

        // Remove quotes if present
        if (value.startsWith('"') && value.endsWith('"') && value.length > 1) {
          value = value.substring(1, value.length - 1);
        }

        // Check if it's an error response
        if (value.toLowerCase().contains('error') || value == '?') {
          print('Error response for $key: $value');
          return null;
        }

        print('getSgdValue($key): $value');
        return value;
      } else {
        print('No response for $key');
      }
      return null;
    } catch (e) {
      print('Error getting SGD value for $key: $e');
      return null;
    }
  }

  // Set SGD value on the printer - uses cached working key if available
  Future<void> setSgdValue(String key, String value) async {
    try {
      if (!_zebraService.isConnected) {
        throw Exception("Printer not connected");
      }

      // If we're setting darkness/speed/printMethod, use the cached working key if available
      String actualKey = key;
      if (key == 'print.tone' && _workingDarknessKey != null) {
        actualKey = _workingDarknessKey!;
        print('Using cached darkness key: $actualKey');
      } else if (key == 'media.speed' && _workingSpeedKey != null) {
        actualKey = _workingSpeedKey!;
        print('Using cached speed key: $actualKey');
      } else if (key == 'ezpl.print_method' && _workingPrintMethodKey != null) {
        actualKey = _workingPrintMethodKey!;
        print('Using cached print method key: $actualKey');
      }

      final command = '! U1 setvar "$actualKey" "$value"\r\n';
      print('Setting SGD value: $actualKey = $value');
      await _zebraService.connectedPrinter?.sendCommand(command);

      // Small delay to ensure command is processed
      await Future.delayed(const Duration(milliseconds: 50));

      print('setSgdValue($actualKey): $value completed');
    } catch (e) {
      print('Error setting SGD value for $key: $e');
      rethrow;
    }
  }

  List<String>? getCachedPrintMethods() {
    if (_printMethodsCached && _cachedPrintMethods.isNotEmpty) {
      print('Returning cached print methods: $_cachedPrintMethods');
      return List<String>.from(_cachedPrintMethods);
    }
    print('No cached print methods available');
    return null;
  }

  // Check which print methods are supported by the printer
  Future<List<String>> detectSupportedPrintMethods() async {
    // Return cached results if available
    if (_printMethodsCached && _cachedPrintMethods.isNotEmpty) {
      print('Using cached print methods: $_cachedPrintMethods');
      return List<String>.from(_cachedPrintMethods);
    }

    print('Detecting supported print methods');

    final List<String> supported = [];
    String? originalMethod;

    try {
      originalMethod = await getSgdValue('ezpl.print_method');
      print('Current print method: $originalMethod');
    } catch (e) {
      print('Could not get current print method: $e');
    }

    // Test direct thermal
    try {
      await setSgdValue('ezpl.print_method', 'direct thermal');
      await Future.delayed(const Duration(milliseconds: 100));
      final verifyDirect = await getSgdValue('ezpl.print_method');
      if (verifyDirect?.toLowerCase().contains('direct') ?? false) {
        supported.add('Direct Thermal');
        print('Direct Thermal is supported');
      }
    } catch (e) {
      print('Direct Thermal test failed: $e');
    }

    // Test thermal transfer
    try {
      await setSgdValue('ezpl.print_method', 'thermal trans');
      await Future.delayed(const Duration(milliseconds: 100));
      final verifyTransfer = await getSgdValue('ezpl.print_method');
      if (verifyTransfer?.toLowerCase().contains('thermal trans') ?? false) {
        supported.add('Thermal Transfer');
        print('Thermal Transfer is supported');
      }
    } catch (e) {
      print('Thermal Transfer test failed: $e');
    }

    if (originalMethod != null) {
      try {
        await setSgdValue('ezpl.print_method', originalMethod);
        print('Restored original print method: $originalMethod');
      } catch (e) {
        print('Could not restore original method: $e');
      }
    }

    if (supported.isNotEmpty) {
      _workingPrintMethodKey = 'ezpl.print_method';
      print('Supported print methods: $supported');
      _cachedPrintMethods = supported;
      _printMethodsCached = true;
      print('Cached print methods for future use');
      return supported;
    }
    /*
    print('Could not detect print methods, defaulting to Direct Thermal only');
    final defaultMethods = ['Direct Thermal'];
    _cachedPrintMethods = defaultMethods;
    _printMethodsCached = true;
    return defaultMethods;
    */
    return supported;
  }

  Future<Map<String, String?>> fetchAllSettings({
    bool forceRefresh = false,
  }) async {
    // Return cached settings if available and not forcing refresh
    if (_settingsCached && _cachedSettings != null && !forceRefresh) {
      print('Using cached printer settings');
      return Map<String, String?>.from(_cachedSettings!);
    }

    try {
      String? darkness;
      String? speed;
      String? printMethod;
      String? mediaType;
      String? labelWidthInches;
      String? labelWidthDots;
      String? labelHeight;
      String? labelOrientation;
      String? dpi;

      print('Fetching settings sequentially...');

      // Fetch darkness
      darkness = await getSgdValue('print.tone');
      if (darkness != null) {
        _workingDarknessKey = 'print.tone';
      }

      print("Fetching label orientation");
      labelOrientation = await getSgdValue('zpl.label_orientation');

      // Fetch speed
      speed = await getSgdValue('media.speed');
      if (speed != null) {
        _workingSpeedKey = 'media.speed';
      }

      // Fetch print method
      printMethod = await getSgdValue('ezpl.print_method');
      if (printMethod != null) {
        _workingPrintMethodKey = 'ezpl.print_method';
      }

      // Fetch media type
      mediaType = await getSgdValue('ezpl.media_type');

      print('Fetching printer DPI');
      dpi = await getSgdValue('head.resolution.in_dpi');
      if (dpi != null && dpi.isNotEmpty) {
        print('Found DPI: $dpi');
      } else {
        print('DPI not found, using default 203');
        dpi = '203';
      }
      final printerDpi = int.tryParse(dpi) ?? 203;

      print('Fetching label dimensions');

      // Width - Try ezpl.print_width first (returns DOTS, not inches!)
      labelWidthDots = await getSgdValue('ezpl.print_width');
      if (labelWidthDots != null &&
          labelWidthDots.isNotEmpty &&
          labelWidthDots != '?') {
        print('Raw label width: $labelWidthDots dots');

        // Convert dots to inches for storage
        final widthDots = int.tryParse(labelWidthDots) ?? 1200;
        final widthInches = widthDots / printerDpi;
        labelWidthInches = widthInches.toStringAsFixed(2);

        print(
          'Converted label width: $labelWidthDots dots = $labelWidthInches" (at $printerDpi DPI)',
        );
      } else {
        print('Label width not found, using defaults');
        labelWidthDots = '1200'; // Default dots
        labelWidthInches = (1200 / printerDpi).toStringAsFixed(
          2,
        ); // Calculate inches
        print('Default label width: $labelWidthDots dots = $labelWidthInches"');
      }

      // Height - zpl.label_length returns DOTS
      labelHeight = await getSgdValue('zpl.label_length');
      if (labelHeight == null || labelHeight.isEmpty || labelHeight == '?') {
        print('Label height not found, using default 1800 dots');
        labelHeight = '1800';
      } else {
        print('Raw label height: $labelHeight dots');
      }

      //  Cache the settings with both width formats
      print('Caching printer settings');
      _cachedSettings = {
        'mediaType': mediaType,
        'darkness': darkness,
        'speed': speed,
        'printMethod': printMethod,
        'labelWidthInches': labelWidthInches,
        'labelWidth': labelWidthDots,
        'labelWidthDots': labelWidthDots,
        'labelHeight': labelHeight,
        'labelOrientation': labelOrientation,
        'dpi': dpi,
      };
      _settingsCached = true;

      print('-----Final fetched settings-----');
      print('  Darkness: $darkness (key: $_workingDarknessKey)');
      print('  Speed: $speed (key: $_workingSpeedKey)');
      print('  Media Type: $mediaType');
      print('  Print Method: $printMethod (key: $_workingPrintMethodKey)');
      print('  Label Width: $labelWidthInches" = $labelWidthDots dots');
      print('  Label Height: $labelHeight dots');
      print('  Label Orientation: $labelOrientation');
      print('  DPI: $dpi');
      print('-----------------------------------');

      return _cachedSettings!;
    } catch (e) {
      print('Error fetching all settings: $e');
      return {
        'mediaType': null,
        'darkness': null,
        'speed': null,
        'printMethod': null,
        'labelWidthInches': null,
        'labelWidth': null,
        'labelWidthDots': null,
        'labelHeight': null,
        'labelOrientation': null,
        'dpi': null,
      };
    }
  }

  // Reset cached keys (useful when connecting to a different printer)
  void resetCachedKeys() {
    print('Resetting cached SGD keys, settings, and print methods');
    _workingDarknessKey = null;
    _workingSpeedKey = null;
    _workingPrintMethodKey = null;
    _cachedSettings = null;
    _settingsCached = false;
    _printMethodsCached = false;
    _cachedPrintMethods = [];
  }

  // Add method to clear cache if needed
  void resetPrintMethodsCache() {
    _printMethodsCached = false;
    _cachedPrintMethods = [];
    print('Cleared print methods cache');
  }

  /// Update cached settings without re-fetching from printer
  /// This keeps the cache in sync after saving settings
  void updateCachedSettings(Map<String, String?> updatedValues) {
    if (_cachedSettings == null) {
      print('Cache not initialized, creating new cache');
      _cachedSettings = {};
    }

    // Update only the provided keys
    _cachedSettings!.addAll(updatedValues);
    _settingsCached = true;

    print('Cache updated with new values:');
    updatedValues.forEach((key, value) {
      print('$key: $value');
    });
  }
}
