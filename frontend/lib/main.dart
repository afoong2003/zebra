import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;


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
  
  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F5F8),
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey,
            height: 1.0,
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
      child: ListView(
        children: [
          Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
              ),
            ),
          ),
        Divider(thickness: 1, color: Colors.black, indent: 16.0, endIndent: 16.0,),
        ListTile(
          leading: Icon(Icons.print),
          title: Text('Printer Database'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder:  (context) => PrinterDatabasePage())
            );
          },
        ),
        Divider(thickness: 1, color: Colors.black, indent: 16.0, endIndent: 16.0,),
        ListTile(
          leading: Icon(Icons.help_outline),
          title: Text('Zebra Assist'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder:  (context) => ZebraAssistPage())
            );
          },
        ),
        Divider(thickness: 1, color: Colors.black, indent: 16.0, endIndent: 16.0,),
        ListTile(
          leading: Icon(Icons.settings),
          title: Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder:  (context) => SettingsPage())
            );
          },
        ),
        Divider(thickness: 1, color: Colors.black, indent: 16.0, endIndent: 16.0,),
      ],
    ),
  ),
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 70.0,
                width: 200.0,
                margin: EdgeInsets.all(40.0),
                padding: EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                  'Name Placeholder',
                  style: TextStyle(
                    color: Colors.black
                    ),
                  ),
              ),
              ),
                Container(
                height: 200.0,
                width: 200.0,
                padding: EdgeInsets.all(40.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white
                ),
                child: Text(
                  'Image placeholder',
                  style: TextStyle(
                    color: Colors.black
                    ),
                  ),
              ),
            ],
          ),
            ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Text('Settings Page'),
      ),
    );
  }
}

class PrinterDatabasePage extends StatelessWidget {
  const PrinterDatabasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Database'),
        backgroundColor: Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Text('Printer Database Page'),
      ),
    );
  }
}

class ZebraAssistPage extends StatelessWidget {
  const ZebraAssistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zebra Assist'),
        backgroundColor: Color(0xFFF5F5F8),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Text('Zebra Assist Page'),
      ),
    );
  }
}