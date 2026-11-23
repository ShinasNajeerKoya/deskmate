import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Lets the app start its demo mode on the iOS Simulator (see lib/app/device_info.dart).
    // Registered like a plugin, so it doesn't depend on the root view controller being ready.
    if let registrar = self.registrar(forPlugin: "DeskmateDevice") {
      FlutterMethodChannel(name: "deskmate/device", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          switch call.method {
          case "isEmulator":
            #if targetEnvironment(simulator)
              result(true)
            #else
              result(false)
            #endif
          default:
            result(FlutterMethodNotImplemented)
          }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
