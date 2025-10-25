import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// --- Zebra BLE UUIDs ---
const String ZEBRA_SERVICE_UUID = "38EB4A80-C570-11E3-9507-0002A5D5C51B";
const String ZEBRA_WRITE_CHAR_UUID = "38EB4A82-C570-11E3-9507-0002A5D5C51B";
const String ZEBRA_READ_CHAR_UUID = "38EB4A81-C570-11E3-9507-0002A5D5C51B";

class ZebraBlePrinter {
  final BluetoothDevice device;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<List<int>>? _readSubscription;

  int _chunksToBeSent = 0;
  int _chunksSent = 0;
  Completer<void>? _writeCompleter;

  ZebraBlePrinter(this.device);

  Future<bool> connectAndDiscover() async {
    _writeCharacteristic = null;

    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15)
        );
      print("Connected to ${device.platformName}");

      try {
        final mtu = await device.requestMtu(512);
        print("MTU negotiated: $mtu");
      } catch (e) {
        print("MTU negotiation failed, using default: $e");
      }

      List<BluetoothService> services = await device.discoverServices();
      print("Discovering services...");

      for (BluetoothService service in services) {
        if (service.serviceUuid.toString().toUpperCase() == ZEBRA_SERVICE_UUID.toUpperCase()) {
          print("Found Zebra Service: ${service.serviceUuid}");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String charUuid = characteristic.characteristicUuid.toString().toUpperCase();
            if (charUuid == ZEBRA_WRITE_CHAR_UUID.toUpperCase()) {
              print("Found Write Characteristic: $charUuid");
              _writeCharacteristic = characteristic;
            } else if (charUuid == ZEBRA_READ_CHAR_UUID.toUpperCase()) {
              print("Found Read Characteristic: $charUuid");
              await setupReadNotifications(characteristic);
            }
          }
        }
      }

      if (_writeCharacteristic != null) {
        print("Ready to send commands.");
        return true;
      } else {
        print("Error: Zebra write characteristic not found.");
        await disconnect();
        return false;
      }
    } catch (e) {
      print("Error during connection/discovery: $e");
      await disconnect();
      return false;
    }
  }

  Future<void> sendCommand(String command) async {
    if (_writeCharacteristic == null) {
      print("Error: Not connected or write characteristic not found.");
      throw Exception("Printer not ready");
    }
    if (_writeCompleter != null && !_writeCompleter!.isCompleted) {
      print("Error: Previous write operation still in progress.");
      throw Exception("Write in progress");
    }

    print("Sending command: $command");
    List<int> data = utf8.encode(command);
    await _writeDataInChunks(data, _writeCharacteristic!);
    await _writeCompleter?.future;
  }

  Future<void> _writeDataInChunks(List<int> data, BluetoothCharacteristic characteristic) async {
    _writeCompleter = Completer<void>();
    
    int mtuValue = device.mtuNow;
    int chunkSize = min(max(mtuValue - 3, 20), 512);
    
    if (chunkSize < 20) chunkSize = 80;

    _chunksSent = 0;
    _chunksToBeSent = (data.length / chunkSize).ceil();
    print("Data length: ${data.length}, Chunk size: $chunkSize (MTU: $mtuValue), Chunks: $_chunksToBeSent");

    for (int i = 0; i < data.length; i += chunkSize) {
      int end = min(i + chunkSize, data.length);
      List<int> chunk = data.sublist(i, end);

      try {
        await characteristic.write(chunk, withoutResponse: false);
        _chunksSent++;
        print("Sent chunk $_chunksSent/$_chunksToBeSent");
      } catch (e) {
        print("Error sending chunk $_chunksSent: $e");
        if (!_writeCompleter!.isCompleted) _writeCompleter!.completeError(e);
        rethrow;
      }
    }

    print("All chunks sent successfully.");
    if (!_writeCompleter!.isCompleted) _writeCompleter!.complete();
  }

  Future<void> setupReadNotifications(BluetoothCharacteristic characteristic) async {
    if (characteristic.properties.notify || characteristic.properties.indicate) {
      try {
        await characteristic.setNotifyValue(true);
        _readSubscription = characteristic.onValueReceived.listen((value) {
          String receivedData = utf8.decode(value, allowMalformed: true);
          print("Received Data: $receivedData");
        }, onError: (error) {
          print("Error receiving data: $error");
        });
        print("Subscribed to read characteristic.");
      } catch (e) {
        print("Error setting up notifications: $e");
      }
    }
  }

  Future<void> disconnect() async {
    await _readSubscription?.cancel();
    _readSubscription = null;
    try {
      await device.disconnect();
      print("Disconnected from ${device.platformName}");
    } catch (e) {
      print("Error disconnecting: $e");
    }
    _writeCharacteristic = null;
    if (_writeCompleter != null && !_writeCompleter!.isCompleted) {
      _writeCompleter!.completeError("Disconnected during write");
    }
  }
}