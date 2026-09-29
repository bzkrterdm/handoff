import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Modern macOS chrome: the Flutter sidebar runs up under the traffic
    // lights, like Notes or Finder. The Dart side pads its sidebar for them.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    self.minSize = NSSize(width: 980, height: 620)
    if windowFrame.width < 1180 {
      self.setContentSize(NSSize(width: 1180, height: 760))
      self.center()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    DockBadgeChannel.register(with: flutterViewController)

    super.awakeFromNib()
  }
}
