import Foundation

/// What the menu shows. Updated on the main thread by HubController.
final class HubModel: ObservableObject {
    enum Bluetooth { case starting, on, off, unauthorized, unsupported }

    @Published var bluetooth: Bluetooth = .starting
    @Published var connected = false
    @Published var phoneName: String?
    var blePhoneName: String?
    @Published var overWifi = false
    /// Wi-Fi pairing code while pairing is open (2 minutes), and this Mac's IP for manual entry.
    @Published var pairingCode: String?
    @Published var localAddress: String?
    @Published var wifiPaired = false
    @Published var openAtLogin = LoginItem.isEnabled
    @Published var claudeSetup: ClaudeCollector.Setup = .notConnected
    @Published var claudeMessage: String?
    /// Permissions or settings still needed for some data (shown as hints in the menu).
    @Published var problems: [String] = []

    var statusLine: String {
        switch bluetooth {
        case .starting: return "Starting…"
        case .off: return "Bluetooth is off"
        case .unauthorized: return "Bluetooth not allowed (System Settings → Privacy & Security → Bluetooth)"
        case .unsupported: return "This Mac can't share data over Bluetooth LE"
        case .on:
            if connected { return "Connected to \(phoneName ?? "your phone")" + (overWifi ? " over Wi-Fi" : " over Bluetooth") }
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
