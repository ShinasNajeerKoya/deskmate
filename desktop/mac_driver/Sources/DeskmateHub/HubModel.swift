import Foundation

/// What the menu shows. Updated on the main thread by HubController.
final class HubModel: ObservableObject {
    enum Bluetooth { case starting, on, off, unauthorized, unsupported }

    @Published var bluetooth: Bluetooth = .starting
    @Published var connected = false
    @Published var phoneName: String?
    @Published var openAtLogin = LoginItem.isEnabled

    var statusLine: String {
        switch bluetooth {
        case .starting: return "Starting…"
        case .off: return "Bluetooth is off"
        case .unauthorized: return "Bluetooth not allowed (System Settings → Privacy & Security → Bluetooth)"
        case .unsupported: return "This Mac can't share data over Bluetooth LE"
        case .on:
            if connected { return "Connected to \(phoneName ?? "your phone")" }
            return "Waiting for your phone…"
        }
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    func setOpenAtLogin(_ on: Bool) {
        LoginItem.set(on)
        openAtLogin = LoginItem.isEnabled
    }
}
