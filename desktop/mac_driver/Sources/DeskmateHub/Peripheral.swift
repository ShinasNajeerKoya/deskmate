import CoreBluetooth
import Foundation

/// GATT server: advertises the Deskmate service, pushes messages to the phone,
/// and receives the phone's writes (its name, later commands).
final class Peripheral: NSObject, CBPeripheralManagerDelegate {
    var onBluetooth: ((HubModel.Bluetooth) -> Void)?
    var onPhonesChanged: ((_ connected: Bool, _ name: String?) -> Void)?
    var onSubscribed: (() -> Void)?

    private var manager: CBPeripheralManager!
    private let stats = CBMutableCharacteristic(
        type: GATT.stats, properties: [.read, .notify], value: nil, permissions: [.readable])
    private let command = CBMutableCharacteristic(
        type: GATT.command, properties: [.write, .writeWithoutResponse], value: nil, permissions: [.writeable])
    private var subscribers: [CBCentral] = []
    private var names: [UUID: String] = [:]
    private var latest = Data()
    private var pending: [Data] = []

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Sends one JSON message to every subscribed phone.
    func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]) else { return }
        if message["t"] as? String == "sys" { latest = data }
        guard !subscribers.isEmpty else { return }
        if !pending.isEmpty || !manager.updateValue(data, for: stats, onSubscribedCentrals: nil) {
            pending.append(data)
            if pending.count > 20 { pending.removeFirst() }  // stale stats are worthless
        }
    }

    private func publishPhones() {
        let name = subscribers.lazy.compactMap { self.names[$0.identifier] }.first
        onPhonesChanged?(!subscribers.isEmpty, name)
    }

    // MARK: CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            onBluetooth?(.on)
            subscribers.removeAll()
            let service = CBMutableService(type: GATT.service, primary: true)
            service.characteristics = [stats, command]
            manager.removeAllServices()
            manager.add(service)
        case .poweredOff: onBluetooth?(.off)
        case .unauthorized: onBluetooth?(.unauthorized)
        case .unsupported: onBluetooth?(.unsupported)
        default: break
        }
        publishPhones()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { NSLog("Deskmate Hub: add service failed: \(error.localizedDescription)"); return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [GATT.service],
            CBAdvertisementDataLocalNameKey: GATT.localName,
        ])
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        subscribers.append(central)
        publishPhones()
        onSubscribed?()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        publishPhones()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.offset <= latest.count else {
            manager.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = latest.subdata(in: request.offset..<latest.count)
        manager.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let data = request.value,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if json["t"] as? String == "hello", let name = json["name"] as? String, !name.isEmpty {
                names[request.central.identifier] = name
                publishPhones()
            }
            // Commands ("t":"cmd") are handled in a later version.
        }
        if let first = requests.first { manager.respond(to: first, withResult: .success) }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        while let data = pending.first {
            guard manager.updateValue(data, for: stats, onSubscribedCentrals: nil) else { return }
            pending.removeFirst()
        }
    }
}
