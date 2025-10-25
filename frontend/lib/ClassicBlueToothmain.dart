
/*

import 'package:flutter/material.dart';
import 'package:frontend/menu/unconnected_menu.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pages/connected_printer.dart';
import 'services/zebra_service.dart';
import 'dart:async';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        scaffoldBackgroundColor: Color(0xFFF5F5F8),
      ),
  
      home: const MyHomePage(title: 'Printer Setup'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isDiscoveredPrintersExpanded = false;
  bool _isDiscovering = false; 
  List<String> _printerNames = []; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndRequestBluetoothPermission();
    });
  }

  Future<void> checkAndRequestBluetoothPermission() async {
    PermissionStatus bluetoothStatus = await Permission.bluetooth.status;
    PermissionStatus locationStatus = await Permission.locationWhenInUse.status;

    if (!locationStatus.isGranted) {
      locationStatus = await Permission.locationWhenInUse.request();
    }
    
    if (!bluetoothStatus.isGranted) {
      bluetoothStatus = await Permission.bluetooth.request();
    }

    if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
      if (mounted) { 
        showBluetoothSettingsDialog();
      }
    }
  }

  void showBluetoothSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            height: 220,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.bluetooth_disabled, color: Colors.blue, size: 40),
                const SizedBox(height: 15),
                const Text(
                  'Bluetooth Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please enable Bluetooth in your device settings to connect to a printer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        openAppSettings();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Settings'),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualConnectionDialog() {
    final TextEditingController ipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manual Connection'),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(
              hintText: "Enter IP Address or DNS Name",
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String address = ipController.text.trim();
                if (address.isEmpty) return;

                Navigator.pop(context);

                //Show a loading indicator here

                final bool isConnected = await ZebraService.connectToPrinter(address);

                if (mounted) { 
                  if (isConnected) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConnectedPrinter(printerName: address),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to connect to $address'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  void _discoverAndShowPrinters() async {
    setState(() {
      _isDiscovering = true;
      _printerNames = [];
    });

    final foundPrinters = await ZebraService.discoverPrinters();

    setState(() {
      _printerNames = foundPrinters;
      _isDiscovering = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F5F8),
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      drawer: const UnconnectedMenu(), 
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 150.0,
                width: 150.0,
                margin: EdgeInsets.only(top: 15.0, bottom: 20.0),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/Alertcircle.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(25.0),
                  color: Color(0xFFF5F5F8)
                ),
              ),
                Container(
                height: 50.0,
                width: 150.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white
                ),
                child: FittedBox(
                  fit: BoxFit.none,
                  child: Text(
                    'Not Connected',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                )
              ),
              Container(
                margin: const EdgeInsets.all(24.0),
                child: InkWell(
                  onTap: _showManualConnectionDialog, 
                  borderRadius: BorderRadius.circular(25.0), 
                  child: Container(
                    height: 50.0,
                    width: 290.0,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25.0),
                      color: Colors.white
                    ),
                    child: Row( 
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Manual Connection',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        Icon( 
                          Icons.arrow_forward_ios,
                          color: Colors.black,
                          size: 18.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 24.0),
                width: 290.0,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      InkWell(
                        borderRadius: _isDiscoveredPrintersExpanded
                            ? const BorderRadius.vertical(top: Radius.circular(25.0))
                            : BorderRadius.circular(25.0),
                        onTap: () {
                          final isOpening = !_isDiscoveredPrintersExpanded;
                          setState(() {
                            _isDiscoveredPrintersExpanded = isOpening;
                          });

                          if (isOpening) {
                            _discoverAndShowPrinters();
                          }
                        },
                        child: Container(
                          height: 50.0,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Discovered Printers',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  if (_isDiscoveredPrintersExpanded)
                                    IconButton(
                                      icon: Icon(Icons.refresh, color: Colors.black),
                                      onPressed: _discoverAndShowPrinters,
                                    ),
                                  Icon(
                                    _isDiscoveredPrintersExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isDiscoveredPrintersExpanded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Column(
                            children: [
                              const Divider(indent: 10, endIndent: 10, color: Colors.black),
                              if (_isDiscovering)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: CircularProgressIndicator(),
                                )
                              else if (_printerNames.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Text(
                                    'No printers found.',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                )
                              else
                                ..._printerNames.map((name) {
                                  return _buildPrinterTile(name);
                                }).toList(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(24.0),
                height: 450.0,
                width: 290.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, 
                  children: [
                    Text(
                      'Instructions',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15), 
                    Container(
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5F8),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Center(
                        child: Text(
                          '1. Ensure the printer is on by checking that the LEDs are lit. If the printer is not on, press the power button',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 15.0),
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5F8),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Center(
                        child: Text(
                          '2. Use Limited Pairing Mode if bluetooth connection has issues. Hold the printer feed button until the LED begins flashing.',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(top: 15.0),
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5F8),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Center(
                        child: Text(
                          '3. Then tap the printer in the Discovered Printers.',
                          style: TextStyle(color: Colors.black),
                        ),
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

  Widget _buildPrinterTile(String printerName) {
    return ListTile(
      leading: Icon(Icons.print, color: Colors.grey[600]),
      title: Text(
        printerName,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        print('Tapped on $printerName');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectedPrinter(printerName: printerName),
          ),
        );
      },
    );
  }
}





*/