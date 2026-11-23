import Foundation

/// YouTube Music playing in a Google Chrome tab (music.youtube.com).
///
/// Reads the track through Chrome's AppleScript support, which runs a small
/// script inside the YouTube Music tab. This needs, once:
///  - Chrome: View → Developer → Allow JavaScript from Apple Events
///  - macOS: allow Deskmate Hub to control Google Chrome (asked automatically)
/// Without them, the phone's music tile just stays empty.
final class MusicCollector {
    /// Why music isn't available (shown in the Hub menu), or nil when it works.
    private(set) var problem: String?

    private let queue = DispatchQueue(label: "deskmate.music")

    /// Reads the current track (off the main thread) and calls back on the main thread.
    func read(_ done: @escaping ([String: Any]?) -> Void) {
        queue.async {
            let result = self.runInTab(Self.readScript)
            var message: [String: Any]?
            if let json = result, let data = json.data(using: .utf8),
               var m = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                m["t"] = "music"
                if let vol = (m["vol"] as? NSNumber)?.doubleValue { m["vol"] = dec(vol, 2) }
                message = m
            }
            DispatchQueue.main.async { done(message) }
        }
    }

    /// Handles music.toggle / next / previous / like / shuffle / volume:<0..1>.
    func handle(_ command: String) {
        let js: String
        switch command {
        case "music.toggle": js = "document.querySelector('#play-pause-button')?.click()"
        case "music.next": js = "document.querySelector('.next-button')?.click()"
        case "music.previous": js = "document.querySelector('.previous-button')?.click()"
        case "music.like": js = "document.querySelector('ytmusic-player-bar #button-shape-like button, ytmusic-player-bar .like')?.click()"
        case "music.shuffle": js = "document.querySelector('ytmusic-player-bar .shuffle')?.click()"
        default:
            guard command.hasPrefix("music.volume:"), let v = Double(command.dropFirst("music.volume:".count)) else { return }
            js = "(()=>{const v=document.querySelector('video'); if(v) v.volume=\(min(max(v, 0), 1));})()"
        }
        queue.async { _ = self.runInTab(js) }
    }

    /// Runs JavaScript in the first music.youtube.com tab and returns its string result.
    private func runInTab(_ javascript: String) -> String? {
        let escaped = javascript.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        if application "Google Chrome" is not running then return "__NOT_RUNNING__"
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "music.youtube.com" then
                        return (execute t javascript "\(escaped)") as text
                    end if
                end repeat
            end repeat
        end tell
        return "__NO_TAB__"
        """
        var error: NSDictionary?
        let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
            problem = message.contains("JavaScript")
                ? "In Chrome, turn on View → Developer → Allow JavaScript from Apple Events"
                : (message.contains("Not authorized") || message.contains("-1743")
                    ? "Allow Deskmate Hub to control Google Chrome (System Settings → Privacy & Security → Automation)"
                    : message)
            return nil
        }
        switch output {
        case "__NOT_RUNNING__"?, "__NO_TAB__"?:
            problem = nil  // nothing playing isn't a problem
            return nil
        default:
            problem = nil
            return output
        }
    }

    /// Reads the player state from the YouTube Music page and returns it as JSON text.
    private static let readScript = """
    (() => {
      const v = document.querySelector('video');
      const md = navigator.mediaSession && navigator.mediaSession.metadata;
      const bar = document.querySelector('ytmusic-player-bar');
      if (!md || !md.title) return '';
      const like = bar && bar.querySelector('#button-shape-like button, .like');
      const shuffle = bar && bar.querySelector('.shuffle');
      const queue = [...document.querySelectorAll('ytmusic-player-queue-item')];
      const cur = queue.findIndex(q => q.hasAttribute('selected') || q.getAttribute('play-button-state') === 'playing' || q.getAttribute('play-button-state') === 'paused');
      const next = (cur >= 0 ? queue.slice(cur + 1) : queue).slice(0, 4).map(q => [
        (q.querySelector('.song-title')?.textContent || '').trim().slice(0, 30),
        (q.querySelector('.byline')?.textContent || '').trim().split('•')[0].trim().slice(0, 24)
      ]).filter(q => q[0]);
      return JSON.stringify({
        title: md.title.slice(0, 40), artist: (md.artist || '').slice(0, 30), album: (md.album || '').slice(0, 30),
        playing: !!v && !v.paused, pos: v ? Math.floor(v.currentTime) : 0, dur: v && isFinite(v.duration) ? Math.floor(v.duration) : 0,
        vol: v ? Math.round(v.volume * 100) / 100 : null,
        liked: !!like && like.getAttribute('aria-pressed') === 'true',
        shuffle: !!shuffle && (shuffle.getAttribute('aria-pressed') === 'true' || shuffle.classList.contains('active')),
        queue: next
      });
    })()
    """
}
