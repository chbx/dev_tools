import Cocoa
import macos_window_utils
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let macOSWindowUtilsViewController = MacOSWindowUtilsViewController()
        let windowFrame = self.frame
        self.contentViewController = macOSWindowUtilsViewController
        self.setFrame(windowFrame, display: true)
        
        MainFlutterWindowManipulator.start(mainFlutterWindow: self)
        customView();
        
        RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)
        
        super.awakeFromNib()
    }
    
    func customView() {
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.styleMask.insert(.fullSizeContentView)

        let newToolbar = NSToolbar()
         newToolbar.allowsUserCustomization = false
        newToolbar.allowsExtensionItems = false
        if #available(macOS 15.0, *) {
            newToolbar.allowsDisplayModeCustomization = false
        }
        self.toolbar = newToolbar
        
        self.toolbarStyle = .unifiedCompact
    }
}
