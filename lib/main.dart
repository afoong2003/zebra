import 'package:flutter/material.dart';
import 'pages/printer_dashboard.dart';
import '/menu/unconnected_menu.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'services/zebra_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/printer_settings_helper.dart';

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
  bool _isConnecting = false;
  late final AppLifecycleListener _appLifecycleListener;

  @override
  void initState() {
    super.initState();

    _initializeBluetoothAndPermissions();

    //Disconnect when closing app
    _appLifecycleListener = AppLifecycleListener(
      onDetach: () async {
        if (_zebraService.isConnected) {
          await _zebraService.disconnect();
        }
      },
    );
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();

    super.dispose();
  }

  Future<void> _initializeBluetoothAndPermissions() async {
    await Permission.locationWhenInUse.request();

    try {
      final adapterState = await FlutterBluePlus.adapterState.first;

      if (adapterState != BluetoothAdapterState.unavailable) {
        await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
      }
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }

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
      onTap: _isConnecting ? null : () => _handlePrinterConnection(device),
    );
  }

  //prevent race conditions
  Future<void> _handlePrinterConnection(BluetoothDevice device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    await _zebraService.stopScan();

    if (!mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.black),
                SizedBox(height: 16),
                Text('Connecting to printer...'),
                SizedBox(height: 8),
                Text(
                  'This may take a few seconds',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ],
            ),
          ),
    );

    try {
      final success = await _zebraService.connectToPrinter(device);

      if (!success) {
        throw Exception("Connection failed");
      }

      if (!_zebraService.isConnected) {
        throw Exception("Connection lost");
      }

      final modelName = await _zebraService.getModelName();

      final settingsHelper = PrinterSettingsHelper();
      await settingsHelper.fetchAllSettings();
      await settingsHelper.detectSupportedPrintMethods();

      SystemStatus? systemStatus;
      try {
        systemStatus = await _zebraService.getSystemStatus();
        print(
          'System Status - Errors: ${systemStatus.hasErrors}, Warnings: ${systemStatus.hasWarnings}',
        );
      } catch (e) {
        print('Warning: Could not fetch system status: $e');
      }

      if (!mounted) return;

      navigator.pop();
      /*
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            systemStatus?.hasIssues == true
                ? 'Connected with ${systemStatus?.hasErrors == true ? "errors" : "warnings"}'
                : 'Connected and ready!',
          ),
          backgroundColor:
              systemStatus?.hasErrors == true ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      */

      navigator.push(
        MaterialPageRoute(
          builder:
              (context) => PrinterDashboard(
                printerName:
                    modelName ??
                    (device.platformName.isNotEmpty
                        ? device.platformName
                        : 'Unknown Printer'),
                systemStatus: systemStatus,
              ),
        ),
      );
    } catch (e) {
      print('Error during connection: $e');

      if (!mounted) return;

      navigator.pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
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
        scrolledUnderElevation: 0.0,
        backgroundColor: const Color(0xFFF5F5F8),
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(color: Colors.black, height: 1.0),
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
                  color: Color(0xFFF5F5F8),
                ),
              ),
              Container(
                height: 50.0,
                width: 150.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white,
                ),
                child: const Center(
                  child: Text(
                    'Not Connected',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Manual Connection',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
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
                        splashColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        borderRadius:
                            _isDiscoveredPrintersExpanded
                                ? const BorderRadius.vertical(
                                  top: Radius.circular(25.0),
                                )
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
                                'Discover Printers',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  if (_isDiscoveredPrintersExpanded)
                                    IconButton(
                                      icon: Icon(
                                        Icons.refresh,
                                        color: Colors.black,
                                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Column(
                            children: [
                              const Divider(
                                indent: 10,
                                endIndent: 10,
                                color: Colors.black,
                              ),
                              StreamBuilder<List<ScanResult>>(
                                stream: _zebraService.scanResults,
                                initialData: const [],
                                builder:
                                    (c, snapshot) => StreamBuilder<bool>(
                                      stream: _zebraService.isScanning,
                                      initialData: false,
                                      builder: (c, isScanningSnapshot) {
                                        final isScanning =
                                            isScanningSnapshot.data ?? false;
                                        final results = snapshot.data ?? [];
                                        /*
                                        // DEBUG: Log scan results
                                        if (results.isNotEmpty) {
                                          print(
                                            "=== SCAN RESULTS (${results.length} devices) ===",
                                          );
                                          for (var r in results) {
                                            print(
                                              "Device: ${r.device.platformName} (${r.device.remoteId})",
                                            );
                                            print(
                                              "  Manufacturer Data: ${r.advertisementData.manufacturerData}",
                                            );
                                            print(
                                              "  Service UUIDs: ${r.advertisementData.serviceUuids}",
                                            );
                                          }
                                        }
                                        */

                                        // Filter for Zebra printers by Service UUID
                                        final zebraResults =
                                            results.where((r) {
                                              //final manufacturerData = r.advertisementData.manufacturerData;
                                              final serviceUuids =
                                                  r
                                                      .advertisementData
                                                      .serviceUuids
                                                      .map(
                                                        (u) =>
                                                            u
                                                                .toString()
                                                                .toUpperCase(),
                                                      )
                                                      .toList();

                                              final hasZebraServiceUuid =
                                                  serviceUuids.any(
                                                    (uuid) =>
                                                        uuid.contains('FE79'),
                                                  );

                                              return hasZebraServiceUuid;
                                            }).toList();
                                        /*
                                        print(
                                          "Zebra devices found: ${zebraResults.length}",
                                        );
                                        */

                                        if (isScanning &&
                                            zebraResults.isEmpty) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 16.0,
                                            ),
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                            ),
                                          );
                                        } else if (!isScanning &&
                                            zebraResults.isEmpty) {
                                          return Column(
                                            children: [
                                              //placeholder printer
                                              ListTile(
                                                leading: Icon(
                                                  Icons.bluetooth,
                                                  color: Colors.blue[600],
                                                ),
                                                title: const Text(
                                                  'ZD421',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (context) =>
                                                              PrinterDashboard(
                                                                printerName:
                                                                    'ZD421',
                                                              ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              //placeholder printer
                                            ],
                                          );
                                        } else {
                                          return Column(
                                            children:
                                                zebraResults.map((result) {
                                                  return _buildPrinterTile(
                                                    result,
                                                  );
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

                    // Instruction 1
                    Container(
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F8),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(10.0),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      '1. Ensure the printer is on by checking that the LEDs are lit. If the printer is not on, press the power button.',
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Image.asset(
                                      'assets/images/image 8.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Instruction 2
                    Container(
                      margin: const EdgeInsets.only(top: 15.0),
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F8),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(10.0),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      '2. Use Limited Pairing Mode if bluetooth connection has issues. Hold the printer feed button ',
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    width: 27,
                                    height: 27,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Image.asset(
                                      'assets/images/image 3.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const TextSpan(
                                  text: ' until the LED begins flashing.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Instruction 3
                    Container(
                      margin: const EdgeInsets.only(top: 15.0),
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F8),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(10.0),
                          child: const Text(
                            '3. Then tap the printer in the Discover Printer and select a printer.',
                            style: TextStyle(color: Colors.black),
                          ),
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
}
