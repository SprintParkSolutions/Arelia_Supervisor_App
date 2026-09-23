import Flutter
import UIKit
import AudioToolbox
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AreliaNotificationSound") {
      let pushChannel = FlutterMethodChannel(name: "arelia/push", binaryMessenger: registrar.messenger())
      pushChannel.setMethodCallHandler { call, result in
        guard call.method == "cancelRemote", let eventId = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
          let ids = notifications.filter { ($0.request.content.userInfo["id"] as? String) == eventId }.map { $0.request.identifier }
          center.removeDeliveredNotifications(withIdentifiers: ids)
          DispatchQueue.main.async { result(nil) }
        }
      }
      let channel = FlutterMethodChannel(name: "arelia/notification_sound", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "play" else {
          result(FlutterMethodNotImplemented)
          return
        }
        AudioServicesPlayAlertSound(1007)
        result(nil)
      }
    }
  }
}
