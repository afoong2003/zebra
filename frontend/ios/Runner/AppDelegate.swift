import UIKit
import Flutter

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
        let mockPrinters = ["Mock Printer 1 (iOS)", "Mock Printer 2 (iOS)"]
        result(mockPrinters)

      } else if call.method == "connectToPrinter" {
        guard let args = call.arguments as? [String: Any],
              let address = args["address"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Address not provided", details: nil))
          return
        }

        print("Swift: Received request to connect to \(address)")

        // TODO: zebra SDK connection logic.
        let isSuccess = !address.isEmpty
        
        result(isSuccess)

      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
