import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Initial window size centered on the active screen.
    let initialSize = NSSize(width: 1100, height: 800)
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let origin = NSPoint(
      x: screenFrame.midX - initialSize.width / 2,
      y: screenFrame.midY - initialSize.height / 2
    )
    self.setFrame(NSRect(origin: origin, size: initialSize), display: true)

    // Prevent the user from shrinking it below something usable.
    self.contentMinSize = NSSize(width: 560, height: 640)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
