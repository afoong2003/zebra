import 'package:flutter/material.dart';
import '../menu/connected_menu.dart';
import '../main.dart';
import 'use_printer.dart'; 
import '../services/zebra_service.dart';
import '../services/fetch_data.dart';
import 'printer_settings.dart';
import 'upload_file.dart';


class ConnectedPrinter extends StatefulWidget {
  final String printerName;

  const ConnectedPrinter({super.key, required this.printerName});

  @override
  State<ConnectedPrinter> createState() => _ConnectedPrinterState();
}

class _ConnectedPrinterState extends State<ConnectedPrinter> {
  String? _modelName;
  String? _printerImageUrl;
  bool _loadingModel = true;

  @override
  void initState() {
    super.initState();
    _fetchModelName();
  }

  Future<void> _fetchModelName() async {
    // Get model name from ZebraService (e.g., "ZD421")
    final model = await ZebraService().getModelName();
    
    // Use the model name or fallback to printerName from widget
    final searchName = model ?? widget.printerName;
    
    // Fetch from Supabase using the fetch_data service
    final result = await fetchModelName(searchName);
    
    setState(() {
      _modelName = result['name'] ?? model;
      _printerImageUrl = result['image_url'];
      _loadingModel = false;
    });
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 85, 
      height: 85, 
      child: Column(
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
              child: Icon(icon, size: 25),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: const Color(0xFFF5F5F8),
        title: _loadingModel
            ? Text(widget.printerName)
            : Text(_modelName ?? widget.printerName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
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
                      blurRadius: 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _printerImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _printerImageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                        ),
                      )
                    : const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
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
                              builder: (context) => UsePrinter(printerName: widget.printerName),
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
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UploadFile(),
                            ),
                          );
                        },
                      ),
                      //const SizedBox(width: 32),
                      _buildActionButton(
                        context: context,
                        icon: Icons.settings,
                        label: 'Printer Settings',
                        color: Colors.black,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PrinterSettings(),
                            ),
                          );


                        },
                      ),
                      //const SizedBox(width: 32),
                      _buildActionButton(
                        context: context,
                        icon: Icons.link_off,
                        label: 'Unpair',
                        color: Colors.black,
                        onTap: () async {
                          await ZebraService().disconnect();
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
