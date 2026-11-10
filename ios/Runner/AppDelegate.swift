import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let headingHandler = HeadingStreamHandler()
  private let exampleExporter = ExampleExporter()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(name: "org.fieldkit/export",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "example",
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String, text.utf8.count <= 100000 else {
          result(FlutterError(code: "invalid_export", message: "Invalid example", details: nil))
          return
        }
        self?.exampleExporter.export(text, result: result)
      }
    let channel = FlutterMethodChannel(
      name: "org.fieldkit/storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    FlutterEventChannel(
      name: "org.fieldkit/compass",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setStreamHandler(headingHandler)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "invalid_path", message: "Storage path required", details: nil))
        return
      }
      do {
        var url = URL(fileURLWithPath: path)
        if call.method == "availableBytes" {
          let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
          result(values.volumeAvailableCapacityForImportantUsage)
        } else if call.method == "excludeFromBackup" {
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "storage_error", message: error.localizedDescription, details: nil))
      }
    }
  }
}

final class ExampleExporter: NSObject, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var temporary: URL?
  func export(_ text: String, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "An export is already open", details: nil)); return
    }
    guard var controller = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })?.rootViewController else {
      result(FlutterError(code: "no_window", message: "Cannot open export picker", details: nil)); return
    }
    while let presented = controller.presentedViewController { controller = presented }
    do {
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let file = folder.appendingPathComponent("supplies.py")
      try text.write(to: file, atomically: true, encoding: .utf8)
      temporary = folder
      pending = result
      let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
      picker.delegate = self
      controller.present(picker, animated: true)
    } catch {
      result(FlutterError(code: "export_failed", message: error.localizedDescription, details: nil))
    }
  }
  private func finish(_ saved: Bool) {
    pending?(saved)
    pending = nil
    if let folder = temporary { try? FileManager.default.removeItem(at: folder) }
    temporary = nil
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(false) }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finish(true) }
}

final class HeadingStreamHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    manager.delegate = self
    manager.headingFilter = 2
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(self, selector: #selector(updateOrientation),
      name: UIDevice.orientationDidChangeNotification, object: nil)
    updateOrientation()
    if CLLocationManager.headingAvailable() {
      manager.startUpdatingHeading()
    } else {
      events(["heading": NSNull(), "accuracy": NSNull()])
    }
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    NotificationCenter.default.removeObserver(self,
      name: UIDevice.orientationDidChangeNotification, object: nil)
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    sink = nil
    return nil
  }
  @objc private func updateOrientation() {
    // Use screen orientation rather than gravity: flat phones have no useful
    // UIDevice orientation. Interface and physical landscape names are opposite.
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })
      else { return }
    switch scene.interfaceOrientation {
    case .portrait: manager.headingOrientation = .portrait
    case .portraitUpsideDown: manager.headingOrientation = .portraitUpsideDown
    case .landscapeLeft: manager.headingOrientation = .landscapeRight
    case .landscapeRight: manager.headingOrientation = .landscapeLeft
    default: break
    }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    updateOrientation()
    guard heading.headingAccuracy >= 0 else {
      sink?(["heading": NSNull(), "accuracy": NSNull(), "status": "unreliable"])
      return
    }
    sink?(["heading": heading.magneticHeading, "accuracy": heading.headingAccuracy])
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    sink?(["heading": NSNull(), "accuracy": NSNull()])
  }
}
