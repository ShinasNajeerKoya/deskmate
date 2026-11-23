import CoreLocation
import CoreWLAN
import Foundation

/// The Mac's Wi-Fi for Control Center: on/off and the network name.
/// macOS only reveals the network name to apps with Location permission,
/// so the first run asks for it; without it the phone just shows "On".
final class WiFiCollector: NSObject, CLLocationManagerDelegate {
    var onChange: (() -> Void)?
    private let location = CLLocationManager()
    private var last: [String: AnyHashable] = [:]

    override init() {
        super.init()
        location.delegate = self
        if location.authorizationStatus == .notDetermined { location.requestAlwaysAuthorization() }
    }

    func message() -> [String: Any] {
        let iface = CWWiFiClient.shared().interface()
        let on = iface?.powerOn() ?? false
        var m: [String: Any] = ["t": "wifi", "on": on]
        if on, let ssid = iface?.ssid(), !ssid.isEmpty { m["ssid"] = String(ssid.prefix(32)) }
        return m
    }

    /// True when the state differs from the last call (so it's only sent on change).
    func changed() -> Bool {
        let m = message()
        let now: [String: AnyHashable] = ["on": m["on"] as? Bool ?? false, "ssid": m["ssid"] as? String ?? ""]
        defer { last = now }
        return now != last
    }

    /// Handles wifi.power:on / wifi.power:off.
    func handle(_ command: String) {
        guard command.hasPrefix("wifi.power:"), let iface = CWWiFiClient.shared().interface() else { return }
        try? iface.setPower(command.hasSuffix(":on"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.onChange?() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onChange?()  // the network name may now be visible
    }
}
