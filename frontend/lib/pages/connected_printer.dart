import 'package:flutter/material.dart';
import 'package:frontend/menu/connected_menu.dart';
import '../main.dart'; 

class ConnectedPrinter extends StatelessWidget {
  final String printerName;

  const ConnectedPrinter({super.key, required this.printerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(printerName),
      ),
      drawer: ConnectedMenu(printerName: printerName),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Details for $printerName'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                print('Unpairing from $printerName');

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyHomePage(title: 'Printer Setup'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Unpair Device'),
            ),
          ],
        ),
      ),
    );
  }
}
