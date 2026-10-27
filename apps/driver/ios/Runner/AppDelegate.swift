import Flutter
import GoogleMaps
import UIKit
import flutter_foreground_task

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps key from the GOOGLE_MAPS_IOS_KEY build setting (Info.plist GMSApiKey).
    // Empty key → the Dart side runs with MAPS_ENABLED=false (placeholder map).
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    // Plugins for the flutter_foreground_task background engine.
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
