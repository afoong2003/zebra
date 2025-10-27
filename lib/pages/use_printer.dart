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
      const zplCommand = '^XA^FX Top section with logo, name and address.^CF0,60^FO50,50^GB100,100,100^FS^FO75,75^FR^GB100,100,100^FS^FO93,93^GB40,40,40^FS^FO220,50^FDIntershipping, Inc.^FS^CF0,30^FO220,115^FD1000 Shipping Lane^FS^FO220,155^FDShelbyville TN 38102^FS^FO220,195^FDUnited States (USA)^FS^FO50,250^GB700,3,3^FS^FX Second section with recipient address and permit information.^CFA,30^FO50,300^FDJohn Doe^FS^FO50,340^FD100 Main Street^FS^FO50,380^FDSpringfield TN 39021^FS^FO50,420^FDUnited States (USA)^FS^CFA,15^FO600,300^GB150,150,3^FS^FO638,340^FDPermit^FS^FO638,390^FD123456^FS^FO50,500^GB700,3,3^FS^FX Third section with bar code.^BY5,2,270^FO100,550^BC^FD12345678^FS^FX Fourth section (the two boxes on the bottom).^FO50,900^GB700,250,3^FS^FO400,900^GB3,250,3^FS^CF0,40^FO100,960^FDCtr. X34B-1^FS^FO100,1010^FDREF1 F00B47^FS^FO100,1060^FDREF2 BL4H8^FS^CF0,190^FO470,955^FDCA^FS^XZ';
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