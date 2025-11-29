import 'package:flutter/material.dart';
import '../services/zebra_service.dart';
import '../services/printer_settings_helper.dart';

class PrinterSettings extends StatefulWidget {
  const PrinterSettings({super.key});

  @override
  State<PrinterSettings> createState() => _PrinterSettingsState();
}

class _PrinterSettingsState extends State<PrinterSettings> {
  final PrinterSettingsHelper _settingsHelper = PrinterSettingsHelper();

  late TextEditingController _widthController;
  late TextEditingController _heightController;

  String? mediaType;
  double? labelWidth;
  double? labelHeight;
  int? darkness;
  int? printSpeed;
  String? printMethod;
  int printerDpi = 203;
  String? labelOrientation;

  // Store original values to track changes
  String? _originalMediaType;
  double? _originalLabelWidth;
  double? _originalLabelHeight;
  int? _originalDarkness;
  int? _originalPrintSpeed;
  String? _originalPrintMethod;
  String? _originalLabelOrientation;

  bool loading = true;
  bool saving = false;
  bool calibratingMedia = false;

  List<String> availablePrintMethods = ['Direct Thermal', 'Thermal Transfer'];

  final List<String> availableMediaTypes = [
    'auto_detect',
    'gap/notch',
    'mark',
    'continuous',
  ];

  final List<String> availableOrientations = [
    '0', // degrees
    '90',
    '180',
    '270',
  ];

  // Check if any settings have changed
  bool get hasChanges {
    return mediaType != _originalMediaType ||
        labelWidth != _originalLabelWidth ||
        labelHeight != _originalLabelHeight ||
        darkness != _originalDarkness ||
        printSpeed != _originalPrintSpeed ||
        printMethod != _originalPrintMethod ||
        labelOrientation != _originalLabelOrientation;
  }

  // Information text for each setting
  final Map<String, String> settingInfo = {
    'media_type':
        'Media Type determines how the printer detects the gap between labels.\n\n'
        'Gap: Uses a sensor to detect physical gaps.\n'
        'Mark: Detects black marks on the backing. \n'
        'Continuous: For continuous media without gaps.\n\n'
        'Use Auto Detect to let the printer determine the best media type.',
    'label_size':
        'Label Width and Height define the size of your labels in inches. '
        'Calibrating the media will only return the length of the label. \n'
        'This ensures the printer knows how much media to use per label.\n\n'
        'Enter the dimensions of your label stock. Common sizes include:\n'
        '• 4" x 6" - Standard shipping labels\n'
        '• 4" x 3" - Small shipping labels\n'
        '• 3" x 2" - Medium product labels\n'
        '• 2" x 1" - Small product labels',
    'darkness':
        'Darkness controls how dark the print appears. '
        'Range: 0-30. Higher values produce darker prints. '
        'Adjust if labels are too light or too dark.',
    'print_speed':
        'Print Speed determines how fast labels are printed. '
        'Measured in inches per second (ips). '
        'Lower speeds may improve print quality for detailed labels. '
        'Please be aware that certain models have different maximum ips capabilities, '
        'refer to user manual for on your specific model for accurate information.',
    'print_method':
        'Print Method defines the technology used for printing. '
        'Direct Thermal: Uses heat-sensitive media (no ribbon required). '
        'Thermal Transfer: Uses a ribbon to transfer ink to the label.\n\n'
        'Available options depend on your printer model capabilities.',
    'label_orientation':
        'Label Orientation controls the rotation of the print on the label.\n\n',
  };

  // Show unsaved changes dialog
  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Unsaved Changes'),
              ],
            ),
            content: const Text(
              'You have unsaved changes. Are you sure you want to leave without saving?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Discard Changes',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
    );
  }
  /*
  Future<void> _calibrateMedia() async {
    setState(() => calibratingMedia = true);
    try {
      final zebraService = ZebraService();
      if (!zebraService.isConnected) {
        throw Exception("Printer not connected");
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Calibrating media... Please wait'),
              ],
            ),
            duration: Duration(seconds: 8),
            backgroundColor: Colors.blue,
          ),
        );
      }
      
      // Store original length to compare
      final originalLength = await getSgdValue('zpl.label_length');
      print('Original length before calibration: $originalLength');
      
      // Send calibration command - uses ZPL ~JC command which is more reliable
      print('Sending ZPL calibration command (~JC)...');
      await zebraService.connectedPrinter?.sendCommand('~JC\r\n');
      
      // Wait longer for physical calibration to complete (printer feeds labels)
      print(' Waiting for printer to feed and measure labels...');
      await Future.delayed(const Duration(seconds: 7));
      
      // Read the detected label length
      print(' Reading calibrated length...');
      final detectedLength = await getSgdValue('zpl.label_length');
      
      print(' Calibration results:');
      print('  Before: $originalLength"');
      print('  After: $detectedLength"');
      
      if (detectedLength != null && detectedLength.isNotEmpty && detectedLength != '?') {
        final lengthValue = double.tryParse(detectedLength);
        
        if (lengthValue != null && lengthValue > 0) {
          // Check if value actually changed
          if (detectedLength == originalLength) {
            print('Length unchanged - calibration may not have run');
            // Still update the UI in case it's correct
          }
          
          setState(() {
            labelHeight = lengthValue;
            _heightController.text = lengthValue.toStringAsFixed(1);
            print('Calibrated label length: $labelHeight"');
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  detectedLength == originalLength 
                    ? 'Media check complete: ${labelHeight?.toStringAsFixed(1)}" (unchanged)'
                    : 'Media calibrated! New length: ${labelHeight?.toStringAsFixed(1)}"'
                ),
                backgroundColor: detectedLength == originalLength ? Colors.orange : Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Invalid length value: $detectedLength');
        }
      } else {
        throw Exception('Could not read calibrated length');
      }
      
    } catch (e) {
      print('Error calibrating media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to calibrate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => calibratingMedia = false);
    }
  }*/

  // Detect available print methods based on printer capabilities
  Future<void> _detectAvailablePrintMethods() async {
    try {
      // Check if methods are already cached in the helper
      final cachedMethods = _settingsHelper.getCachedPrintMethods();

      if (cachedMethods != null && cachedMethods.isNotEmpty) {
        print('Using cached print methods: $cachedMethods');
        setState(() {
          availablePrintMethods = cachedMethods;

          // If current print method is not in the supported list, switch to the first available
          if (printMethod != null &&
              !availablePrintMethods.contains(printMethod)) {
            printMethod = availablePrintMethods.first;
            print(
              'Current print method not supported, switching to: $printMethod',
            );
          }
        });
        return; // Exit early - don't run detection
      }

      // If not cached, detect them
      print('No cached methods found, detecting supported print methods...');
      final supportedMethods =
          await _settingsHelper.detectSupportedPrintMethods();

      setState(() {
        availablePrintMethods = supportedMethods;

        // If current print method is not in the supported list, switch to the first available
        if (printMethod != null &&
            !availablePrintMethods.contains(printMethod)) {
          printMethod = availablePrintMethods.first;
          print(
            'Current print method not supported, switching to: $printMethod',
          );
        }
      });

      print('Available print methods: $availablePrintMethods');
    } catch (e) {
      print('Error detecting print methods: $e');
      setState(() {
        availablePrintMethods = ['Direct Thermal']; // Safe default
      });
    }
  }

  // Fetch current settings from the printer using SGD commands
  Future<void> fetchSettings() async {
    setState(() => loading = true);
    try {
      await _detectAvailablePrintMethods();

      // Detect printer DPI (only if not already detected)
      if (printerDpi == 203) {
        // Try to get from cache first
        final cachedSettings = await _settingsHelper.fetchAllSettings(
          forceRefresh: false,
        );
        final cachedDpi = cachedSettings['dpi'];

        if (cachedDpi != null && cachedDpi != '?') {
          printerDpi = int.tryParse(cachedDpi) ?? 203;
          print('Using cached DPI: $printerDpi');
        } else {
          // Only query printer if not in cache
          try {
            final dpiStr = await getSgdValue('head.resolution.in_dpi');
            if (dpiStr != null && dpiStr != '?') {
              printerDpi = int.tryParse(dpiStr) ?? 203;
              print('Detected printer DPI: $printerDpi');
            }
          } catch (e) {
            print(' Could not detect DPI: $e');
          }
        }
      }

      // Fetch settings (will use cache if available)
      print('Fetching printer settings...');
      final settings = await _settingsHelper.fetchAllSettings(
        forceRefresh: false,
      );

      final darknessStr = settings['darkness'];
      final speedStr = settings['speed'];
      final mediaTypeRaw = settings['mediaType']?.toLowerCase().trim();
      final printMethodStr = settings['printMethod'];
      final widthDots = settings['labelWidth'];
      final heightDots = settings['labelHeight'];

      setState(() {
        // Set media type
        if (mediaTypeRaw != null &&
            availableMediaTypes.contains(mediaTypeRaw)) {
          mediaType = mediaTypeRaw;
        } else if (mediaTypeRaw != null) {
          print(
            'Unexpected media type "$mediaTypeRaw", defaulting to gap/notch',
          );
          mediaType = 'gap/notch';
        } else {
          mediaType = 'gap/notch';
        }
        _originalMediaType = mediaType;

        // Parse label width from dots (cached value)
        if (widthDots != null && widthDots != '?') {
          final dots = double.tryParse(widthDots);
          if (dots != null) {
            labelWidth = dots / printerDpi;
            print(
              'Width from cache: $widthDots dots = ${labelWidth?.toStringAsFixed(1)}" (at $printerDpi DPI)',
            );
          }
        } else {
          labelWidth = 4.0; // Default
        }
        _widthController.text = labelWidth!.toStringAsFixed(1);
        _originalLabelWidth = labelWidth;

        // Parse label height from dots (cached value)
        if (heightDots != null && heightDots != '?') {
          final dots = double.tryParse(heightDots);
          if (dots != null) {
            // Check if value is likely in dots or inches
            if (dots < 50) {
              labelHeight = dots; // Already in inches
            } else {
              labelHeight = dots / printerDpi; // Convert dots to inches
            }
            print(
              ' Height from cache: $heightDots = ${labelHeight?.toStringAsFixed(1)}" (at $printerDpi DPI)',
            );
          }
        } else {
          labelHeight = 6.0; // Default
        }
        _heightController.text = labelHeight!.toStringAsFixed(1);
        _originalLabelHeight = labelHeight;

        // Parse darkness - handle both string and decimal format
        if (darknessStr != null &&
            darknessStr.isNotEmpty &&
            darknessStr != 'Unknown') {
          // Use double.tryParse to handle both "20" and "20.0" formats
          final doubleValue = double.tryParse(darknessStr);
          darkness = doubleValue?.round() ?? 10;
          print('Parsed darkness: "$darknessStr" -> $darkness');
        } else {
          darkness = 10;
          print('Using default darkness: 10');
        }
        _originalDarkness = darkness;

        // Parse speed - handle both string and decimal format
        if (speedStr != null && speedStr.isNotEmpty && speedStr != 'Unknown') {
          // Use double.tryParse to handle both "4" and "4.0" formats
          final doubleValue = double.tryParse(speedStr);
          final speedValue = doubleValue?.round() ?? 4;
          printSpeed = speedValue.clamp(2, 10);
          print('Parsed speed: "$speedStr" -> $printSpeed');
        } else {
          printSpeed = 4;
          print('Using default speed: 4');
        }
        _originalPrintSpeed = printSpeed;

        // Normalize print method from SGD to display format
        if (printMethodStr != null) {
          if (printMethodStr.contains('direct')) {
            printMethod = 'Direct Thermal';
          } else if (printMethodStr.contains('thermal trans') ||
              printMethodStr.contains('transfer')) {
            printMethod = 'Thermal Transfer';
          } else {
            printMethod = printMethodStr;
          }
        } else {
          printMethod = null;
        }
        _originalPrintMethod = printMethod;

        if (printMethod != null &&
            !availablePrintMethods.contains(printMethod)) {
          printMethod = availablePrintMethods.first;
          _originalPrintMethod = printMethod;
        }

        final orientationStr = settings['labelOrientation'];
        if (orientationStr != null &&
            availableOrientations.contains(orientationStr)) {
          labelOrientation = orientationStr;
        } else {
          labelOrientation = '0'; // Default 0 degrees
        }
        _originalLabelOrientation = labelOrientation;

        loading = false;
      });

      print('Settings fetched successfully (using cache):');
      print('  Media Type: $mediaType');
      print(
        '  Label Size: ${labelWidth?.toStringAsFixed(1)}" x ${labelHeight?.toStringAsFixed(1)}"',
      );
      print('  Darkness: $darkness');
      print('  Print Speed: $printSpeed');
      print('  Print Method: $printMethod');
    } catch (e) {
      print('Error fetching settings: $e');
      setState(() => loading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Save all settings at once
  Future<void> _saveAllSettings() async {
    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final zebraService = ZebraService();
      if (!zebraService.isConnected) {
        throw Exception("Printer not connected");
      }

      print('=== Starting to save settings ===');

      // Track what was actually saved for cache update
      Map<String, String?> updatedCache = {};

      // Save all changed settings sequentially
      if (mediaType != _originalMediaType && mediaType != null) {
        print('Saving media type: $mediaType');
        await setSgdValue('ezpl.media_type', mediaType!);
        updatedCache['mediaType'] = mediaType; //  Consistent format
      }

      if (labelWidth != _originalLabelWidth && labelWidth != null) {
        print('Saving label width: $labelWidth"');
        final widthDots = (labelWidth! * printerDpi).round();
        await setSgdValue('ezpl.print_width', widthDots.toString());
        // Update ALL width-related cache keys to stay in sync
        updatedCache['labelWidth'] = widthDots.toString();
        updatedCache['labelWidthDots'] = widthDots.toString();
        updatedCache['labelWidthInches'] = labelWidth!.toStringAsFixed(2);
        print(
          'Saved width as $widthDots dots ($labelWidth inches at $printerDpi DPI)',
        );
      }

      if (labelHeight != _originalLabelHeight && labelHeight != null) {
        print('Saving label height: $labelHeight"');
        final heightDots = (labelHeight! * printerDpi).round();
        await setSgdValue('zpl.label_length', heightDots.toString());
        updatedCache['labelHeight'] = heightDots.toString();
        print(
          'Saved height as $heightDots dots ($labelHeight inches at $printerDpi DPI)',
        );
      }

      if (darkness != _originalDarkness && darkness != null) {
        print('Saving darkness: $darkness');
        await setSgdValue('print.tone', darkness!.toString());
        updatedCache['darkness'] = darkness!.toString() + '.0';
      }

      if (printSpeed != _originalPrintSpeed && printSpeed != null) {
        print('Saving print speed: $printSpeed');
        await setSgdValue('media.speed', printSpeed!.toString());
        updatedCache['speed'] = printSpeed!.toString() + '.0';
      }

      if (printMethod != _originalPrintMethod && printMethod != null) {
        print('Saving print method: $printMethod');
        final sgdValue =
            printMethod == 'Thermal Transfer'
                ? 'thermal trans'
                : 'direct thermal';
        await setSgdValue('ezpl.print_method', sgdValue);
        updatedCache['printMethod'] = sgdValue;
      }

      if (labelOrientation != _originalLabelOrientation &&
          labelOrientation != null) {
        print('Saving label orientation: $labelOrientation');
        await setSgdValue('zpl.label_orientation', labelOrientation!);
        updatedCache['labelOrientation'] = labelOrientation;
      }

      // Small delay for settings to persist
      await Future.delayed(const Duration(milliseconds: 200));

      // UPDATE CACHE DIRECTLY instead of re-fetching
      if (updatedCache.isNotEmpty) {
        _settingsHelper.updateCachedSettings(updatedCache);
        print('Cache updated with ${updatedCache.length} changed settings');
      }

      // Update original values with what was saved
      setState(() {
        _originalMediaType = mediaType;
        _originalLabelWidth = labelWidth;
        _originalLabelHeight = labelHeight;
        _originalDarkness = darkness;
        _originalPrintSpeed = printSpeed;
        _originalPrintMethod = printMethod;
        _originalLabelOrientation = labelOrientation;
      });

      print('=== Settings saved successfully ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => saving = false);
    }
  }

  // Format media type for display
  String _formatMediaType(String type) {
    if (type.isEmpty) return type;

    // Special case for auto_detect
    if (type == 'auto_detect') {
      return 'Auto Detect';
    }

    // Special case for gap/notch
    if (type == 'gap/notch') {
      return 'Gap/Notch';
    }

    // Capitalize first letter for others
    return type[0].toUpperCase() + type.substring(1);
  }

  String _formatOrientation(String orientation) {
    switch (orientation) {
      case '0':
        return '0 Degrees';
      case '90':
        return '90 Degrees';
      case '180':
        return '180 Degrees';
      case '270':
        return '270 Degrees';
      default:
        return orientation;
    }
  }

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
    fetchSettings();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive dimensions
    final cardWidth = (screenWidth * 0.95).clamp(
      300.0,
      600.0,
    ); // 95% of screen, max 600px
    final horizontalPadding = (screenWidth - cardWidth) / 2; // Center the cards

    return PopScope(
      canPop: !hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0.0,
          title: const Text('Printer Settings'),
          backgroundColor: const Color(0xFFF5F5F8),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: Colors.black, height: 1.0),
          ),
          /*
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loading ? null : fetchSettings,
              tooltip: 'Refresh Settings',
            ),
          ],
          */
        ),
        body:
            loading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
                : GestureDetector(
                  onTap: () {
                    // Unfocus any text fields when tapping outside
                    FocusScope.of(context).unfocus();
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 16,
                          ),
                          children: [
                            // Label Size Card
                            SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Label Size',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),

                                          IconButton(
                                            icon: const Icon(
                                              Icons.help_outline,
                                              size: 20,
                                              color: Colors.black,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed:
                                                () => _showInfoDialog(
                                                  'Label Size',
                                                  settingInfo['label_size']!,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              cursorColor: Colors.black,
                                              key: ValueKey(
                                                'width_$labelWidth',
                                              ),
                                              controller: _widthController,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                labelText: 'Width (inches)',
                                                labelStyle: TextStyle(
                                                  color: Colors.black,
                                                ),
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                suffixText: '"',
                                                suffixStyle: TextStyle(
                                                  color: Colors.black,
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                              ),
                                              onChanged: (value) {
                                                if (value.isNotEmpty) {
                                                  labelWidth = double.tryParse(
                                                    value,
                                                  );
                                                } else {
                                                  labelWidth = null;
                                                }
                                              },
                                              onSubmitted: (value) {
                                                final width = double.tryParse(
                                                  value,
                                                );
                                                if (width == null ||
                                                    width <= 0) {
                                                  setState(() {
                                                    labelWidth =
                                                        _originalLabelWidth ??
                                                        4.0;
                                                    _widthController
                                                        .text = labelWidth!
                                                        .toStringAsFixed(1);
                                                  });
                                                } else {
                                                  setState(() {
                                                    labelWidth = width;
                                                    _widthController
                                                        .text = width
                                                        .toStringAsFixed(1);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: TextField(
                                              cursorColor: Colors.black,
                                              controller: _heightController,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                labelText: 'Height (inches)',
                                                labelStyle: TextStyle(
                                                  color: Colors.black,
                                                ),
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                suffixText: '"',
                                                suffixStyle: TextStyle(
                                                  color: Colors.black,
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                              ),
                                              onChanged: (value) {
                                                if (value.isNotEmpty) {
                                                  labelHeight = double.tryParse(
                                                    value,
                                                  );
                                                } else {
                                                  labelHeight = null;
                                                }
                                              },
                                              onSubmitted: (value) {
                                                final height = double.tryParse(
                                                  value,
                                                );
                                                if (height == null ||
                                                    height <= 0) {
                                                  setState(() {
                                                    labelHeight =
                                                        _originalLabelHeight ??
                                                        6.0;
                                                    _heightController
                                                        .text = labelHeight!
                                                        .toStringAsFixed(1);
                                                  });
                                                } else {
                                                  setState(() {
                                                    labelHeight = height;
                                                    _heightController
                                                        .text = height
                                                        .toStringAsFixed(1);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Darkness Slider Card
                            SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: Colors.white,
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      const Text(
                                        'Darkness',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.help_outline,
                                          size: 20,
                                          color: Colors.black,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            () => _showInfoDialog(
                                              'Darkness',
                                              settingInfo['darkness']!,
                                            ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Slider(
                                    activeColor: Colors.black,
                                    value: (darkness ?? 10).toDouble(),
                                    min: 0,
                                    max: 30,
                                    label: darkness?.toString(),
                                    onChanged: (value) {
                                      setState(() => darkness = value.toInt());
                                    },
                                  ),
                                  trailing: Text(
                                    '${darkness ?? 10}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Media Type Card
                            SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Media Type',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.help_outline,
                                                size: 20,
                                                color: Colors.black,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed:
                                                  () => _showInfoDialog(
                                                    'Media Type',
                                                    settingInfo['media_type']!,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.black,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            dropdownColor: Colors.white,
                                            value: mediaType,
                                            underline: const SizedBox(),
                                            isDense: true,
                                            isExpanded: false,
                                            items:
                                                availableMediaTypes
                                                    .map(
                                                      (type) =>
                                                          DropdownMenuItem(
                                                            value: type,
                                                            child: Text(
                                                              _formatMediaType(
                                                                type,
                                                              ),
                                                            ),
                                                          ),
                                                    )
                                                    .toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(
                                                  () => mediaType = value,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Label Orientation Card
                            SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Label',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const Text(
                                                'Orientation',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.help_outline,
                                              size: 20,
                                              color: Colors.black,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed:
                                                () => _showInfoDialog(
                                                  'Label Orientation',
                                                  settingInfo['label_orientation']!,
                                                ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.black,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: DropdownButton<String>(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          dropdownColor: Colors.white,
                                          value: labelOrientation,
                                          underline: const SizedBox(),
                                          isDense: true,
                                          isExpanded: false,
                                          items:
                                              availableOrientations
                                                  .map(
                                                    (orientation) =>
                                                        DropdownMenuItem(
                                                          value: orientation,
                                                          child: Text(
                                                            _formatOrientation(
                                                              orientation,
                                                            ),
                                                          ),
                                                        ),
                                                  )
                                                  .toList(),
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(
                                                () => labelOrientation = value,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Print Speed Card
                            SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Print Speed',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.help_outline,
                                                size: 20,
                                                color: Colors.black,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed:
                                                  () => _showInfoDialog(
                                                    'Print Speed',
                                                    settingInfo['print_speed']!,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.black,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: DropdownButton<int>(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            dropdownColor: Colors.white,
                                            value: printSpeed,
                                            underline: const SizedBox(),
                                            isDense: true,
                                            isExpanded: false,
                                            items:
                                                List.generate(9, (i) => i + 2)
                                                    .map(
                                                      (speed) =>
                                                          DropdownMenuItem(
                                                            value: speed,
                                                            child: Text(
                                                              '$speed ips',
                                                            ),
                                                          ),
                                                    )
                                                    .toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(
                                                  () => printSpeed = value,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Print Method Card
                            SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Print Method',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.help_outline,
                                                size: 20,
                                                color: Colors.black,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed:
                                                  () => _showInfoDialog(
                                                    'Print Method',
                                                    settingInfo['print_method']!,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child:
                                            availablePrintMethods.length == 1
                                                ? Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.black,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    color: Colors.grey.shade50,
                                                  ),
                                                  child: Text(
                                                    availablePrintMethods.first,
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                )
                                                : Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.black,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    dropdownColor: Colors.white,
                                                    value: printMethod,
                                                    underline: const SizedBox(),
                                                    isDense: true,
                                                    isExpanded: false,
                                                    items:
                                                        availablePrintMethods
                                                            .map(
                                                              (method) =>
                                                                  DropdownMenuItem(
                                                                    value:
                                                                        method,
                                                                    child: Text(
                                                                      method,
                                                                    ),
                                                                  ),
                                                            )
                                                            .toList(),
                                                    onChanged: (value) {
                                                      if (value != null) {
                                                        setState(
                                                          () =>
                                                              printMethod =
                                                                  value,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // DPI
                            SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Printer DPI',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.help_outline,
                                              size: 20,
                                              color: Colors.black,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed:
                                                () => _showInfoDialog(
                                                  'Printer DPI',
                                                  'DPI (Dots Per Inch) indicates the printer\'s resolution.\n\n'
                                                      'Common DPI values:\n'
                                                      '• 203 DPI - Standard resolution\n'
                                                      '• 300 DPI - High resolution\n'
                                                      '• 600 DPI - Ultra-high resolution\n\n'
                                                      'Higher DPI produces sharper, more detailed prints but may reduce print speed.\n\n'
                                                      'This is a fixed hardware specification and cannot be changed.',
                                                ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.black,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.grey.shade50,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$printerDpi DPI',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Save Settings Button at bottom
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,

                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: cardWidth,
                          child: ElevatedButton(
                            onPressed:
                                (saving || !hasChanges)
                                    ? null
                                    : _saveAllSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[600],
                            ),
                            child:
                                saving
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Text(
                                      hasChanges
                                          ? 'Save Settings'
                                          : 'No Changes',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  // Get SGD value from the printer - now uses helper
  Future<String?> getSgdValue(String key) async {
    return _settingsHelper.getSgdValue(key);
  }

  // Set SGD value on the printer - now uses helper
  Future<void> setSgdValue(String key, String value) async {
    return _settingsHelper.setSgdValue(key, value);
  }
}
