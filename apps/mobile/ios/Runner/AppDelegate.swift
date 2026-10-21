import Flutter
import UIKit
import ReplayKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let screenShareChannel = FlutterMethodChannel(
      name: "com.xlive.app/screenshare",
      binaryMessenger: controller.binaryMessenger
    )

    screenShareChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "showBroadcastPicker" {
        if #available(iOS 12.0, *) {
          DispatchQueue.main.async {
            let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            picker.showsMicrophoneButton = false
            if let url = Bundle.main.url(forResource: nil, withExtension: "appex", subdirectory: "PlugIns"),
               let bundle = Bundle(url: url) {
              picker.preferredExtension = bundle.bundleIdentifier
            }
            for view in picker.subviews {
              if let button = view as? UIButton {
                button.sendActions(for: .allTouchEvents)
                break
              }
            }
            result(true)
          }
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "iOS 12.0+ required", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
