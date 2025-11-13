import 'package:flutter/material.dart';
import '../services/zebra_service.dart';
import '../services/printer_settings_helper.dart';

class UsePrinter extends StatefulWidget {
  final String printerName;

  const UsePrinter({super.key, required this.printerName});

  @override
  State<UsePrinter> createState() => _UsePrinterState();
}

class _UsePrinterState extends State<UsePrinter> {
  final ZebraService _zebraService = ZebraService();
  final PrinterSettingsHelper _settingsHelper = PrinterSettingsHelper();
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        title: Text('Print to ${widget.printerName}'),
        backgroundColor: const Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: _isPrinting ? null : _handleTestPrint,
                child: _isPrinting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Test Print',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTestPrint() async {
    print('=== TEST PRINT STARTED ===');
    setState(() => _isPrinting = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      // Check connection
      if (!_zebraService.isConnected) {
        print('ERROR: Not connected to printer');
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Not connected to printer'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('Printer is connected, fetching current settings...');
      
      // Fetch current printer settings using shared helper
      final settings = await _settingsHelper.fetchAllSettings();
      
      final darkness = settings['darkness'] ?? 'Unknown';
      final speed = settings['speed'] ?? 'Unknown';
      final mediaType = settings['mediaType'] ?? 'Unknown';
      
      print('Fetched Settings:');
      print('  Darkness: $darkness');
      print('  Speed: $speed');
      print('  Media Type: $mediaType');
      
      // Detect printer DPI for accurate calculations
      int printerDpi = 203; // Default
      try {
        final dpiStr = await _settingsHelper.getSgdValue('head.resolution.in_dpi');
        if (dpiStr != null && dpiStr != '?') {
          printerDpi = int.tryParse(dpiStr) ?? 203;
          print('🖨️ Detected printer DPI: $printerDpi');
        }
      } catch (e) {
        print('⚠️ Could not detect DPI, using default 203');
      }
      
      // Fetch label dimensions dynamically
      double labelWidthInches = 4.0; // Default
      double labelHeightInches = 6.0; // Default
      
      // Get width from ezpl.print_width (in dots) and convert to inches
      final widthDots = await _settingsHelper.getSgdValue('ezpl.print_width');
      if (widthDots != null && widthDots != '?') {
        final dots = double.tryParse(widthDots);
        if (dots != null) {
          labelWidthInches = dots / printerDpi;
          print('📏 Width from ezpl.print_width: $widthDots dots = ${labelWidthInches.toStringAsFixed(1)}" (at $printerDpi DPI)');
        }
      } else {
        // Fallback to legacy keys (already in inches)
        final widthStr = await _settingsHelper.getSgdValue('zpl.label_width') ?? 
                         await _settingsHelper.getSgdValue('ezpl.media_width');
        if (widthStr != null && widthStr != '?') {
          labelWidthInches = double.tryParse(widthStr) ?? 4.0;
          print('📏 Width from legacy key: ${labelWidthInches.toStringAsFixed(1)}"');
        }
      }
      
      // Get height - CHECK if value is already in inches or needs conversion
      final heightStr = await _settingsHelper.getSgdValue('zpl.label_length') ?? 
                        await _settingsHelper.getSgdValue('ezpl.media_length');
      if (heightStr != null && heightStr != '?') {
        final heightValue = double.tryParse(heightStr);
        if (heightValue != null) {
          // Smart detection: if value is < 50, it's likely already in inches
          // If value is >= 50, it's likely in dots and needs conversion
          if (heightValue < 50) {
            // Already in inches (e.g., 6.0)
            labelHeightInches = heightValue;
            print('📏 Height from zpl.label_length: ${heightValue}" (already in inches)');
          } else {
            // In dots, convert to inches (e.g., 1800 dots)
            labelHeightInches = heightValue / printerDpi;
            print('📏 Height from zpl.label_length: ${heightValue.toInt()} dots = ${labelHeightInches.toStringAsFixed(1)}" (at $printerDpi DPI)');
          }
        } else {
          labelHeightInches = 6.0;
        }
      } else {
        labelHeightInches = 6.0;
      }
      
      // Calculate label dimensions in dots
      final labelWidthDots = (labelWidthInches * printerDpi).round();
      final labelHeightDots = (labelHeightInches * printerDpi).round();
      
      print('📐 Calculated dimensions:');
      print('  Width: ${labelWidthInches.toStringAsFixed(1)}" = $labelWidthDots dots');
      print('  Height: ${labelHeightInches.toStringAsFixed(1)}" = $labelHeightDots dots');

      messenger.showSnackBar(
        const SnackBar(content: Text('Sending test print...')),
      );

      // Create test label with current settings and dynamic dimensions
      final zplCommand = '''
^XA

^FX Set label dimensions dynamically based on printer settings
^PW$labelWidthDots
^LL$labelHeightDots

^FX Top section - Title
^CF0,50
^FO50,50^FDTest Label^FS

^FX Horizontal line separator
^FO50,120^GB${labelWidthDots - 100},2,2^FS

^FX Settings section
^CF0,35
^FO50,150^FDCurrent Settings:^FS

^CF0,28
^FO50,210^FDDarkness: $darkness^FS
^FO50,250^FDSpeed: $speed ips^FS
^FO50,290^FDMedia Type: $mediaType^FS
^FO50,330^FDLabel Size: ${labelWidthInches.toStringAsFixed(1)}" x ${labelHeightInches.toStringAsFixed(1)}"^FS
^FO50,370^FDDPI: $printerDpi^FS

^FX Horizontal line separator
^FO50,420^GB${labelWidthDots - 100},2,2^FS

^FX Barcode section (only if label is tall enough)
${labelHeightInches >= 4 ? '''
^CF0,35
^FO50,460^FDExample Barcode:^FS
^BY3,3,100
^FO100,520^BC^FD123456789012^FS
''' : ''}

^FX QR Code section (only if label is wide enough)
${labelWidthInches >= 3 ? '''
^CF0,35
^FO${labelWidthDots - 250},460^FDQR Code:^FS
^FO${labelWidthDots - 250},520^BQN,2,6^FDQA,Test Label Data^FS
''' : ''}

^FX Footer line
^FO50,${labelHeightDots - 200}^GB${labelWidthDots - 100},2,2^FS

^FX Test pattern boxes (only if label is tall enough)
${labelHeightInches >= 5 ? '''
^FO50,${labelHeightDots - 150}^GB150,100,3^FS
^FO${(labelWidthDots / 2 - 75).round()},${labelHeightDots - 150}^GB150,100,3^FS
^FO${labelWidthDots - 200},${labelHeightDots - 150}^GB150,100,3^FS
^CF0,20
^FO90,${labelHeightDots - 100}^FDBox 1^FS
^FO${(labelWidthDots / 2 - 35).round()},${labelHeightDots - 100}^FDBox 2^FS
^FO${labelWidthDots - 160},${labelHeightDots - 100}^FDBox 3^FS
''' : ''}

^XZ
''';
    
      print('ZPL Command being sent:');
      print(zplCommand);
      
      await _zebraService.printZpl(zplCommand);
      
      print('Print command sent successfully!');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Test print sent successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      print('ERROR during print: $e');
      print('Stack trace: $stackTrace');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isPrinting = false);
      print('=== TEST PRINT FINISHED ===');
    }
  }
}