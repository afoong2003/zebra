import 'package:flutter/material.dart';
import 'package:frontend/services/zebra_service.dart'; 

class UsePrinter extends StatelessWidget {
  final String printerName;

  const UsePrinter({super.key, required this.printerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Print to $printerName'),
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
                child: const Text(
                  'Test Print',
                ),
                onPressed: () async {
                  print('UI: Tapped Test Print button for $printerName');
                  
                  final bool success = await ZebraService.printTestPage(printerName);

                  if (success) {
                    print('UI: Test print command sent successfully.');
                  } else {
                    print('UI: Failed to send test print command.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}