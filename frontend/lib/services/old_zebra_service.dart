import 'package:flutter/services.dart';

class ZebraService {
  static const MethodChannel _channel = MethodChannel('com.ipro.zebra/printer');

  static Future<List<String>> discoverPrinters() async {
    try {
      final List<dynamic>? printers = await _channel.invokeMethod('discoverPrinters');
      return printers?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      print("Failed to discover printers: '${e.message}'.");
      return [];
    }
  }

  static Future<bool> connectToPrinter(String address) async {
    try {
      final bool? isConnected = await _channel.invokeMethod('connectToPrinter', {'address': address});
      return isConnected ?? false;
    } on PlatformException catch (e) {
      print("Failed to connect: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> printTestPage(String address) async {
    try {
      final bool? success = await _channel.invokeMethod('printTestPage', {'address': address});
      return success ?? false;
    } on PlatformException catch (e) {
      print("Service: Failed to print test page: '${e.message}'.");
      return false;
    }
  }
}