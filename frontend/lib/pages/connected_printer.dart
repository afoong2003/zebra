import 'package:flutter/material.dart';
import 'package:frontend/menu/connected_menu.dart';
import '../main.dart';
import 'use_printer.dart'; 

class ConnectedPrinter extends StatelessWidget {
  final String printerName;

  const ConnectedPrinter({super.key, required this.printerName});

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40), 
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F8),
        title: Text(printerName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      drawer: ConnectedMenu(printerName: printerName),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // First Container: Printer Image
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
             
            ),
            const SizedBox(height: 16),
            
            const SizedBox(height: 48), 

            // Second Container: Functionality as a Row of Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context: context,
                  icon: Icons.print,
                  label: 'Print Actions',
                  color: Colors.black,
                  onTap: () {
                    print('Tapped Print');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsePrinter(printerName: printerName),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context: context,
                  icon: Icons.upload_file,
                  label: 'Upload File',
                  color: Colors.black,
                  onTap: () {
                  },
                ),
                _buildActionButton(
                  context: context,
                  icon: Icons.settings,
                  label: 'Printer Settings',
                  color: Colors.black,
                  onTap: () {
                  },
                ),
                _buildActionButton(
                  context: context,
                  icon: Icons.link_off,
                  label: 'Unpair',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyHomePage(title: 'Printer Setup'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
