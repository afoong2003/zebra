import '../services/zebra_service.dart';

class PrinterSettingsHelper {
  static final PrinterSettingsHelper _instance = PrinterSettingsHelper._internal();
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

  // Add static cache for print methods
  static bool _printMethodsCached = false;
  static List<String> _cachedPrintMethods = [];

  // Get SGD value from the printer
  Future<String?> getSgdValue(String key) async {
    try {
      if (!_zebraService.isConnected) {
        throw Exception("Printer not connected");
      }
      
      final command = '! U1 getvar "$key"\r\n';
      print('Sending SGD command: $command');
      final response = await _zebraService.connectedPrinter?.sendCommandAndGetResponse(command);
      
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

  // Check which print methods are supported by the printer
  Future<List<String>> detectSupportedPrintMethods() async {
    // Return cached results if available
    if (_printMethodsCached && _cachedPrintMethods.isNotEmpty) {
      print('Using cached print methods: $_cachedPrintMethods');
      return List<String>.from(_cachedPrintMethods);
    }
    
    print('Detecting supported print methods');
    
    // Try to get current print method
    final currentMethod = await getSgdValue('ezpl.print_method');
    
    if (currentMethod != null) {
      final normalized = currentMethod.toLowerCase().trim();
      print('Current print method: $normalized');
      
      // If we can read the value, the printer supports print method setting
      // Try setting it to both values to see what's accepted
      final List<String> supported = [];
      
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
        print(' Direct Thermal test failed: $e');
      }
      
      // Test thermal transfer
      try {
        await setSgdValue('ezpl.print_method', 'thermal trans');
        await Future.delayed(const Duration(milliseconds: 100));
        final verifyTransfer = await getSgdValue('ezpl.print_method');
        if (verifyTransfer?.toLowerCase().contains('thermal trans') ?? false) {
          supported.add('Thermal Transfer');
          print(' Thermal Transfer is supported');
        }
      } catch (e) {
        print('Thermal Transfer test failed: $e');
      }
      
      // Restore original method
      await setSgdValue('ezpl.print_method', normalized);
      
      if (supported.isNotEmpty) {
        _workingPrintMethodKey = 'ezpl.print_method';
        print('Supported print methods: $supported');
        // At the end, before returning, cache the results:
        _cachedPrintMethods = supported;
        _printMethodsCached = true;
        print('Cached print methods for future use');
        return supported;
      }
    }
    
    // Fallback: check device.head_type to determine capabilities
    final headType = await getSgdValue('device.head_type');
    if (headType != null) {
      final type = headType.toLowerCase();
      print('Head type: $type');
      
      if (type.contains('direct') && !type.contains('thermal transfer')) {
        print('Printer only supports Direct Thermal');
        return ['Direct Thermal'];
      } else if (type.contains('thermal transfer') || type.contains('tt')) {
        print('Printer supports both methods');
        return ['Direct Thermal', 'Thermal Transfer'];
      }
    }
    
    // Default fallback
    print('Could not detect print methods, defaulting to Direct Thermal only');
    return ['Direct Thermal'];
  }

  Future<Map<String, String?>> fetchAllSettings({bool forceRefresh = false}) async {
    // Return cached settings if available and not forcing refresh
    if (_settingsCached && _cachedSettings != null && !forceRefresh) {
      print('Using cached printer settings (including label dimensions)');
      return Map<String, String?>.from(_cachedSettings!);
    }

    try {
      final darknessKeys = ['print.tone'];
      final speedKeys = ['media.speed'];
      final printMethodKeys = ['ezpl.print_method'];
      
      String? darkness;
      String? speed;
      String? printMethod;
      String? mediaType;
      String? labelWidth;   
      String? labelHeight;  
      
      print('Fetching settings sequentially...');
      
      // Fetch darkness
      darkness = await getSgdValue(darknessKeys[0]);
      if (darkness == null || darkness.isEmpty || darkness == 'Unknown') {
        print('Primary darkness key failed, trying alternatives...');
        for (int i = 1; i < darknessKeys.length; i++) {
          darkness = await getSgdValue(darknessKeys[i]);
          if (darkness != null && darkness.isNotEmpty && darkness != 'Unknown') {
            _workingDarknessKey = darknessKeys[i];
            print('Found darkness at alternative key: ${darknessKeys[i]} = $darkness');
            break;
          }
        }
      } else {
        _workingDarknessKey = darknessKeys[0];
        print('Found darkness at primary key: ${darknessKeys[0]} = $darkness');
      }
      
      // Fetch speed
      speed = await getSgdValue(speedKeys[0]);
      if (speed == null || speed.isEmpty || speed == 'Unknown') {
        print('Primary speed key failed, trying alternatives...');
        for (int i = 1; i < speedKeys.length; i++) {
          speed = await getSgdValue(speedKeys[i]);
          if (speed != null && speed.isNotEmpty && speed != 'Unknown') {
            _workingSpeedKey = speedKeys[i];
            print('Found speed at alternative key: ${speedKeys[i]} = $speed');
            break;
          }
        }
      } else {
        _workingSpeedKey = speedKeys[0];
        print('Found speed at primary key: ${speedKeys[0]} = $speed');
      }
      
      // Fetch print method - try ezpl.print_method first (correct key)
      printMethod = await getSgdValue(printMethodKeys[0]);
      if (printMethod == null || printMethod.isEmpty || printMethod == 'Unknown') {
        print('Primary print method key failed, trying alternatives...');
        for (int i = 1; i < printMethodKeys.length; i++) {
          printMethod = await getSgdValue(printMethodKeys[i]);
          if (printMethod != null && printMethod.isNotEmpty && printMethod != 'Unknown') {
            _workingPrintMethodKey = printMethodKeys[i];
            print('Found print method at alternative key: ${printMethodKeys[i]} = $printMethod');
            break;
          }
        }
      } else {
        _workingPrintMethodKey = printMethodKeys[0];
        print('Found print method at primary key: ${printMethodKeys[0]} = $printMethod');
      }
      
      // Fetch media type 
      mediaType = await getSgdValue('ezpl.media_type');
      
      /*
      if (mediaType == null || mediaType.isEmpty || mediaType == 'Unknown') {
        print('ezpl.media_type not found, trying legacy media.type key...');
        final legacyType = await getSgdValue('media.type');
        
        if (legacyType != null) {
          final normalized = legacyType.toLowerCase().trim();
          // Map legacy values to EZPL standard
          if (normalized == 'journal' || normalized == 'web') {
            mediaType = 'continuous';
            print('📋 Normalized legacy media type "$normalized" to "continuous"');
          } else if (normalized == 'gap') {
            mediaType = 'gap/notch';
            print('📋 Normalized media type "gap" to "gap/notch"');
          } else if (normalized == 'cutter') {
            mediaType = 'gap/notch'; // Cutter mode typically uses gap detection
            print('📋 Normalized media type "cutter" to "gap/notch"');
          } else if (normalized == 'auto_detect' || normalized == 'auto detect') {
            mediaType = 'auto_detect';
            print('📋 Media type set to auto_detect');
          }
        }
      }
      */
      // Fetch label dimensions
      print('Fetching label dimensions');
      labelWidth = await getSgdValue('ezpl.print_width');
      labelHeight = await getSgdValue('zpl.label_length');
      
      // Set defaults if still null
      _workingDarknessKey ??= darknessKeys.first;
      _workingSpeedKey ??= speedKeys.first;
      _workingPrintMethodKey ??= printMethodKeys.first;

      // Cache the settings 
      print('Caching printer settings (including label dimensions) for fast access');
      _cachedSettings = {
        'mediaType': mediaType,
        'darkness': darkness,
        'speed': speed,
        'printMethod': printMethod,
        'labelWidth': labelWidth,   
        'labelHeight': labelHeight,
      };
      _settingsCached = true;

      print('-----Final fetched settings-----');
      print('  Darkness: $darkness (key: $_workingDarknessKey)');
      print('  Speed: $speed (key: $_workingSpeedKey)');
      print('  Media Type: $mediaType');
      print('  Print Method: $printMethod (key: $_workingPrintMethodKey)');
      print('  Label Width: $labelWidth dots');   
      print('  Label Height: $labelHeight dots'); 
      print('-----------------------------------');

      return _cachedSettings!;
    } catch (e) {
      print('Error fetching all settings: $e');
      return {
        'mediaType': null,
        'darkness': null,
        'speed': null,
        'printMethod': null,
        'labelWidth': null,   
        'labelHeight': null,  
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
      print('   $key: $value');
    });
  }
}