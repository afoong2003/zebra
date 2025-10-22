import UIKit
import Flutter
import ExternalAccessory

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    let printerChannel = FlutterMethodChannel(name: "com.ipro.zebra/printer",
                                              binaryMessenger: controller.binaryMessenger)

    printerChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      if call.method == "discoverPrinters" {
        let accessories = EAAccessoryManager.shared().connectedAccessories
        let zebraPrinters = accessories.filter { $0.protocolStrings.contains("com.zebra.rawport") }
        var printerNames = zebraPrinters.map { $0.name }
        
        print("Swift: Discovered real printers: \(printerNames)")
        
        if printerNames.isEmpty {
            print("Swift: No real printers found. Adding mock data for UI testing.")
            printerNames.append("Mock ZD620 (Test)")
            printerNames.append("Mock ZQ521 (Test)")
        }
        
        result(printerNames)

      } else if call.method == "connectToPrinter" {
        guard let args = call.arguments as? [String: Any],
              let address = args["address"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Address not provided", details: nil))
          return
        }

        print("Swift: Received request to connect to \(address)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let connection = self.getConnection(for: address)
            var isConnected = false
            
            if connection.open() {
                isConnected = true
                connection.close()
            }
            
            DispatchQueue.main.async {
                result(isConnected)
            }
        }

      } else if call.method == "printTestPage" {
        guard let args = call.arguments as? [String: Any],
              let address = args["address"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Address not provided", details: nil))
          return
        }

        print("Swift: Received request to print test page to \(address)")

        DispatchQueue.global(qos: .userInitiated).async {
            let connection = self.getConnection(for: address)
            var success = false
            
            do {
                if connection.open() {
                    print("Swift: Connection opened successfully.")
                    
                    let printer = try ZebraPrinterFactory.getInstance(connection)
                    
                    let zplString = """
                    ^XA
                    ^FO50,50
                    ^A0N,50,50
                    ^FDHello World^FS
                    ^XZ
                    """

                    var sendError: NSError?

                    if let printerTools = try? printer.getToolsUtil(),
                       let toolsUtilObj = printerTools as? NSObject {
                        let sentObj = toolsUtilObj.perform(NSSelectorFromString("sendCommand:error:"), with: zplString, with: nil)
                        let sent = (sentObj?.takeUnretainedValue() as? Bool) ?? false
                        if sent {
                            print("Swift: ZPL data sent successfully.")
                            success = true
                        } else {
                            print("Swift: Error sending ZPL data: \(sendError?.localizedDescription ?? "Unknown error")")
                        }
                    } else {
                        print("Swift: ToolsUtil unavailable; cannot send ZPL")
                    }

                    connection.close()
                } else {
                    print("Swift: Failed to open connection.")
                }
            } catch {
                print("Swift: An exception occurred: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                result(success)
            }
        }

      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getConnection(for address: String) -> (NSObject & ZebraPrinterConnection) {
      let isIpAddress = address.split(separator: ".").count == 4
      
      if isIpAddress {
          print("Swift: Creating TCP connection for IP: \(address)")
          return TcpPrinterConnection(address: address, andWithPort: 6101)
      } else {
          print("Swift: Creating Bluetooth connection for name: \(address)")
          let serialNumber = EAAccessoryManager.shared().connectedAccessories.first(where: { $0.name == address })?.serialNumber ?? ""
          return MfiBtPrinterConnection(serialNumber: serialNumber)
      }
  }
}
