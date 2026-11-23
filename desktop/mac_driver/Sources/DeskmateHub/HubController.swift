import Foundation

/// Wires the Bluetooth peripheral, CPU sampling, clock sync and sleep/wake together.
final class HubController {
    let model = HubModel()
    private let peripheral = Peripheral()
    private let cpu = CPUSampler()
    private var power: PowerMonitor?
    private var timers: [Timer] = []
    private var seq = 0
    private var asleep = false

    func start() {
        peripheral.onBluetooth = { [model] state in model.bluetooth = state }
        peripheral.onPhonesChanged = { [model] connected, name in
            model.connected = connected
            model.phoneName = connected ? name : nil
        }
        peripheral.onSubscribed = { [weak self] in
            self?.sendTime()
            self?.sendPower()
        }
        power = PowerMonitor { [weak self] asleep in
            guard let self, self.asleep != asleep else { return }
            self.asleep = asleep
            self.sendPower()
        }
        _ = cpu.sample()  // prime the delta

        // Live CPU once a second; clock sync hourly (and on every connection).
        add(Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.sendCPU() })
        add(Timer(timeInterval: 3600, repeats: true) { [weak self] _ in self?.sendTime() })
        LoginItem.enableOnFirstLaunch()
        model.openAtLogin = LoginItem.isEnabled
    }

    private func add(_ timer: Timer) {
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        timers.append(timer)
    }

    private func sendCPU() {
        guard let value = cpu.sample() else { return }
        seq += 1
        peripheral.send(["t": "sys", "seq": seq, "cpu": (value * 10).rounded() / 10])
    }

    /// Clock sync: the phone has no network time, so it uses the Mac's clock and time zone.
    private func sendTime() {
        peripheral.send([
            "t": "time",
            "ts": Int(Date().timeIntervalSince1970 * 1000),
            "tz": TimeZone.current.secondsFromGMT() / 60,
        ])
    }

    private func sendPower() {
        peripheral.send(["t": "power", "asleep": asleep])
    }
}
