import Foundation
import IOBluetooth

/// The Mac's Bluetooth devices for Control Center: paired devices with their
/// connection state, plus nearby unpaired devices found by a short scan.
/// Never turns the Mac's Bluetooth off (that would cut the phone's own link).
final class BluetoothCollector: NSObject, IOBluetoothDeviceInquiryDelegate {
    /// Called on the main thread whenever the list may have changed.
    var onChange: (() -> Void)?

    private var inquiry: IOBluetoothDeviceInquiry?
    private var nearby: [String: IOBluetoothDevice] = [:]
    private var pairing: IOBluetoothDevicePair?
    private(set) var scanning = false

    /// Scanning makes Bluetooth audio stutter, so it only runs briefly, when the
    /// phone asks (Control Center open), never continuously.
    func scan(seconds: Int = 10) {
        guard !scanning else { return }
        nearby.removeAll()
        let inquiry = IOBluetoothDeviceInquiry(delegate: self)
        inquiry?.inquiryLength = UInt8(clamping: seconds)
        inquiry?.updateNewDeviceNames = true
        self.inquiry = inquiry
        if inquiry?.start() == kIOReturnSuccess {
            scanning = true
            onChange?()
        }
    }

    func message() -> [String: Any] {
        var devices: [[String: Any]] = []
        for device in (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []) {
            guard let entry = describe(device, paired: true) else { continue }
            devices.append(entry)
        }
        for device in nearby.values where !device.isPaired() {
            guard let entry = describe(device, paired: false) else { continue }
            devices.append(entry)
        }
        // Connected first, then paired, then nearby; keep the message small.
        devices.sort {
            let a = ($0["connected"] as? Bool ?? false ? 0 : 1, $0["paired"] as? Bool ?? false ? 0 : 1)
            let b = ($1["connected"] as? Bool ?? false ? 0 : 1, $1["paired"] as? Bool ?? false ? 0 : 1)
            return a < b
        }
        return ["t": "bluetooth", "scanning": scanning, "devices": Array(devices.prefix(12))]
    }

    /// Handles bt.connect:<id>, bt.disconnect:<id>, bt.pair:<id>, bt.scan.
    func handle(_ command: String) {
        let parts = command.split(separator: ":", maxSplits: 1).map(String.init)
        let action = parts[0]
        if action == "bt.scan" { scan(); return }
        guard parts.count == 2, let device = find(parts[1]) else { return }
        switch action {
        case "bt.connect":
            DispatchQueue.global().async {
                _ = device.openConnection()
                DispatchQueue.main.async { self.onChange?() }
            }
        case "bt.disconnect":
            _ = device.closeConnection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.onChange?() }
        case "bt.pair":
            let pair = IOBluetoothDevicePair(device: device)
            pair?.delegate = self
            pairing = pair
            _ = pair?.start()
        default:
            break
        }
    }

    // MARK: Helpers

    private func find(_ id: String) -> IOBluetoothDevice? {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return paired.first { shortID($0) == id } ?? nearby[id]
    }

    private func describe(_ device: IOBluetoothDevice, paired: Bool) -> [String: Any]? {
        guard let name = device.name ?? device.nameOrAddress, !name.isEmpty else { return nil }
        return [
            "id": shortID(device),
            "name": String(name.prefix(28)),
            "kind": kind(device),
            "connected": device.isConnected(),
            "paired": paired,
        ]
    }

    /// Bluetooth address without separators, e.g. "a1b2c3d4e5f6".
    private func shortID(_ device: IOBluetoothDevice) -> String {
        (device.addressString ?? "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").lowercased()
    }

    /// Maps the Bluetooth device class to the phone's device kinds.
    private func kind(_ device: IOBluetoothDevice) -> String {
        let major = device.deviceClassMajor
        let minor = device.deviceClassMinor
        switch major {
        case UInt32(kBluetoothDeviceClassMajorAudio):
            // Minor 0x05 = loudspeaker; everything else (headset, headphones…) shows as headphones.
            return minor == 0x05 ? "speaker" : "headphones"
        case UInt32(kBluetoothDeviceClassMajorPeripheral):
            // Peripheral minor: bit 4 = keyboard, bit 5 = pointing device.
            if minor & 0x20 != 0 { return "mouse" }
            if minor & 0x10 != 0 { return "keyboard" }
            return "other"
        default:
            return "other"
        }
    }

    // MARK: IOBluetoothDeviceInquiryDelegate

    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        guard let device, !device.isPaired() else { return }
        nearby[shortID(device)] = device
        onChange?()
    }

    func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32) {
        onChange?()
    }

    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        scanning = false
        onChange?()
    }

    // MARK: Pairing (IOBluetoothDevicePairDelegate, informal protocol)

    @objc func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        pairing = nil
        if error == kIOReturnSuccess, let pair = sender as? IOBluetoothDevicePair, let device = pair.device() {
            DispatchQueue.global().async { _ = device.openConnection() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.onChange?() }
    }
}
