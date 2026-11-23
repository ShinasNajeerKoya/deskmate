import Foundation
import ServiceManagement

/// "Open at Login" through macOS's standard login items (System Settings → General → Login Items).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Deskmate Hub: login item change failed: \(error.localizedDescription)")
        }
    }

    /// Turn it on once, the first time the app runs from an Applications folder
    /// (not from a build or Downloads folder, which would leave a broken login item).
    static func enableOnFirstLaunch() {
        let key = "loginItemSetUp"
        let path = Bundle.main.bundleURL.path
        let installed = path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
        guard Bundle.main.bundleURL.pathExtension == "app", installed,
              !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(true)
    }
}
