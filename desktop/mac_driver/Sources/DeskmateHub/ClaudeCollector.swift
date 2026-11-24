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
    private var replies: [String: (day: Date, at: Date, model: String, tokens: Int)] = [:]
    private let queue = DispatchQueue(label: "deskmate.claude")

    // MARK: Status line setup

    enum Setup { case connected, notConnected, otherStatusLine }

    static var setup: Setup {
        guard let settings = readSettings() else { return .notConnected }
        guard let status = settings["statusLine"] as? [String: Any] else { return .notConnected }
        let command = status["command"] as? String ?? ""
        return command.contains("claude-statusline.sh") && command.contains("Deskmate") ? .connected : .otherStatusLine
    }

    /// The status-line script. Claude Code also calls it at the start of a session, before it knows
    /// the limits; those calls must not replace a good reading, so only input with `rate_limits` is kept.
    static let statusScript = """
    #!/bin/sh
    # Deskmate: saves what Claude Code passes to its status line (incl. rate_limits) for Deskmate Hub.
    dir="$HOME/Library/Application Support/Deskmate"
    cat > "$dir/claude-status.json.tmp"
    if grep -q '"rate_limits"' "$dir/claude-status.json.tmp"; then
      mv "$dir/claude-status.json.tmp" "$dir/claude-status.json"
    else
      rm -f "$dir/claude-status.json.tmp"
    fi

    """

    /// Brings an already-installed status-line script up to date (called on every launch).
    static func refreshStatusScript() {
        guard setup == .connected else { return }
        try? statusScript.write(to: scriptFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptFile.path)
    }

    /// Installs the status-line script and points Claude Code at it.
    /// Backs up settings.json first; refuses if another status line is configured.
    static func connect() -> String? {
        if setup == .otherStatusLine {
            return "Claude Code already has a status line; Deskmate won't replace it."
        }
        do {
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            try Self.statusScript.write(to: scriptFile, atomically: true, encoding: .utf8)
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


    // MARK: Hooks (what each Claude Code session is doing)
    //
    // Claude Code runs this script on session events (also from the VS Code extension and the
    // Claude app). It keeps one small file per session with its state, never any prompt text.

    static let hookFile = supportDir.appendingPathComponent("claude-hook.sh")
    static let sessionsDir = supportDir.appendingPathComponent("sessions")
    static let hookEvents = ["SessionStart", "UserPromptSubmit", "PostToolUse", "Notification", "Stop", "SessionEnd"]

    private static func hookGroups(_ settings: [String: Any], _ event: String) -> [[String: Any]] {
        ((settings["hooks"] as? [String: Any])?[event] as? [[String: Any]]) ?? []
    }

    private static func isOurs(_ group: [String: Any]) -> Bool {
        ((group["hooks"] as? [[String: Any]]) ?? []).contains { (($0["command"] as? String) ?? "").contains("claude-hook.sh") }
    }

    static var hooksInstalled: Bool {
        guard let settings = readSettings() else { return false }
        return hookEvents.allSatisfy { event in hookGroups(settings, event).contains(where: isOurs) }
    }

    /// Installs the hook script and adds our entries to ~/.claude/settings.json (other hooks stay).
    /// Backs the file up first. Safe to call on every launch.
    static func installHooks() {
        do {
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let script = """
            #!/bin/sh
            # Deskmate: records what a Claude Code session is doing (state only, no prompt text) for Deskmate Hub.
            [ -n "$DESKMATE_PING" ] && exit 0  # the background refresh isn't one of your sessions
            dir="$HOME/Library/Application Support/Deskmate/sessions"
            mkdir -p "$dir"
            input=$(cat)
            sid=$(printf '%s' "$input" | /usr/bin/plutil -extract session_id raw -o - - 2>/dev/null)
            [ -z "$sid" ] && exit 0
            case "$1" in
              SessionEnd) rm -f "$dir/$sid.json"; exit 0 ;;
              Stop|Notification) state=waiting ;;
              SessionStart) state=idle ;;
              *) state=working ;;
            esac
            printf '{"state":"%s","at":%s}' "$state" "$(date +%s)" > "$dir/$sid.json.tmp" && mv "$dir/$sid.json.tmp" "$dir/$sid.json"

            """
            try script.write(to: hookFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookFile.path)
            guard !hooksInstalled else { return }

            var settings = readSettings() ?? [:]
            if FileManager.default.fileExists(atPath: settingsFile.path) {
                let backup = settingsFile.deletingLastPathComponent().appendingPathComponent("settings.json.deskmate-hooks-backup")
                try? FileManager.default.removeItem(at: backup)
                try FileManager.default.copyItem(at: settingsFile, to: backup)
            }
            var hooks = settings["hooks"] as? [String: Any] ?? [:]
            for event in hookEvents {
                var groups = hookGroups(settings, event)
                if groups.contains(where: isOurs) { continue }
                var group: [String: Any] = ["hooks": [["type": "command", "command": "\"\(hookFile.path)\" \(event)"]]]
                if event == "PostToolUse" { group["matcher"] = "*" }
                groups.append(group)
                hooks[event] = groups
            }
            settings["hooks"] = hooks
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsFile, options: .atomic)
        } catch {
            print("Couldn't install Claude hooks: \(error.localizedDescription)")
        }
    }

    /// Sessions and how many wait for you, from the hook files. Files older than 2 hours are dropped
    /// (a session that crashed never says goodbye).
    private func hookSessions(now: Date) -> (count: Int, waiting: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.sessionsDir, includingPropertiesForKeys: nil)) ?? []
        var count = 0, waiting = 0
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let at = json["at"] as? Double else { continue }
            if now.timeIntervalSince1970 - at > 2 * 3600 { try? FileManager.default.removeItem(at: file); continue }
            count += 1
            if json["state"] as? String == "waiting" { waiting += 1 }
        }
        return (count, waiting)
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
            if now.timeIntervalSince(modified) < 10 * 60 {
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
        if Self.hooksInstalled {
            let h = hookSessions(now: now)
            active = h.count
            waiting = h.waiting
        }
        m["sessions"] = active
        m["waiting"] = waiting

        addLimits(to: &m, now: now, weekStart: weekStart)
        return m
    }

    // MARK: Limits
    //
    // Percentages are Claude Code's own last reading from its status line (with its age). They can't be
    // worked out from the session logs (the limit isn't a plain token count), so there is no estimate.
    // Without a fresh reading the phone shows the 5-hour block from the logs: tokens, per-hour tokens
    // and an approximate reset time.

    private struct Reading { var pct: Double; var resetsAt: Double }

    private func tokens(from: Date, to: Date) -> Int {
        replies.values.reduce(0) { $0 + (($1.at >= from && $1.at < to) ? $1.tokens : 0) }
    }

    /// The current 5-hour block from the logs: it starts at the hour of a first message and lasts 5 hours.
    private func logBlock(now: Date) -> (start: Date, tokens: Int)? {
        let sorted = replies.values.sorted { $0.at < $1.at }
        var start: Date?
        var sum = 0
        for r in sorted {
            if start == nil || r.at >= start!.addingTimeInterval(5 * 3600) {
                start = Self.hourStart(r.at)
                sum = 0
            }
            sum += r.tokens
        }
        guard let start, now < start.addingTimeInterval(5 * 3600) else { return nil }
        return (start, sum)
    }

    /// The start of the local clock hour (not the UTC hour: in a half-hour time zone those differ).
    private static func hourStart(_ d: Date) -> Date {
        Calendar.current.dateInterval(of: .hour, for: d)?.start ?? d
    }

    /// Every 5-hour block from the logs (oldest first): the start and the tokens used in it.
    private func logBlocks() -> [(start: Date, tokens: Int)] {
        var blocks: [(start: Date, tokens: Int)] = []
        for r in replies.values.sorted(by: { $0.at < $1.at }) {
            if let last = blocks.last, r.at < last.start.addingTimeInterval(5 * 3600) {
                blocks[blocks.count - 1].tokens += r.tokens
            } else {
                let start = Self.hourStart(r.at)
                blocks.append((start, r.tokens))
            }
        }
        return blocks
    }

    private func addLimits(to m: inout [String: Any], now: Date, weekStart: Date) {
        let nowSec = now.timeIntervalSince1970
        var five: Reading?, week: Reading?
        var statusAt: Date = .distantPast
        if let data = try? Data(contentsOf: Self.statusFile),
           let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let limits = status["rate_limits"] as? [String: Any] {
            statusAt = (try? Self.statusFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            func reading(_ key: String) -> Reading? {
                guard let o = limits[key] as? [String: Any], let pct = o["used_percentage"] as? Double else { return nil }
                return Reading(pct: pct, resetsAt: o["resets_at"] as? Double ?? 0)
            }
            five = reading("five_hour")
            week = reading("seven_day")
        }

        var windowStart: Date?, windowEnd: Date?, windowTokens = 0
        if let f = five, f.resetsAt > nowSec {
            m["h5"] = dec(f.pct)
            m["readAge"] = max(0, Int(now.timeIntervalSince(statusAt) / 60))
            windowStart = Date(timeIntervalSince1970: f.resetsAt - 5 * 3600)
            windowEnd = Date(timeIntervalSince1970: f.resetsAt)
            windowTokens = tokens(from: windowStart!, to: now)
        } else if let block = logBlock(now: now) {
            m["h5Est"] = true  // the reset time is approximate; there is no percentage
            windowStart = block.start
            windowEnd = block.start.addingTimeInterval(5 * 3600)
            windowTokens = block.tokens
        }
        if let windowStart, let windowEnd {
            m["h5Reset"] = max(0, Int(windowEnd.timeIntervalSince(now) / 60))
            m["b5Tokens"] = windowTokens
            m["b5StartHour"] = Calendar.current.component(.hour, from: windowStart)
            m["b5Hours"] = (0..<5).map { i -> Int in
                let from = windowStart.addingTimeInterval(Double(i) * 3600)
                return tokens(from: from, to: min(from.addingTimeInterval(3600), now.addingTimeInterval(1)))
            }
        }

        // The recent 5-hour sessions with their tokens (the current one last): [[start seconds, tokens], …].
        var sessions = logBlocks().filter { windowStart == nil || $0.start.addingTimeInterval(5 * 3600) <= windowStart!.addingTimeInterval(60) }
        if let windowStart { sessions.append((windowStart, windowTokens)) }
        if !sessions.isEmpty {
            m["b5Sessions"] = sessions.suffix(6).map { [Int($0.start.timeIntervalSince1970), $0.tokens] }
        }

        if let w = week, w.resetsAt > nowSec {
            m["wk"] = dec(w.pct)
            m["readAge"] = max(0, Int(now.timeIntervalSince(statusAt) / 60))
            let f = DateFormatter()
            f.dateFormat = "EEE"
            let resetDate = Date(timeIntervalSince1970: w.resetsAt)
            m["wkReset"] = f.string(from: resetDate)
            let c = Calendar.current.dateComponents([.hour, .minute], from: resetDate)
            m["wkResetTime"] = (c.hour ?? 0) * 60 + (c.minute ?? 0)  // minutes after midnight, computer's time
        }
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
            replies[id] = (Calendar.current.startOfDay(for: date), date, Self.modelName(message["model"] as? String), tokens)
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
