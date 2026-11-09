import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    migrateMushafData()
    // The Friday reminder (flutter_local_notifications): shown even while the app is open, and a tap reaches it.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Mushaf 1.7 and earlier on iPhone (the SwiftUI app this one replaced) kept the last page, language, reciter and
  /// bookmarked pages in UserDefaults. Carry them over once, into the places the Flutter app reads them: its
  /// shared preferences ("flutter." keys) and library.json in Application Support. As MainActivity.kt does on Android.
  private func migrateMushafData() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: "migratedToFlutter") else { return }
    defer { defaults.set(true, forKey: "migratedToFlutter") }

    let lastPage = defaults.integer(forKey: "lastPage")
    if lastPage > 0, defaults.object(forKey: "flutter.lastPage") == nil {
      defaults.set(lastPage, forKey: "flutter.lastPage")
    }
    if let lang = defaults.string(forKey: "lang"), ["ar", "en", "fr"].contains(lang),
       defaults.object(forKey: "flutter.language") == nil {
      defaults.set(lang, forKey: "flutter.language")
    }
    if let reciter = defaults.string(forKey: "reciter"), defaults.object(forKey: "flutter.reciter") == nil {
      defaults.set(reciter, forKey: "flutter.reciter")
    }

    let pages = (defaults.array(forKey: "bookmarks") as? [Int]) ?? []
    guard !pages.isEmpty,
          let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    let library = dir.appendingPathComponent("library.json")
    guard !FileManager.default.fileExists(atPath: library.path) else { return }
    let json = "{\"bookmarks\":[" + pages.map { "{\"page\":\($0)}" }.joined(separator: ",") + "],\"notes\":{}}"
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try? json.write(to: library, atomically: true, encoding: .utf8)
  }
}
