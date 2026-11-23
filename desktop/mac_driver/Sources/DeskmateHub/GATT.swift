import CoreBluetooth

/// Shared BLE contract. Keep in sync with lib/ble/gatt.dart (phone) and
/// desktop/windows_driver (Windows). Messages are described in docs/PROTOCOL.md.
enum GATT {
    static let service = CBUUID(string: "CC8A9226-538A-41AA-B390-85DB92127C62")
    /// Hub → phone. Notify + read. UTF-8 JSON messages with a topic "t".
    static let stats = CBUUID(string: "46ABD5B3-C525-463B-9E0A-5EB81163CCBB")
    /// Phone → Hub. Write. UTF-8 JSON, e.g. {"t":"hello","name":"<phone name>"}.
    static let command = CBUUID(string: "58DB6A63-A4AB-4A47-A369-966CAF61956F")
    static let localName = "Deskmate"
}
