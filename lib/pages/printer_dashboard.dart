import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../menu/connected_menu.dart';
import '../main.dart';
import 'templates.dart';
import '../services/zebra_service.dart';
import '../services/fetch_data.dart';
import '../services/printer_settings_helper.dart';
import 'printer_settings.dart';

class PrinterDashboard extends StatefulWidget {
  final String printerName;
  final SystemStatus? systemStatus;

  const PrinterDashboard({
    super.key,
    required this.printerName,
    this.systemStatus,
  });

  @override
  State<PrinterDashboard> createState() => _PrinterDashboardState();
}

class _PrinterDashboardState extends State<PrinterDashboard> {
  String? _modelName;
  String? _printerImageUrl;
  bool _loadingModel = true;
  SystemStatus? _systemStatus;
  Timer? _statusCheckTimer;
  bool _isCheckingStatus = false;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _systemStatus = widget.systemStatus;
    _fetchModelName();

    // Auto-show error dialog and start monitoring if there are errors
    if (_systemStatus?.hasErrors == true) {
      // Show dialog after the first frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_dialogShown) {
          _dialogShown = true;
          _showSystemStatusDialog();
        }
      });
      // Start periodic status checking
      _startStatusMonitoring();
    }
  }

  @override
  void dispose() {
    _stopStatusMonitoring();
    super.dispose();
  }

  // Refresh status when returning to this page
  Future<void> _refreshSystemStatus() async {
    if (_isCheckingStatus || !mounted) return;

    _isCheckingStatus = true;

    try {
      print('Refreshing system status on page resume...');
      final status = await ZebraService().getSystemStatus();

      if (!mounted) return;

      final hadErrors = _systemStatus?.hasErrors == true;
      final hasErrorsNow = status.hasErrors;

      setState(() {
        _systemStatus = status;
      });

      print(
        'Status refresh - Errors: ${status.hasErrors}, Warnings: ${status.hasWarnings}',
      );

      // If errors just appeared, show dialog and start monitoring
      if (hasErrorsNow && !hadErrors) {
        if (!_dialogShown) {
          _dialogShown = true;
          _showSystemStatusDialog();
        }
        _startStatusMonitoring();
      } else if (!hasErrorsNow) {
        // No errors, stop monitoring if running and reset dialog flag for future errors
        _stopStatusMonitoring();
        _dialogShown = false;
      }
    } catch (e) {
      print('Error refreshing system status: $e');
    } finally {
      _isCheckingStatus = false;
    }
  }

  void _startStatusMonitoring() {
    // Don't start if already running
    if (_statusCheckTimer != null) return;

    print('Starting system status monitoring every 5 seconds...');
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkSystemStatus();
    });
  }

  void _stopStatusMonitoring() {
    if (_statusCheckTimer != null) {
      print('Stopping system status monitoring');
      _statusCheckTimer?.cancel();
      _statusCheckTimer = null;
    }
  }

  Future<void> _checkSystemStatus() async {
    if (_isCheckingStatus || !mounted) return;

    _isCheckingStatus = true;

    try {
      print('Checking system status...');
      final status = await ZebraService().getSystemStatus();

      if (!mounted) return;

      setState(() {
        _systemStatus = status;
      });

      print(
        'Status check - Errors: ${status.hasErrors}, Warnings: ${status.hasWarnings}',
      );

      // If no more errors, stop monitoring and reset dialog flag for future errors
      if (!status.hasErrors) {
        print('No errors detected, stopping monitoring');
        _stopStatusMonitoring();
        _dialogShown = false;
      }
    } catch (e) {
      print('Error checking system status: $e');
    } finally {
      _isCheckingStatus = false;
    }
  }

  Future<void> _handleUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpeg', 'jpg', 'gif'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final extension = fileName.split('.').last.toLowerCase();

      if (!mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.black),
                      SizedBox(height: 16),
                      Text('Converting file to ZPL...'),
                    ],
                  ),
                ),
              ),
            ),
      );

      final settingsHelper = PrinterSettingsHelper();
      final settings = await settingsHelper.fetchAllSettings(
        forceRefresh: false,
      );

      print('Upload File - Printer settings received:');
      print('  labelWidthDots: ${settings['labelWidthDots']}');
      print('  labelWidthInches: ${settings['labelWidthInches']}');
      print('  labelHeight: ${settings['labelHeight']}');
      print('  dpi: ${settings['dpi']}');

      final widthDots =
          int.tryParse(
            settings['labelWidthDots'] ?? settings['labelWidth'] ?? '1200',
          ) ??
          1200;
      final heightDots =
          int.tryParse(settings['labelHeight'] ?? '1800') ?? 1800;
      final printerDpi = int.tryParse(settings['dpi'] ?? '203') ?? 203;

      print('Upload File - Parsed values:');
      print('  widthDots: $widthDots');
      print('  heightDots: $heightDots');
      print('  printerDpi: $printerDpi');

      // Use printer's native DPI for rendering to ensure correct physical size
      final int renderDpi = printerDpi;

      // Get width and height in inches for API (based on printer's actual dimensions)
      final widthInches =
          double.tryParse(settings['labelWidthInches'] ?? '') ??
          (widthDots / printerDpi);
      final heightInches = heightDots / printerDpi;

      // Calculate rendered dimensions in dots (for the ZPL output)
      // Since renderDpi == printerDpi, these equal the printer's native dots
      final renderWidthDots = (widthInches * renderDpi).round();
      final renderHeightDots = (heightInches * renderDpi).round();

      // Get rotation from orientation (convert to degrees)
      final orientationStr = settings['labelOrientation'] ?? 'normal';
      int rotation = 0;
      if (orientationStr.toLowerCase().contains('invert')) {
        rotation = 180;
      }

      // Read file as bytes
      final fileBytes = await file.readAsBytes();

      // Convert to ZPL based on file type
      String? zplContent;
      if (extension == 'pdf') {
        zplContent = await _convertPdfToZpl(
          pdfBytes: fileBytes,
          widthInches: widthInches,
          heightInches: heightInches,
          dpi: renderDpi,
          rotation: rotation,
        );
      } else {
        final imageFormat =
            (extension == 'jpg' || extension == 'jpeg') ? 'jpeg' : extension;
        zplContent = await _convertImageToZpl(
          imageBytes: fileBytes,
          imageFormat: imageFormat,
          widthInches: widthInches,
          heightInches: heightInches,
          dpi: renderDpi,
          rotation: rotation,
        );
      }

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (zplContent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to convert ${extension.toUpperCase()} to ZPL',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show the preview dialog
      // Use rendered dimensions for display, but keep printerDpi for reference
      final zpl = zplContent; // Capture non-null value
      showDialog(
        context: context,
        builder:
            (context) => _UploadedFilePreviewDialog(
              fileName: fileName,
              zplContent: zpl,
              widthDots: renderWidthDots,
              heightDots: renderHeightDots,
              printerDpi: renderDpi,
              onPrint: (quantity) async {
                return await _printZpl(
                  zpl,
                  quantity,
                  renderWidthDots,
                  renderHeightDots,
                );
              },
              onSaveTemplate: (templateName, zplParam) async {
                await _saveAsTemplate(
                  templateName,
                  zplParam,
                  renderWidthDots,
                  renderHeightDots,
                  renderDpi,
                );
              },
            ),
      );
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog if open
      Navigator.of(
        context,
      ).popUntil((route) => route.isFirst || route.settings.name != null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _convertPdfToZpl({
    required Uint8List pdfBytes,
    required double widthInches,
    required double heightInches,
    required int dpi,
    required int rotation,
  }) async {
    try {
      // Build params JSON for LabelZoom API
      final params = {
        'label': {'width': widthInches, 'height': heightInches},
        'dpi': dpi,
        'rotation': rotation,
        'colorMode': 'GRAYSCALE',
        'darkness': 70,
      };

      final paramsJson = json.encode(params);
      final encodedParams = Uri.encodeComponent(paramsJson);

      final url = Uri.parse(
        'https://labelzoom.net/api/v2/convert/pdf/to/zpl?params=$encodedParams',
      );

      print('Calling LabelZoom API:');
      print('  URL: $url');
      print('  Params: $paramsJson');
      print('  PDF size: ${pdfBytes.length} bytes');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/pdf',
          'Accept': 'text/plain',
          'User-Agent': 'ZebraPrinterApp/1.0 (Flutter)',
        },
        body: pdfBytes,
      );

      print('LabelZoom API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final zpl = response.body;
        print('ZPL received: ${zpl.length} characters');
        return zpl;
      } else {
        print('LabelZoom API error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error converting PDF to ZPL: $e');
      return null;
    }
  }

  Future<String?> _convertImageToZpl({
    required Uint8List imageBytes,
    required String imageFormat,
    required double widthInches,
    required double heightInches,
    required int dpi,
    required int rotation,
  }) async {
    try {
      // Build params JSON for LabelZoom API
      final params = {
        'label': {'width': widthInches, 'height': heightInches},
        'dpi': dpi,
        'rotation': rotation,
        'colorMode': 'GRAYSCALE',
        'darkness': 70,
      };

      final paramsJson = json.encode(params);
      final encodedParams = Uri.encodeComponent(paramsJson);

      // LabelZoom API endpoint for image conversion
      // Format: /convert/{sourceFormat}/to/zpl
      final url = Uri.parse(
        'https://labelzoom.net/api/v2/convert/$imageFormat/to/zpl?params=$encodedParams',
      );

      // Determine Content-Type based on format
      String contentType;
      switch (imageFormat) {
        case 'png':
          contentType = 'image/png';
          break;
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
        default:
          contentType = 'application/octet-stream';
      }

      print('Calling LabelZoom API for $imageFormat:');
      print('  URL: $url');
      print('  Params: $paramsJson');
      print('  Image size: ${imageBytes.length} bytes');
      print('  Content-Type: $contentType');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': contentType,
          'Accept': 'text/plain',
          'User-Agent': 'ZebraPrinterApp/1.0 (Flutter)',
        },
        body: imageBytes,
      );

      print('LabelZoom API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final zpl = response.body;
        print('ZPL received: ${zpl.length} characters');
        return zpl;
      } else {
        print('LabelZoom API error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error converting $imageFormat to ZPL: $e');
      return null;
    }
  }

  Future<SystemStatus?> _printZpl(
    String zplContent,
    int quantity,
    int widthDots,
    int heightDots,
  ) async {
    final zebraService = ZebraService();

    try {
      if (!zebraService.isConnected) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not connected to printer'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      String fullZpl;

      // Check if ZPL is already complete (from LabelZoom API)
      final trimmedZpl = zplContent.trim();
      if (trimmedZpl.startsWith('^XA') && trimmedZpl.endsWith('^XZ')) {
        // ZPL is complete, just add quantity if needed
        if (quantity > 1) {
          // Insert ^PQ before the final ^XZ
          fullZpl =
              trimmedZpl.substring(0, trimmedZpl.length - 3) +
              '^PQ$quantity\n^XZ';
        } else {
          fullZpl = trimmedZpl;
        }
      } else {
        // Wrap the ZPL content with proper commands
        fullZpl = '''
^XA
^PW$widthDots
^LL$heightDots

$zplContent

^PQ$quantity
^XZ
''';
      }

      await zebraService.printZpl(fullZpl);

      // Small delay to let printer process
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check system status after printing
      try {
        final status = await zebraService.getSystemStatus();
        return status;
      } catch (e) {
        print('Error checking system status: $e');
        return null;
      }
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  Future<void> _saveAsTemplate(
    String templateName,
    String zplContent,
    int widthDots,
    int heightDots,
    int renderDpi,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Generate a unique key
    int counter = 1;
    String templateKey = 'Custom Template $counter';
    final existingNamesJson = prefs.getString('template_names');
    Map<String, String> existingNames = {};

    if (existingNamesJson != null) {
      try {
        final decoded = json.decode(existingNamesJson) as Map<String, dynamic>;
        existingNames = decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      } catch (e) {
        print('Error loading template names: $e');
      }
    }

    while (existingNames.containsKey(templateKey) ||
        prefs.getString('template_zpl_$templateKey') != null) {
      counter++;
      templateKey = 'Custom Template $counter';
    }

    // Save the template with dimensions and render DPI
    existingNames[templateKey] = templateName;
    await prefs.setString('template_names', json.encode(existingNames));
    await prefs.setString('template_zpl_$templateKey', zplContent);
    // Save dimensions and render DPI so use_printer.dart can scale correctly
    await prefs.setInt('template_width_$templateKey', widthDots);
    await prefs.setInt('template_height_$templateKey', heightDots);
    await prefs.setInt('template_render_dpi_$templateKey', renderDpi);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "$templateName" saved!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _fetchModelName() async {
    final model = await ZebraService().getModelName();
    final searchName = model ?? widget.printerName;
    final result = await fetchModelName(searchName);

    if (!mounted) return;

    setState(() {
      _modelName = result['name'] ?? model;
      _printerImageUrl = result['image_url'];
      _loadingModel = false;
    });
  }

  void _showSystemStatusDialog() {
    if (_systemStatus == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  _systemStatus!.hasErrors ? Icons.error : Icons.warning,
                  color: _systemStatus!.hasErrors ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text('System Status'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_systemStatus!.errors.isNotEmpty) ...[
                    const Text(
                      'Errors:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._systemStatus!.errors.map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /*
                            const Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Colors.red,
                            ),
                            */
                            const SizedBox(width: 8),
                            Expanded(child: Text(error)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_systemStatus!.warnings.isNotEmpty) ...[
                    const Text(
                      'Warnings:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._systemStatus!.warnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(warning)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  //const SizedBox(height: 16),
                  //const Divider(color: Colors.black),
                  // const SizedBox(height: 8),
                  /*
                  if (_statusCheckTimer != null)
                    const Text(
                      'Monitoring status every 5 seconds...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    */
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _dialogShown = false;
                  Navigator.pop(context);
                },
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
    ).then((_) {
      // Reset dialog shown flag when dialog is dismissed
      _dialogShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;

    final containerWidth = (screenWidth * 0.9).clamp(300.0, 400.0);

    final infoContainerHeight = containerWidth * 0.486;
    final imageWidth = containerWidth * 0.4;
    final horizontalGap = 16.0;
    final buttonSize = (containerWidth - horizontalGap) / 2;
    final verticalGap = horizontalGap;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: const Color(0xFFF5F5F8),
        title: const Text(
          "Printer Dashboard",
          style: TextStyle(color: Colors.black),
        ),
        /*
        actions: [
          if (_systemStatus?.hasIssues == true)
            IconButton(
              icon: Icon(
                size: 24,
                _systemStatus!.hasErrors ? Icons.error : Icons.warning,
                color: _systemStatus!.hasErrors ? Colors.red : Colors.orange,
              ),
              onPressed: _showSystemStatusDialog,
              tooltip: 'View System Status',
            ),
        ],
        */
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.black, height: 1.0),
        ),
      ),
      drawer: ConnectedMenu(printerName: widget.printerName),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // First Container - Printer Info
              Container(
                width: containerWidth,
                height: infoContainerHeight,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Left side Printer Image
                    SizedBox(
                      width: imageWidth,
                      child:
                          _printerImageUrl != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _printerImageUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(
                                            Icons.image_not_supported,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                ),
                              )
                              : const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                    ),

                    const SizedBox(width: 16),

                    // Right side Printer Status
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Printer Name
                          Text(
                            _loadingModel
                                ? widget.printerName
                                : (_modelName ?? widget.printerName),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Status Row with error indicator
                          Row(
                            children: [
                              // Show icon for errors/warnings, green dot for ready
                              if (_systemStatus?.hasIssues == true)
                                GestureDetector(
                                  onTap: _showSystemStatusDialog,
                                  child: Icon(
                                    _systemStatus!.hasErrors
                                        ? Icons.error
                                        : Icons.warning,
                                    size: 16,
                                    color:
                                        _systemStatus!.hasErrors
                                            ? Colors.red
                                            : Colors.orange,
                                  ),
                                )
                              else
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _systemStatus?.hasErrors == true
                                      ? 'Error'
                                      : (_systemStatus?.hasWarnings == true
                                          ? 'Warning'
                                          : 'Ready to Print'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          /*
                          const Text(
                            'Connection Status: Connected',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Print head Temp: ',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Remaining Labels: ',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          */
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: containerWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Column 1
                    Column(
                      children: [
                        _buildActionButton(
                          context: context,
                          icon: Icons.print_outlined,
                          label: 'Templates',
                          color: Colors.black,
                          size: buttonSize,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UsePrinter(
                                      printerName: widget.printerName,
                                    ),
                              ),
                            ).then((result) {
                              // Handle result from templates page
                              if (result is TemplatesResult) {
                                // If user already acknowledged error, don't show dialog again
                                if (result.errorAcknowledged) {
                                  _dialogShown = true;
                                }
                                // Immediately update status if error was returned (faster than polling)
                                if (result.errorStatus != null) {
                                  setState(() {
                                    _systemStatus = result.errorStatus;
                                  });
                                  // Start monitoring since we have errors
                                  _startStatusMonitoring();
                                  return; // Skip the refresh since we already have status
                                }
                              }
                              // Refresh system status when returning from UsePrinter
                              _refreshSystemStatus();
                            });
                          },
                        ),
                        SizedBox(height: verticalGap),
                        _buildActionButton(
                          context: context,
                          icon: Icons.settings_outlined,
                          label: 'Printer Settings',
                          color: Colors.black,
                          size: buttonSize,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PrinterSettings(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // Column 2
                    Column(
                      children: [
                        _buildActionButton(
                          context: context,
                          icon: Icons.upload_file,
                          label: 'Upload File',
                          color: Colors.black,
                          size: buttonSize,
                          onTap: () => _handleUploadFile(),
                        ),

                        SizedBox(height: verticalGap),
                        _buildActionButton(
                          context: context,
                          icon: Icons.link_off,
                          label: 'Unpair',
                          color: Colors.black,
                          size: buttonSize,
                          onTap: () async {
                            await ZebraService().disconnect();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const MyHomePage(
                                      title: 'Printer Setup',
                                    ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(size * 0.11),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(icon, size: size * 0.33, color: color),
            ),
            SizedBox(height: size * 0.01),
            Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.093,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (label == 'Upload File') ...[
              const Text(
                'PDF, PNG, JPEG, GIF',
                style: TextStyle(color: Colors.black, fontSize: 8),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UploadedFilePreviewDialog extends StatefulWidget {
  final String fileName;
  final String zplContent;
  final int widthDots;
  final int heightDots;
  final int printerDpi;
  final Future<SystemStatus?> Function(int quantity) onPrint;
  final Future<void> Function(String templateName, String zpl) onSaveTemplate;

  const _UploadedFilePreviewDialog({
    required this.fileName,
    required this.zplContent,
    required this.widthDots,
    required this.heightDots,
    required this.printerDpi,
    required this.onPrint,
    required this.onSaveTemplate,
  });

  @override
  State<_UploadedFilePreviewDialog> createState() =>
      _UploadedFilePreviewDialogState();
}

class _UploadedFilePreviewDialogState
    extends State<_UploadedFilePreviewDialog> {
  Uint8List? _previewImage;
  bool _isLoadingPreview = true;
  String? _previewError;

  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _nameController = TextEditingController();
  String _currentTemplateName = '';

  int _quantity = 1;
  bool _isValidQuantity = true;
  bool _isEditingName = false;
  bool _isPrinting = false;
  bool _isSaving = false;
  String _editableZpl = '';

  @override
  void initState() {
    super.initState();
    _editableZpl = widget.zplContent;
    // Remove .pdf extension for template name
    _currentTemplateName = widget.fileName.replaceAll(
      RegExp(r'\.(pdf|zpl|txt)$', caseSensitive: false),
      '',
    );
    _nameController.text = _currentTemplateName;
    _fetchPreview();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });

    try {
      final widthInches = widget.widthDots / widget.printerDpi;
      final heightInches = widget.heightDots / widget.printerDpi;

      String dpmm;
      if (widget.printerDpi >= 580) {
        dpmm = '24dpmm';
      } else if (widget.printerDpi >= 280) {
        dpmm = '12dpmm';
      } else if (widget.printerDpi >= 180) {
        dpmm = '8dpmm';
      } else {
        dpmm = '6dpmm';
      }

      // Check if ZPL is already complete (from LabelZoom API)
      final trimmedZpl = _editableZpl.trim();
      String fullZpl;

      if (trimmedZpl.startsWith('^XA') && trimmedZpl.endsWith('^XZ')) {
        fullZpl = trimmedZpl;
      } else {
        fullZpl = '''
^XA
^PW${widget.widthDots}
^LL${widget.heightDots}

$_editableZpl

^XZ
''';
      }

      print('Requesting label preview from Labelary API');
      print('  DPMM: $dpmm');
      print(
        '  Dimensions: ${widthInches.toStringAsFixed(2)}" × ${heightInches.toStringAsFixed(2)}"',
      );
      print('  ZPL length: ${fullZpl.length} characters');

      final url = Uri.parse(
        'http://api.labelary.com/v1/printers/$dpmm/labels/${widthInches.toStringAsFixed(1)}x${heightInches.toStringAsFixed(1)}/0/',
      );

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'image/png',
            },
            body: fullZpl,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timeout - Labelary API took too long to respond',
              );
            },
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print(
          'Successfully received preview image (${response.bodyBytes.length} bytes)',
        );
        setState(() {
          _previewImage = response.bodyBytes;
          _isLoadingPreview = false;
        });
      } else {
        final errorMessage = response.body;
        print('Labelary API error (${response.statusCode}): $errorMessage');
        setState(() {
          _previewError =
              'Failed to generate preview (HTTP ${response.statusCode})';
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      print('Error loading label preview: $e');
      if (!mounted) return;
      setState(() {
        _previewError = 'Failed to load preview: ${e.toString()}';
        _isLoadingPreview = false;
      });
    }
  }

  void _showPrintErrorDialog(SystemStatus status) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Print Error'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Errors detected after printing:'),
                const SizedBox(height: 8),
                ...status.errors.map(
                  (error) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(error)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
    );
  }

  Future<void> _handlePrint() async {
    if (!_isValidQuantity || _isPrinting) return;

    setState(() => _isPrinting = true);

    try {
      final status = await widget.onPrint(_quantity);

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (status != null && status.hasErrors) {
        _showPrintErrorDialog(status);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent $_quantity label(s) to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSaveTemplate() async {
    if (_currentTemplateName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    await widget.onSaveTemplate(_currentTemplateName.trim(), _editableZpl);

    if (!mounted) return;
    setState(() => _isSaving = false);
    // Don't close dialog - user may want to print after saving
  }

  void _saveName() {
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = _currentTemplateName;
      setState(() => _isEditingName = false);
      return;
    }

    setState(() {
      _currentTemplateName = _nameController.text.trim();
      _isEditingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final widthInches = widget.widthDots / widget.printerDpi;
    final heightInches = widget.heightDots / widget.printerDpi;

    // Calculate preview constraints based on label height
    // For small labels (like 1x1), we don't want a huge preview area
    final maxPreviewHeight =
        (heightInches <= 2.0)
            ? 200.0
            : (heightInches <= 4.0)
            ? 300.0
            : 400.0;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with editable name
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F8),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Editable template name
                          _isEditingName
                              ? Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      cursorColor: Colors.black,
                                      controller: _nameController,
                                      autofocus: true,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                          ),
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) => _saveName(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check, size: 20),
                                    onPressed: _saveName,
                                    tooltip: 'Save',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      _nameController.text =
                                          _currentTemplateName;
                                      setState(() => _isEditingName = false);
                                    },
                                    tooltip: 'Cancel',
                                  ),
                                ],
                              )
                              : Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _currentTemplateName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () {
                                      setState(() => _isEditingName = true);
                                    },
                                    tooltip: 'Edit name',
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                          const SizedBox(height: 4),
                          Text(
                            '${widthInches.toStringAsFixed(2)}" × ${heightInches.toStringAsFixed(2)}"',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Only show dialog close button when not editing name
                    if (!_isEditingName)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                  ],
                ),
              ),

              // Save as Template Button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _handleSaveTemplate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                            : const Icon(Icons.save_alt, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save as Template'),
                  ),
                ),
              ),

              // Preview Area - constrained height based on label size
              Container(
                constraints: BoxConstraints(
                  maxHeight: maxPreviewHeight,
                  minHeight: 100,
                ),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildPreviewArea(),
              ),

              // Quantity and Print Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F8),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Print Quantity:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            cursorColor: Colors.black,
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      _isValidQuantity
                                          ? Colors.black
                                          : Colors.red,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      _isValidQuantity
                                          ? Colors.black
                                          : Colors.red,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      _isValidQuantity
                                          ? Colors.black
                                          : Colors.red,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              errorText: !_isValidQuantity ? 'Min 1' : null,
                              errorStyle: const TextStyle(fontSize: 10),
                            ),
                            onChanged: (value) {
                              if (value.isEmpty) {
                                if (_isValidQuantity != false ||
                                    _quantity != 0) {
                                  setState(() {
                                    _isValidQuantity = false;
                                    _quantity = 0;
                                  });
                                }
                                return;
                              }

                              final qty = int.tryParse(value);

                              if (qty == null || qty < 1) {
                                final newQty = qty ?? 0;
                                if (_isValidQuantity != false ||
                                    _quantity != newQty) {
                                  setState(() {
                                    _isValidQuantity = false;
                                    _quantity = newQty;
                                  });
                                }
                              } else if (qty > 999) {
                                if (_isValidQuantity != true ||
                                    _quantity != 999) {
                                  setState(() {
                                    _isValidQuantity = true;
                                    _quantity = 999;
                                    _quantityController.text = '999';
                                    _quantityController
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset: _quantityController.text.length,
                                      ),
                                    );
                                  });
                                }
                              } else {
                                if (_isValidQuantity != true ||
                                    _quantity != qty) {
                                  setState(() {
                                    _isValidQuantity = true;
                                    _quantity = qty;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (_isValidQuantity && !_isPrinting)
                                ? Colors.black
                                : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: (_isValidQuantity && !_isPrinting) ? 2 : 0,
                      ),
                      onPressed:
                          (_isValidQuantity && !_isPrinting)
                              ? _handlePrint
                              : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPrinting)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          else
                            Icon(
                              Icons.print,
                              size: 20,
                              color:
                                  _isValidQuantity ? Colors.white : Colors.grey,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isPrinting ? 'Printing...' : 'Print Label',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  (_isValidQuantity && !_isPrinting)
                                      ? Colors.white
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_isLoadingPreview) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.black),
            SizedBox(height: 16),
            Text(
              'Loading preview...',
              style: TextStyle(color: Colors.black, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_previewError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _previewError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchPreview,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }

    if (_previewImage != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.0,
        child: Image.memory(_previewImage!, fit: BoxFit.contain),
      );
    }

    return Center(
      child: Text(
        'No preview available',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
    );
  }
}
