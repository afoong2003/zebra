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
  BluetoothCharacteristic? _readCharacteristic;
  StreamSubscription<List<int>>? _readSubscription;

  int _chunksToBeSent = 0;
  int _chunksSent = 0;
  Completer<void>? _writeCompleter;

  ZebraBlePrinter(this.device);

  Future<bool> connectAndDiscover() async {
    _writeCharacteristic = null;
    _readCharacteristic = null;

    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
      print("Connected to ${device.platformName}");

      try {
        final mtu = await device.requestMtu(512);
        print("MTU negotiated: $mtu");
      } catch (e) {
        print("MTU negotiation failed, using default: $e");
      }
      /*
      try {
        await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
        print("Connection priority set to HIGH");
      } catch (e) {
        print("Failed to set connection priority: $e");
      }
*/
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.serviceUuid.toString().toUpperCase() ==
            ZEBRA_SERVICE_UUID.toUpperCase()) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            String charUuid =
                characteristic.characteristicUuid.toString().toUpperCase();
            if (charUuid == ZEBRA_WRITE_CHAR_UUID.toUpperCase()) {
              _writeCharacteristic = characteristic;
            } else if (charUuid == ZEBRA_READ_CHAR_UUID.toUpperCase()) {
              _readCharacteristic = characteristic;
              await setupReadNotifications(characteristic);
            }
          }
        }
      }

      if (_writeCharacteristic != null && _readCharacteristic != null) {
        return true;
      } else {
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

  Future<void> _writeDataInChunks(
    List<int> data,
    BluetoothCharacteristic characteristic,
  ) async {
    _writeCompleter = Completer<void>();

    int mtuValue = device.mtuNow;
    int chunkSize = mtuValue - 3;

    if (chunkSize < 20) chunkSize = 20;
    if (chunkSize > 244) chunkSize = 244;

    _chunksSent = 0;
    _chunksToBeSent = (data.length / chunkSize).ceil();
    print(
      "Data length: ${data.length}, Chunk size: $chunkSize (MTU: $mtuValue), Chunks: $_chunksToBeSent",
    );

    for (int i = 0; i < data.length; i += chunkSize) {
      int end = min(i + chunkSize, data.length);
      List<int> chunk = data.sublist(i, end);

      bool chunkSent = false;
      int retryCount = 0;
      const maxRetries = 3;

      while (!chunkSent && retryCount < maxRetries) {
        try {
          await characteristic.write(chunk, withoutResponse: false);
          _chunksSent++;
          print("Sent chunk $_chunksSent/$_chunksToBeSent");
          chunkSent = true;

          // Add delay between chunks to prevent buffer overflow
          // Scale delay based on total chunks and remaining chunks
          if (_chunksSent < _chunksToBeSent) {
            int delayMs;
            if (_chunksToBeSent > 5) {
              // Large print: use longer delay
              delayMs = 80;
            } else if (_chunksToBeSent > 3) {
              // Medium print: moderate delay
              delayMs = 50;
            } else {
              // Small print: minimal delay
              delayMs = 30;
            }
            print("Waiting ${delayMs}ms before next chunk...");
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        } catch (e) {
          /*
          retryCount++;
          final isBufferError = e.toString().contains('Resources are insufficient') || 
                               e.toString().contains('apple-code: 17') ||
                               e.toString().contains('GATT_CONN_FAIL_ESTABLISH');
          
          if (isBufferError && retryCount < maxRetries) {
            // Buffer is full, wait longer and retry
            final waitTime = 150 * retryCount; // Exponential backoff: 150ms, 300ms, 450ms
            print(" Buffer full (attempt $retryCount/$maxRetries), waiting ${waitTime}ms before retry...");
            await Future.delayed(Duration(milliseconds: waitTime));
          } else {
            // Non-buffer error or max retries reached
            print(" Error sending chunk $_chunksSent (attempt $retryCount/$maxRetries): $e");
            if (!_writeCompleter!.isCompleted) _writeCompleter!.completeError(e);
            rethrow;
          }
          */
          //print("error");
        }
      }
      /*
      if (!chunkSent) {
        final error = "Failed to send chunk $_chunksSent after $maxRetries attempts";
        print("$error");
        if (!_writeCompleter!.isCompleted) _writeCompleter!.completeError(error);
        throw Exception(error);
      }
    }

*/
      print(" All chunks sent successfully.");
      if (!_writeCompleter!.isCompleted) _writeCompleter!.complete();
    }
  }

  Future<void> setupReadNotifications(
    BluetoothCharacteristic characteristic,
  ) async {
    if (characteristic.properties.notify ||
        characteristic.properties.indicate) {
      try {
        await characteristic.setNotifyValue(true);
        _readSubscription = characteristic.onValueReceived.listen(
          (value) {
            String receivedData = utf8.decode(value, allowMalformed: true);
            print("Received Data: $receivedData");
          },
          onError: (error) {
            print("Error receiving data: $error");
          },
        );
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
    _readCharacteristic = null;
    if (_writeCompleter != null && !_writeCompleter!.isCompleted) {
      _writeCompleter!.completeError("Disconnected during write");
    }
  }

  Future<String?> sendCommandAndGetResponse(
    String command, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_readCharacteristic == null) {
      throw Exception("Read characteristic not available");
    }

    final completer = Completer<String?>();
    StringBuffer buffer = StringBuffer();

    late StreamSubscription<List<int>> subscription;
    subscription = _readCharacteristic!.onValueReceived.listen((value) {
      final data = utf8.decode(value, allowMalformed: true);
      buffer.write(data);
      if (data.endsWith('\r\n') || data.endsWith('\n')) {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
          subscription.cancel();
        }
      }
    });

    try {
      await sendCommand(command);

      String? response;
      try {
        response = await completer.future.timeout(
          timeout,
          onTimeout: () {
            return buffer.isEmpty ? null : buffer.toString();
          },
        );
      } catch (_) {
        response = null;
      }
      return response;
    } finally {
      await subscription.cancel();
    }
  }
}
