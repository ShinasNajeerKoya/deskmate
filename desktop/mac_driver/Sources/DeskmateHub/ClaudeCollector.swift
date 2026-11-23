import Foundation

/// Claude usage for the phone's Claude page.
///
/// - Tokens per day (last 7 days), share by model, active sessions and
///   "waiting for you": read from Claude Code's session logs
///   (~/.claude/projects/**/*.jsonl). That format isn't documented and may change
///   between Claude Code versions, so parsing is defensive and skips anything unexpected.
/// - 5-hour and weekly limits: from Claude Code's status line, which passes
///   `rate_limits` (Pro/Max/Ultra plans) to a script. "Connect Claude usage…" in the
///   Hub menu installs that script; it saves the JSON to claude-status.json.
/// Never reads credentials and never calls any Anthropic endpoint.
final class ClaudeCollector {
    static let supportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Deskmate")
    static let statusFile = supportDir.appendingPathComponent("claude-status.json")
    static let scriptFile = supportDir.appendingPathComponent("claude-statusline.sh")
    static let settingsFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    private let projects = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")

    private struct FileState { var offset: UInt64 = 0; var lastKind = ""; var lastStop = "" }
    private var files: [URL: FileState] = [:]
    /// message id → (day start, model, tokens), deduplicated (one reply can span several log lines).
    private var replies: [String: (day: Date, model: String, tokens: Int)] = [:]
    private let queue = DispatchQueue(label: "deskmate.claude")

    // MARK: Status line setup

    enum Setup { case connected, notConnected, otherStatusLine }

    static var setup: Setup {
        guard let settings = readSettings() else { return .notConnected }
        guard let status = settings["statusLine"] as? [String: Any] else { return .notConnected }
        let command = status["command"] as? String ?? ""
        return command.contains("claude-statusline.sh") && command.contains("Deskmate") ? .connected : .otherStatusLine
    }

    /// Installs the status-line script and points Claude Code at it.
    /// Backs up settings.json first; refuses if another status line is configured.
    static func connect() -> String? {
        if setup == .otherStatusLine {
            return "Claude Code already has a status line; Deskmate won't replace it."
        }
        do {
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let script = """
            #!/bin/sh
            # Deskmate: saves what Claude Code passes to its status line (incl. rate_limits) for Deskmate Hub.
            dir="$HOME/Library/Application Support/Deskmate"
            cat > "$dir/claude-status.json.tmp" && mv "$dir/claude-status.json.tmp" "$dir/claude-status.json"

            """
            try script.write(to: scriptFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptFile.path)

            var settings = readSettings() ?? [:]
            if FileManager.default.fileExists(atPath: settingsFile.path) {
                let backup = settingsFile.deletingLastPathComponent().appendingPathComponent("settings.json.deskmate-backup")
                try? FileManager.default.removeItem(at: backup)
                try FileManager.default.copyItem(at: settingsFile, to: backup)
            } else {
                try FileManager.default.createDirectory(at: settingsFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            settings["statusLine"] = ["type": "command", "command": "\"\(scriptFile.path)\""]
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsFile, options: .atomic)
            return nil
        } catch {
            return "Couldn't connect Claude usage: \(error.localizedDescription)"
        }
    }

    private static func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsFile) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: Collecting

    /// Builds the `claude` message off the main thread; calls back on the main thread.
    func collect(_ done: @escaping ([String: Any]) -> Void) {
        queue.async {
            let m = self.build()
            DispatchQueue.main.async { done(m) }
        }
    }

    private func build() -> [String: Any] {
        var m: [String: Any] = ["t": "claude"]
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else { return m }

        // Session logs: read only what's new since last time.
        var active = 0, waiting = 0
        for url in logFiles(modifiedAfter: weekStart) {
            readNewLines(url, since: weekStart)
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if now.timeIntervalSince(modified) < 30 * 60 {
                active += 1
                let s = files[url] ?? FileState()
                if s.lastKind == "assistant" && s.lastStop == "end_turn" { waiting += 1 }
            }
        }
        replies = replies.filter { $0.value.day >= weekStart }

        var perDay = [Int](repeating: 0, count: 7)
        var perModel: [String: Int] = [:]
        for r in replies.values {
            let index = calendar.dateComponents([.day], from: weekStart, to: r.day).day ?? -1
            if (0..<7).contains(index) { perDay[index] += r.tokens }
            perModel[r.model, default: 0] += r.tokens
        }
        m["tokens7d"] = perDay
        let total = max(1, perModel.values.reduce(0, +))
        m["models"] = Dictionary(uniqueKeysWithValues: perModel.filter { $0.value > 0 }.sorted { $0.value > $1.value }.prefix(3)
            .map { ($0.key, dec(Double($0.value) / Double(total), 2)) })
        m["sessions"] = active
        m["waiting"] = waiting

        // Limits from the status line (only present on subscription plans).
        if let data = try? Data(contentsOf: Self.statusFile),
           let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let limits = status["rate_limits"] as? [String: Any] {
            let nowSec = now.timeIntervalSince1970
            if let h5 = limits["five_hour"] as? [String: Any], let pct = h5["used_percentage"] as? Double {
                let reset = h5["resets_at"] as? Double ?? 0
                if reset == 0 || reset > nowSec {
                    m["h5"] = dec(pct)
                    if reset > 0 { m["h5Reset"] = Int((reset - nowSec) / 60) }
                }
            }
            if let wk = limits["seven_day"] as? [String: Any], let pct = wk["used_percentage"] as? Double {
                let reset = wk["resets_at"] as? Double ?? 0
                if reset == 0 || reset > nowSec {
                    m["wk"] = dec(pct)
                    if reset > 0 {
                        let f = DateFormatter()
                        f.dateFormat = "EEE"
                        m["wkReset"] = f.string(from: Date(timeIntervalSince1970: reset))
                    }
                }
            }
        }
        return m
    }

    private func logFiles(modifiedAfter date: Date) -> [URL] {
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)
        else { return [] }
        var result: [URL] = []
        for dir in projectDirs {
            let entries = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in entries where url.pathExtension == "jsonl" {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if modified >= date { result.append(url) }
            }
        }
        return result
    }

    private func readNewLines(_ url: URL, since weekStart: Date) {
        var state = files[url] ?? FileState()
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        if size < state.offset { state = FileState() }  // file was rewritten
        guard size > state.offset else { files[url] = state; return }
        try? handle.seek(toOffset: state.offset)
        guard let data = try? handle.readToEnd() else { return }

        // Only complete lines; a partial last line is read next time.
        guard let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { files[url] = state; return }
        let complete = data[data.startIndex...lastNewline]
        state.offset += UInt64(complete.count)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for line in complete.split(separator: UInt8(ascii: "\n")) {
            guard let json = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let kind = json["type"] as? String else { continue }
            if kind == "user" || kind == "assistant" {
                state.lastKind = kind
                state.lastStop = ((json["message"] as? [String: Any])?["stop_reason"] as? String) ?? ""
            }
            guard kind == "assistant",
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any],
                  let stamp = json["timestamp"] as? String, let date = iso.date(from: stamp), date >= weekStart
            else { continue }
            let id = (message["id"] as? String) ?? (json["uuid"] as? String) ?? UUID().uuidString
            let tokens = ["input_tokens", "output_tokens", "cache_creation_input_tokens"]
                .reduce(0) { $0 + ((usage[$1] as? Int) ?? 0) }
            replies[id] = (Calendar.current.startOfDay(for: date), Self.modelName(message["model"] as? String), tokens)
        }
        files[url] = state
    }

    /// "claude-opus-5-5" → "Opus".
    static func modelName(_ id: String?) -> String {
        guard let id else { return "Other" }
        for family in ["opus", "sonnet", "haiku", "fable"] where id.contains(family) { return family.capitalized }
        return "Other"
    }
}
