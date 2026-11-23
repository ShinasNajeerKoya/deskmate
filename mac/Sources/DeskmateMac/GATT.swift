import CoreBluetooth

/// Shared BLE contract. Keep in sync with lib/ble/gatt.dart on the phone.
enum GATT {
    static let service = CBUUID(string: "CC8A9226-538A-41AA-B390-85DB92127C62")
    /// Notify + read. UTF-8 JSON messages with a topic, e.g. {"t":"sys","seq":Int,"cpu":Double,"ts":Int}.
    /// Topics and fields: lib/data/models.dart on the phone.
    static let stats = CBUUID(string: "46ABD5B3-C525-463B-9E0A-5EB81163CCBB")
    static let localName = "Deskmate"
}
