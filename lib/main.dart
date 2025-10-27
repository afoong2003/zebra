import 'package:flutter/material.dart';
import 'pages/connected_printer.dart';
import 'package:frontend/menu/unconnected_menu.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'services/zebra_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {  
  WidgetsFlutterBinding.ensureInitialized();  

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(   
    url: dotenv.env['SUPABASE_URL']!,    
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,  
  );  
  runApp(MyApp());
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
        scaffoldBackgroundColor: const Color(0xFFF5F5F8),
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
  // --- State Management ---
  final ZebraService _zebraService = ZebraService();
  bool _isDiscoveredPrintersExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndRequestBluetoothPermission();
    });
  }

  @override
  void dispose() {
    _zebraService.stopScan();
    super.dispose();
  }

  Future<void> checkAndRequestBluetoothPermission() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
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
                  style: TextStyle(color: Colors.black),
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

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Manual connection is not implemented yet.'),
                  ),
                );
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  void _startDiscovery() {
    _zebraService.startScan();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F8),
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
                margin: const EdgeInsets.only(top: 15.0, bottom: 20.0),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/Alertcircle.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
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
                child: const Center(
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
                        highlightColor: Colors.transparent,
                        splashColor: Colors.grey.withOpacity(0.2),
                        borderRadius: _isDiscoveredPrintersExpanded
                            ? const BorderRadius.vertical(top: Radius.circular(25.0))
                            : BorderRadius.circular(25.0),
                        onTap: () {
                          final isOpening = !_isDiscoveredPrintersExpanded;
                          setState(() {
                            _isDiscoveredPrintersExpanded = isOpening;
                          });

                          if (isOpening) {
                            _startDiscovery();
                          } else {
                            _zebraService.stopScan();
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
                                      onPressed: _startDiscovery,
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
                              StreamBuilder<List<ScanResult>>(
                                stream: _zebraService.scanResults,
                                initialData: const [],
                                builder: (c, snapshot) => StreamBuilder<bool>(
                                  stream: _zebraService.isScanning,
                                  initialData: false,
                                  builder: (c, isScanningSnapshot) {
                                    final isScanning = isScanningSnapshot.data ?? false;
                                    final results = snapshot.data ?? [];

                                    // DEBUG: Log scan results
                                    if (results.isNotEmpty) {
                                      print("=== SCAN RESULTS (${results.length} devices) ===");
                                      for (var r in results) {
                                        print("Device: ${r.device.platformName} (${r.device.remoteId})");
                                        print("  Manufacturer Data: ${r.advertisementData.manufacturerData}");
                                        print("  Service UUIDs: ${r.advertisementData.serviceUuids}");
                                      }
                                    }

                                    // Filter for Zebra printers by Company Identifier only
                                    final zebraResults = results.where((r) {
                                      final manufacturerData = r.advertisementData.manufacturerData;
                                      final serviceUuids = r.advertisementData.serviceUuids
                                          .map((u) => u.toString().toUpperCase())
                                          .toList();

                                      final hasZebraCompanyId = manufacturerData.containsKey(0x01F1);
                                      final hasZebraServiceUuid = serviceUuids.any((uuid) =>
                                        uuid.contains('FE79') ||
                                        uuid.contains('FD66') ||
                                        uuid.contains('38EB4A80')
                                      );

                                      return hasZebraCompanyId || hasZebraServiceUuid;
                                    }).toList();

                                    print("Zebra devices found: ${zebraResults.length}");

                                    if (isScanning && zebraResults.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: CircularProgressIndicator(),
                                      );
                                    } else if (!isScanning && zebraResults.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                                        child: Text(
                                          'No Zebra printers found.',
                                          style: TextStyle(color: Colors.black),
                                        ),
                                      );
                                    } else {
                                      return Column(
                                        children: zebraResults.map((result) {
                                          return _buildPrinterTile(result);
                                        }).toList(),
                                      );
                                    }
                                  },
                                ),
                              ),
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

  // --- Updated to use new ZebraService BLE connection and print ---
  Widget _buildPrinterTile(ScanResult result) {
    final device = result.device;
    return ListTile(
      leading: Icon(Icons.bluetooth, color: Colors.blue[600]),
      title: Text(
        device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(device.remoteId.str),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);

        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final success = await _zebraService.connectToPrinter(device);
          String? modelName;
          if (success) {
            modelName = await _zebraService.getModelName();
            await _zebraService.stopScan(); // <-- Stop scanning here!
          }
          Navigator.of(context).pop(); // Dismiss loading dialog

          if (success) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Connected successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConnectedPrinter(
                  printerName: modelName ?? (device.platformName.isNotEmpty
                      ? device.platformName
                      : 'Unknown Printer'),
                ),
              ),
            );
          } else {
            throw Exception("Connection failed");
          }
        } catch (e) {
          Navigator.of(context).pop(); // Dismiss loading dialog if error
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}





