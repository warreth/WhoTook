import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenshotChannel: FlutterEventChannel?
  private var screenshotStreamHandler: ScreenshotStreamHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let handler = ScreenshotStreamHandler()
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterEventChannel(
      name: "app.whotook/screenshots",
      binaryMessenger: messenger
    )
    channel.setStreamHandler(handler)
    FlutterMethodChannel(
      name: "app.whotook/screenshots",
      binaryMessenger: messenger
    ).setMethodCallHandler { call, result in
      if call.method == "isSupported" {
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    screenshotStreamHandler = handler
    screenshotChannel = channel
  }
}

/// Bridges `UIApplication.userDidTakeScreenshotNotification` to an event stream.
/// The observer only exists between `onListen` and `onCancel`.
private final class ScreenshotStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    guard observer == nil else { return nil }
    observer = NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.eventSink?(Int(Date().timeIntervalSince1970 * 1000))
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    eventSink = nil
    return nil
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}
