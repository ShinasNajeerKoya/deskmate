import Foundation

/// What the menu shows. Updated on the main thread by HubController.
final class HubModel: ObservableObject {
    @Published var connected = false
    @Published var phoneName: String?
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
        if connected { return "Connected to \(phoneName ?? "your phone") over Wi-Fi" }
        return wifiPaired ? "Waiting for your phone on Wi-Fi…" : "No phone paired yet"
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    func setOpenAtLogin(_ on: Bool) {
        LoginItem.set(on)
        openAtLogin = LoginItem.isEnabled
    }
}
