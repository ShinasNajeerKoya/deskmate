import CoreBluetooth
import Foundation

/// GATT server: advertises the Deskmate service and pushes notifications to subscribed phones.
final class Peripheral: NSObject, CBPeripheralManagerDelegate {
    private var manager: CBPeripheralManager!
    private let stats = CBMutableCharacteristic(
        type: GATT.stats, properties: [.read, .notify], value: nil, permissions: [.readable])
    private var subscribers: [CBCentral] = []
    private var latest = Data()
    private var pending: Data?

    var subscriberCount: Int { subscribers.count }

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Sends to all subscribers. If the transmit queue is full, keeps only the newest value
    /// and retries when CoreBluetooth says it's ready (stale stats are worthless).
    func send(_ data: Data) {
        latest = data
        guard !subscribers.isEmpty else { return }
        if let min = subscribers.map(\.maximumUpdateValueLength).min(), data.count > min {
            log("warning: payload \(data.count) B exceeds max update length \(min) B (MTU too small)")
        }
        if !manager.updateValue(data, for: stats, onSubscribedCentrals: nil) {
            pending = data
        }
    }

    // MARK: CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            log("Bluetooth on, registering service")
            subscribers.removeAll()
            let service = CBMutableService(type: GATT.service, primary: true)
            service.characteristics = [stats]
            manager.removeAllServices()
            manager.add(service)
        case .poweredOff:
            log("Bluetooth is off. Turn it on to advertise.")
        case .unauthorized:
            log("Bluetooth permission denied. Allow it in System Settings → Privacy & Security → Bluetooth "
                + "for the app running this (Terminal / VS Code). If it's greyed out, IT may be blocking it.")
        case .unsupported:
            log("This Mac doesn't support BLE peripheral mode.")
        case .resetting:
            log("Bluetooth resetting…")
        case .unknown:
            break
        @unknown default:
            log("Bluetooth state \(peripheral.state.rawValue)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            log("Failed to add service: \(error.localizedDescription)")
            return
        }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [GATT.service],
            CBAdvertisementDataLocalNameKey: GATT.localName,
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            log("Advertising failed: \(error.localizedDescription)")
        } else {
            log("Advertising as \"\(GATT.localName)\" (\(GATT.service.uuidString))")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        subscribers.append(central)
        log("Phone subscribed (\(central.identifier.uuidString.prefix(8))…, max update \(central.maximumUpdateValueLength) B)")
        send(latest)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        log("Phone unsubscribed / disconnected (\(central.identifier.uuidString.prefix(8))…)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.offset <= latest.count else {
            manager.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = latest.subdata(in: request.offset..<latest.count)
        manager.respond(to: request, withResult: .success)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let data = pending else { return }
        pending = nil
        send(data)
    }
}

func log(_ message: String) {
    let time = Date().formatted(date: .omitted, time: .standard)
    print("[\(time)] \(message)")
    fflush(stdout)
}
