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
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: Icon(icon, size: 30), // smaller icon
          ),
        ),
        const SizedBox(height: 6), // less vertical space
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 12, 
          ),
          textAlign: TextAlign.center,
        ),
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
        child: Center( // <-- Add this
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // <-- Vertical centering
            crossAxisAlignment: CrossAxisAlignment.center, // <-- Horizontal centering
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
                      color: Colors.grey,
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48), 

              // Second Container: Functionality as a Row of Buttons ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                      //const SizedBox(width: 32), 
                      _buildActionButton(
                        context: context,
                        icon: Icons.upload_file,
                        label: 'Upload File',
                        color: Colors.black,
                        onTap: () {},
                      ),
                      //const SizedBox(width: 32),
                      _buildActionButton(
                        context: context,
                        icon: Icons.settings,
                        label: 'Printer Settings',
                        color: Colors.black,
                        onTap: () {},
                      ),
                      //const SizedBox(width: 32),
                      _buildActionButton(
                        context: context,
                        icon: Icons.link_off,
                        label: 'Unpair',
                        color: Colors.black,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
