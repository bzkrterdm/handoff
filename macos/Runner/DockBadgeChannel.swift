import Cocoa
import FlutterMacOS

/// `handoff/dock` method channel: `setBadge(String?)` writes the Dock tile
/// badge. Kept in the app rather than a plugin — it is one AppKit line.
enum DockBadgeChannel {
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "handoff/dock", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setBadge":
        let label = call.arguments as? String
        NSApp.dockTile.badgeLabel = (label?.isEmpty ?? true) ? nil : label
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
