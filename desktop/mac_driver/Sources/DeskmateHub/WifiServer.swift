import CommonCrypto
import CryptoKit
import Foundation
import Network

/// Wi-Fi link to the Deskmate phone app on the local network (preferred over
/// Bluetooth, which leaves the radio free for earphones). See docs/PROTOCOL.md.
///
/// - Found by the phone via Bonjour (`_deskmate._tcp`), or by typed IP.
/// - Frames: 4-byte big-endian length + payload.
/// - Pairing (once): the menu shows a 6-digit code (2 minutes, one attempt). The phone
///   proves it knows the code (HMAC with a PBKDF2 key) before the Hub hands it a random
///   256-bit key, encrypted with that code-derived key.
/// - Sessions: a fresh key per connection (HMAC of the long-term key and both nonces);
///   every message is AES-256-GCM.
final class WifiServer {
    static let port: NWEndpoint.Port = 47820
    static let serviceType = "_deskmate._tcp"

    var onPhonesChanged: (() -> Void)?
    var onCommand: ((String) -> Void)?
    var onReady: (() -> Void)?
    var onPairingChanged: (() -> Void)?

    private var listener: NWListener?
    private var sessions: [WifiSession] = []
    private(set) var pairingCode: String?
    private(set) var pairingExpires: Date?
    let phones = PairedPhones()

    var hasPhone: Bool { sessions.contains { $0.isReady } }
    var phoneName: String? { sessions.first { $0.isReady }?.phoneName }
    var pairingActive: Bool { pairingCode != nil && (pairingExpires ?? .distantPast) > Date() }

    func start() {
        do {
            let listener = try NWListener(using: .tcp, on: Self.port)
            listener.service = NWListener.Service(name: Host.current().localizedName, type: Self.serviceType)
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state { NSLog("Deskmate Hub Wi-Fi: \(error)") }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            NSLog("Deskmate Hub Wi-Fi: can't listen: \(error)")
        }
    }

    /// "Pair a phone over Wi-Fi…": a fresh 6-digit code, valid for 2 minutes.
    func beginPairing() {
        // DESKMATE_TEST_PAIR_CODE: fixed code for automated protocol tests only.
        pairingCode = ProcessInfo.processInfo.environment["DESKMATE_TEST_PAIR_CODE"]
            ?? String(format: "%06d", Int.random(in: 0..<1_000_000))
        pairingExpires = Date().addingTimeInterval(120)
        onPairingChanged?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 121) { [weak self] in
            guard let self, let expires = self.pairingExpires, expires <= Date() else { return }
            self.endPairing()
        }
    }

    func endPairing() {
        pairingCode = nil
        pairingExpires = nil
        onPairingChanged?()
    }

    func send(_ message: [String: Any]) {
        for session in sessions where session.isReady { session.sendEncrypted(message) }
    }

    private func accept(_ connection: NWConnection) {
        let session = WifiSession(connection: connection, server: self)
        sessions.append(session)
        session.start()
    }

    fileprivate func closed(_ session: WifiSession) {
        let wasReady = session.isReady
        sessions.removeAll { $0 === session }
        if wasReady { onPhonesChanged?() }
    }

    fileprivate func ready(_ session: WifiSession) {
        onPhonesChanged?()
        onReady?()
    }

    /// This Mac's IPv4 address on Wi-Fi/Ethernet, for typing on the phone if discovery is blocked.
    static var localAddress: String? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }
        var p: UnsafeMutablePointer<ifaddrs>? = first
        var fallback: String?
        while let ifa = p {
            defer { p = ifa.pointee.ifa_next }
            guard let sa = ifa.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ifa.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let address = String(cString: host)
            if name == "en0" { return address }
            fallback = fallback ?? address
        }
        return fallback
    }
}

/// One phone connection: handshake, then encrypted messages both ways.
private final class WifiSession {
    private enum Stage { case hello, proof, ready, closed }

    let connection: NWConnection
    weak var server: WifiServer?
    private var stage = Stage.hello
    private var buffer = Data()
    private var mode = ""
    private var phoneID = ""
    private(set) var phoneName: String?
    private var phoneNonce = Data()
    private var hubNonce = Data()
    private var sessionKey: SymmetricKey?

    var isReady: Bool { stage == .ready }

    init(connection: NWConnection, server: WifiServer) {
        self.connection = connection
        self.server = server
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.close()
            default: break
            }
        }
        connection.start(queue: .main)
        receive()
        // A connection that never finishes the handshake is dropped.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            if let self, self.stage != .ready { self.close() }
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { self.buffer.append(data); self.drain() }
            if isComplete || error != nil { self.close() } else if self.stage != .closed { self.receive() }
        }
    }

    private func drain() {
        while buffer.count >= 4 {
            let length = Int(buffer.prefix(4).reduce(0) { $0 << 8 | UInt32($1) })
            guard length <= 1 << 20 else { return close() }
            guard buffer.count >= 4 + length else { return }
            let frame = buffer.subdata(in: buffer.startIndex + 4 ..< buffer.startIndex + 4 + length)
            buffer.removeSubrange(buffer.startIndex ..< buffer.startIndex + 4 + length)
            handle(frame)
            if stage == .closed { return }
        }
    }

    private func handle(_ frame: Data) {
        guard let server else { return close() }
        switch stage {
        case .hello:
            guard let json = Self.json(frame), json["t"] as? String == "hello",
                  let mode = json["mode"] as? String, let id = json["id"] as? String,
                  let nonce = (json["nonce"] as? String).flatMap({ Data(base64Encoded: $0) }), nonce.count == 16
            else { return close() }
            self.mode = mode
            phoneID = id
            phoneName = (json["name"] as? String).map { String($0.prefix(40)) }
            phoneNonce = nonce
            if mode == "pair" && !server.pairingActive { return fail("not-pairing") }
            if mode == "resume" && server.phones.key(for: id) == nil { return fail("unknown-phone") }
            if mode != "pair" && mode != "resume" { return close() }
            hubNonce = Self.random(16)
            sendPlain(["t": "challenge", "nonce": hubNonce.base64EncodedString()])
            stage = .proof

        case .proof:
            guard let json = Self.json(frame), json["t"] as? String == "proof",
                  let mac = (json["mac"] as? String).flatMap({ Data(base64Encoded: $0) })
            else { return close() }
            if mode == "pair" { finishPairing(mac, server) } else { finishResume(mac, server) }

        case .ready:
            guard let key = sessionKey, let box = try? AES.GCM.SealedBox(combined: frame),
                  let plain = try? AES.GCM.open(box, using: key), let json = Self.json(plain) else { return close() }
            if json["t"] as? String == "cmd", let command = json["c"] as? String { server.onCommand?(command) }

        case .closed:
            break
        }
    }

    private func finishPairing(_ mac: Data, _ server: WifiServer) {
        guard let code = server.pairingCode, server.pairingActive else { return fail("not-pairing") }
        let temp = Self.pbkdf2(code, salt: phoneNonce + hubNonce, rounds: 100_000)
        let tempKey = SymmetricKey(data: temp)
        guard HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: Data("deskmate-pair-phone".utf8), using: tempKey)
        else {
            server.endPairing()  // one attempt per code
            return fail("wrong-code")
        }
        let longTerm = Self.random(32)
        server.phones.save(id: phoneID, key: longTerm, name: phoneName)
        server.endPairing()
        guard let box = try? AES.GCM.seal(longTerm, using: tempKey).combined else { return close() }
        sendPlain(["t": "key", "box": box.base64EncodedString(), "hub": Host.current().localizedName ?? "Mac"])
        // The phone reconnects with its new key.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.close() }
    }

    private func finishResume(_ mac: Data, _ server: WifiServer) {
        guard let longTerm = server.phones.key(for: phoneID) else { return fail("unknown-phone") }
        let session = Data(HMAC<SHA256>.authenticationCode(for: phoneNonce + hubNonce, using: SymmetricKey(data: longTerm)))
        let key = SymmetricKey(data: session)
        guard HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: Data("deskmate-phone".utf8), using: key)
        else { return close() }
        sessionKey = key
        stage = .ready
        if let name = phoneName { server.phones.rename(id: phoneID, name: name) }
        sendEncrypted(["t": "ready"])
        server.ready(self)
    }

    // MARK: Sending

    func sendEncrypted(_ message: [String: Any]) {
        guard let key = sessionKey,
              let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]),
              let box = try? AES.GCM.seal(data, using: key).combined else { return }
        write(box)
    }

    private func sendPlain(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        write(data)
    }

    private func write(_ payload: Data) {
        var length = UInt32(payload.count).bigEndian
        let frame = Data(bytes: &length, count: 4) + payload
        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            if error != nil { self?.close() }
        })
    }

    private func fail(_ reason: String) {
        sendPlain(["t": "error", "reason": reason])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.close() }
    }

    private func close() {
        guard stage != .closed else { return }
        stage = .closed
        connection.cancel()
        server?.closed(self)
    }

    // MARK: Helpers

    private static func json(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func random(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private static func pbkdf2(_ password: String, salt: Data, rounds: UInt32) -> Data {
        var derived = [UInt8](repeating: 0, count: 32)
        let passwordBytes = Array(password.utf8)
        let saltBytes = [UInt8](salt)
        _ = passwordBytes.withUnsafeBufferPointer { pw in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                UnsafeRawPointer(pw.baseAddress!).assumingMemoryBound(to: CChar.self), pw.count,
                saltBytes, saltBytes.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                &derived, derived.count)
        }
        return Data(derived)
    }
}

/// Phones paired over Wi-Fi: id → long-term key and name. Stored in
/// ~/Library/Application Support/Deskmate/paired-phones.json, readable only by you.
final class PairedPhones {
    private struct Phone: Codable { var key: String; var name: String? }
    private let file = ClaudeCollector.supportDir.appendingPathComponent("paired-phones.json")
    private var phones: [String: Phone]

    init() {
        phones = (try? JSONDecoder().decode([String: Phone].self, from: Data(contentsOf: file))) ?? [:]
    }

    var isEmpty: Bool { phones.isEmpty }

    func key(for id: String) -> Data? { phones[id].flatMap { Data(base64Encoded: $0.key) } }

    func save(id: String, key: Data, name: String?) {
        phones[id] = Phone(key: key.base64EncodedString(), name: name)
        persist()
    }

    func rename(id: String, name: String) {
        guard phones[id]?.name != name else { return }
        phones[id]?.name = name
        persist()
    }

    func forgetAll() {
        phones.removeAll()
        persist()
    }

    private func persist() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(phones) else { return }
        try? data.write(to: file, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
