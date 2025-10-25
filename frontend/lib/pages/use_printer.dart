import 'package:flutter/material.dart';
import 'package:frontend/services/zebra_service.dart';

class UsePrinter extends StatefulWidget {
  final String printerName;

  const UsePrinter({super.key, required this.printerName});

  @override
  State<UsePrinter> createState() => _UsePrinterState();
}

class _UsePrinterState extends State<UsePrinter> {
  final ZebraService _zebraService = ZebraService();
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

      print('Printer is connected, sending ZPL command...');
      messenger.showSnackBar(
        const SnackBar(content: Text('Sending test print...')),
      );

      // Send test ZPL command
      const zplCommand = '^XA^PW800^FO0,300^A0N,100,100^FB800,1,0,C^FDHello World^FS^XZ';
      print('ZPL Command: $zplCommand');
      
      await _zebraService.printZpl(zplCommand);
      
      print('✅ Print command sent successfully!');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Test print sent successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ ERROR during print: $e');
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