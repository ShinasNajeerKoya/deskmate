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
    /// Artwork for the current song and the queue (downloaded by the Mac).
    let art = ArtCache()

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
            DispatchQueue.main.async { done(message.map(self.attachArt)) }
        }
    }

    /// Handles music.toggle / next / previous / like / shuffle / volume:<0..1>.
    func handle(_ command: String) {
        let js: String
        switch command {
        case "music.toggle": js = "document.querySelector('#play-pause-button')?.click()"
        case "music.next": js = "document.querySelector('.next-button')?.click()"
        case "music.previous":
            // YouTube Music's Previous button restarts the song when more than ~3 s in, so play
            // the previous queue entry directly; fall back to the button if the queue isn't loaded.
            js = "(()=>{const q=[...document.querySelectorAll('ytmusic-player-queue-item')].filter(x=>!x.closest('#counterpart-renderer'));"
                + "const c=q.findIndex(x=>x.hasAttribute('selected'));"
                + "if(c>0){const it=q[c-1]; (it.querySelector('ytmusic-play-button-renderer')||it).click(); return;}"
                + "const v=document.querySelector('video'); if(v&&v.currentTime>3){v.currentTime=0;}"
                + "setTimeout(()=>document.querySelector('.previous-button')?.click(),300);})()"
        case "music.like":
            js = "document.querySelector('ytmusic-player-bar ytmusic-like-button-renderer button[aria-label=\"Like\"]')?.click()"
        case "music.shuffle": js = "document.querySelector('ytmusic-player-bar .shuffle')?.click()"
        default:
            if command.hasPrefix("music.play:"), let index = Int(command.dropFirst("music.play:".count)) {
                // Plays a song from the queue (index among the real queue items, see readScript).
                js = "(()=>{const q=[...document.querySelectorAll('ytmusic-player-queue-item')].filter(x=>!x.closest('#counterpart-renderer'));"
                    + "const it=q[\(index)]; if(it){(it.querySelector('ytmusic-play-button-renderer')||it).click();}})()"
                break
            }
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
    /// The queue skips YouTube Music's hidden video copies (#counterpart-renderer), which
    /// otherwise show every song twice; it returns the 1 song before and 3 after the current one.
    private static let readScript = """
    (() => {
      const v = document.querySelector('video');
      const md = navigator.mediaSession && navigator.mediaSession.metadata;
      const bar = document.querySelector('ytmusic-player-bar');
      if (!md || !md.title) return '';
      const like = bar && bar.querySelector('ytmusic-like-button-renderer');
      const shuffle = bar && bar.querySelector('.shuffle');
      const art = (md.artwork || []).filter(a => a.src).sort((a, b) => parseInt(a.sizes) - parseInt(b.sizes));
      const pick = art.find(a => parseInt(a.sizes) >= 200) || art[art.length - 1];
      // The song's own time, as YouTube Music's player bar shows it. The <video> element can
      // report a different length (mixes, intros) or keep the last song's values for a moment.
      const pb = bar && bar.querySelector('#progress-bar');
      const barMax = pb ? parseFloat(pb.getAttribute('aria-valuemax')) : NaN, barVal = pb ? parseFloat(pb.getAttribute('aria-valuenow')) : NaN;
      const useBar = isFinite(barMax) && barMax > 0 && isFinite(barVal);
      const dur = useBar ? Math.floor(barMax) : (v && isFinite(v.duration) ? Math.floor(v.duration) : 0);
      const pos = useBar ? Math.min(Math.floor(barVal), dur) : (v ? Math.floor(v.currentTime) : 0);
      const items = [...document.querySelectorAll('ytmusic-player-queue-item')].filter(q => !q.closest('#counterpart-renderer'));
      const cur = items.findIndex(q => q.hasAttribute('selected'));
      const entry = (q, i) => {
        const img = q.querySelector('img');
        const src = img && img.src && !img.src.startsWith('data:') ? img.src : '';
        return [
          (q.querySelector('.song-title')?.textContent || '').trim().slice(0, 34),
          (q.querySelector('.byline')?.textContent || '').trim().split('•')[0].trim().slice(0, 26),
          i, src
        ];
      };
      const prev = cur > 0 ? items.slice(Math.max(0, cur - 1), cur).map((q, k) => entry(q, Math.max(0, cur - 1) + k)) : [];
      const next = cur >= 0 ? items.slice(cur + 1, cur + 4).map((q, k) => entry(q, cur + 1 + k)) : [];
      return JSON.stringify({
        title: md.title.slice(0, 48), artist: (md.artist || '').slice(0, 34), album: (md.album || '').slice(0, 34),
        playing: !!v && !v.paused, pos: pos, dur: dur,
        vol: v ? Math.round(v.volume * 100) / 100 : null,
        liked: !!like && like.getAttribute('like-status') === 'LIKE',
        shuffle: !!shuffle && (shuffle.getAttribute('aria-pressed') === 'true' || shuffle.classList.contains('active')),
        artUrl: pick ? pick.src : '',
        prev: prev, next: next,
        // Playing from "Liked music": every queued song is liked.
        allLiked: new URLSearchParams(location.search).get('list') === 'LM'
      });
    })()
    """

    /// Replaces artwork URLs with ids the phone can ask for (images are sent separately as "art").
    private func attachArt(_ message: [String: Any]) -> [String: Any] {
        var m = message
        if let url = m.removeValue(forKey: "artUrl") as? String, let id = art.id(for: url, size: 200) { m["art"] = id }
        for key in ["prev", "next"] {
            guard let rows = m[key] as? [[Any]] else { continue }
            m[key] = rows.map { row -> [Any] in
                var row = row
                if row.count > 3, let url = row[3] as? String { row[3] = art.id(for: url, size: 96) ?? "" }
                return row
            }
        }
        return m
    }
}
