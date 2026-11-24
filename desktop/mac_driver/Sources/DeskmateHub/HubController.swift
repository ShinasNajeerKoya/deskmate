import Foundation

/// Wires the Wi-Fi link to the data collectors, each on its own schedule,
/// and routes the phone's commands. Data is only sent while a phone is connected,
/// and slower-changing data only when it changes (to keep Bluetooth traffic light).
final class HubController {
    let model = HubModel()
    private let system = SystemCollector()
    private let bluetooth = BluetoothCollector()
    private let wifi = WiFiCollector()
    private let music = MusicCollector()
    private let claude = ClaudeCollector()
    private let wifiLink = WifiServer()
    private var power: PowerMonitor?
    private var timers: [Timer] = []
    private var seq = 0
    private var asleep = false
    private var lastSent: [String: Data] = [:]
    private var sentArt: Set<String> = []

    func start() {
        wifiLink.onPhonesChanged = { [weak self] in self?.updatePhones() }
        wifiLink.onReady = { [weak self] in self?.sendEverything() }
        wifiLink.onCommand = { [weak self] command in self?.handle(command) }
        wifiLink.onPairingChanged = { [weak self] in self?.updatePairing() }
        wifiLink.start()
        if ProcessInfo.processInfo.environment["DESKMATE_TEST_PAIR_CODE"] != nil { wifiLink.beginPairing() }
        bluetooth.onChange = { [weak self] in self?.sendIfChanged(self?.bluetooth.message()) }
        wifi.onChange = { [weak self] in self?.sendIfChanged(self?.wifi.message()) }
        music.art.onReady = { [weak self] id in self?.sendArt(id) }
        power = PowerMonitor { [weak self] asleep in
            guard let self, self.asleep != asleep else { return }
            self.asleep = asleep
            self.sendPower()
        }

        // Kept light: the same Bluetooth radio streams your earphones' audio.
        every(2) { $0.sendSystem() }
        every(3) { $0.sendMusic() }
        every(5) { $0.sendIfChanged($0.bluetooth.message()) }
        every(10) { $0.sendIfChanged($0.wifi.message()) }
        every(5) { $0.sendClaude() }
        every(3600) { $0.sendTime() }

        LoginItem.enableOnFirstLaunch()
        model.openAtLogin = LoginItem.isEnabled
        model.claudeSetup = ClaudeCollector.setup
        ClaudeCollector.refreshStatusScript()
        ClaudeCollector.installHooks()
        updatePairing()
    }

    /// "Connect Claude usage…" in the menu.
    func connectClaude() {
        model.claudeMessage = ClaudeCollector.connect()
        model.claudeSetup = ClaudeCollector.setup
        sendClaude()
    }

    // MARK: Scheduling

    private func every(_ seconds: TimeInterval, _ action: @escaping (HubController) -> Void) {
        let timer = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshProblems()
            guard self.wifiLink.hasPhone else { return }
            action(self)
        }
        timer.tolerance = seconds * 0.1
        RunLoop.main.add(timer, forMode: .common)
        timers.append(timer)
    }

    /// A phone just connected: send the clock, power state and everything we know.
    private func sendEverything() {
        lastSent.removeAll()
        sendTime()
        sendPower()
        sendSystem()
        sendIfChanged(bluetooth.message())
        sendIfChanged(wifi.message())
        sentArt.removeAll()
        sendMusic()
        sendClaude()
    }

    // MARK: Senders

    private func sendSystem() {
        var m = system.collect()
        seq += 1
        m["seq"] = seq
        broadcast(m)
    }

    private func sendMusic() {
        music.read { [weak self] message in
            guard let self else { return }
            // Nothing playing: send an empty music message once so the phone clears its tile.
            self.sendIfChanged(message ?? ["t": "music"])
            // Make sure the phone has every image this message refers to.
            var ids: [String] = []
            if let id = message?["art"] as? String { ids.append(id) }
            for key in ["prev", "next"] {
                for row in (message?[key] as? [[Any]]) ?? [] where row.count > 3 {
                    if let id = row[3] as? String, !id.isEmpty { ids.append(id) }
                }
            }
            ids.forEach(self.sendArt)
        }
    }

    /// Sends one artwork image (base64 JPEG) once per connection.
    private func sendArt(_ id: String) {
        guard wifiLink.hasPhone, !sentArt.contains(id), let data = music.art.data(for: id) else { return }
        sentArt.insert(id)
        broadcast(["t": "art", "id": id, "d": data.base64EncodedString()])
    }

    private func sendClaude() {
        claude.collect { [weak self] m in self?.sendIfChanged(m) }
    }

    /// Clock sync: the phone has no network time, so it uses the Mac's clock and time zone.
    private func sendTime() {
        broadcast([
            "t": "time",
            "ts": Int(Date().timeIntervalSince1970 * 1000),
            "tz": TimeZone.current.secondsFromGMT() / 60,
        ])
    }

    private func sendPower() {
        broadcast(["t": "power", "asleep": asleep])
    }

    /// Sends a message only if it differs from the last one of the same topic.
    private func sendIfChanged(_ message: [String: Any]?) {
        guard let message, let topic = message["t"] as? String,
              let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]) else { return }
        guard lastSent[topic] != data else { return }
        lastSent[topic] = data
        broadcast(message)
    }

    /// Sends to the phone over the encrypted Wi-Fi link.
    private func broadcast(_ message: [String: Any]) {
        wifiLink.send(message)
    }

    private func updatePhones() {
        model.connected = wifiLink.hasPhone
        model.phoneName = wifiLink.phoneName
    }

    /// "Pair a phone over Wi-Fi…" in the menu.
    func pairOverWifi() {
        wifiLink.beginPairing()
    }

    private func updatePairing() {
        model.pairingCode = wifiLink.pairingActive ? wifiLink.pairingCode : nil
        model.localAddress = WifiServer.localAddress
        model.wifiPaired = !wifiLink.phones.isEmpty
    }

    // MARK: Commands from the phone

    private func handle(_ command: String) {
        if command.hasPrefix("bt.") {
            bluetooth.handle(command)
        } else if command.hasPrefix("wifi.") {
            wifi.handle(command)
        } else if command.hasPrefix("music.") {
            music.handle(command)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.sendMusic() }
        }
    }

    private func refreshProblems() {
        model.problems = [music.problem].compactMap { $0 }
    }

    /// Debugging: `DeskmateHub --dump` prints one message of each kind and exits.
    static func dumpAndExit() -> Never {
        func show(_ m: [String: Any]?) {
            guard let m, let d = try? JSONSerialization.data(withJSONObject: m, options: [.sortedKeys]) else {
                print("(none)")
                return
            }
            print("\(d.count) B  \(String(decoding: d, as: UTF8.self))")
        }
        let system = SystemCollector(), bluetooth = BluetoothCollector(), wifi = WiFiCollector()
        let music = MusicCollector(), claude = ClaudeCollector()
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        show(system.collect())
        show(bluetooth.message())
        show(wifi.message())
        var done = 0
        music.read { show($0); print("music problem:", music.problem ?? "none"); done += 1 }
        claude.collect { show($0); done += 1 }
        print("claude setup:", ClaudeCollector.setup)
        while done < 2 { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }
        exit(0)
    }
}
