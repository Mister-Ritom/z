import Cocoa
import FlutterMacOS
import FirebaseCore
import FirebaseMessaging

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  // FCM setup (currently disabled via iosNotificationAvailable flag in Dart)
  // When enabled, this will handle push notifications
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // FCM will be initialized by Flutter plugin when flag is enabled
  }
}
