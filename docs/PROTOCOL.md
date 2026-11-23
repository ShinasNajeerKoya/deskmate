# Deskmate protocol (current, v0): Wi-Fi and Bluetooth LE

The same JSON messages travel over two links: **Wi-Fi** (preferred, encrypted TCP) and **Bluetooth LE** (backup). Deskmate Hub (computer) is the server/BLE peripheral; the Deskmate phone app is the client/BLE central.
Implementations: `lib/ble/` (phone), `desktop/mac_driver/Sources/DeskmateHub/` (macOS), `desktop/windows_driver/DeskmateHub/` (Windows).

## Service and characteristics

| Name | UUID | Properties | Direction |
|---|---|---|---|
| Service | `CC8A9226-538A-41AA-B390-85DB92127C62` | advertised | — |
| stats | `46ABD5B3-C525-463B-9E0A-5EB81163CCBB` | read, notify | Hub → phone |
| command | `58DB6A63-A4AB-4A47-A369-966CAF61956F` | write, write without response | phone → Hub |

The phone requests MTU 512 on Android; every message is one UTF-8 JSON object with a topic `"t"`.
Unknown topics and fields must be ignored on both sides.

**Parts:** a message longer than the connection allows (`maximumUpdateValueLength` on macOS, `MaxNotificationSize` on Windows) is base64-encoded and sent as `{"t":"part","id":<n>,"i":<index>,"n":<count>,"d":"<base64 slice>"}`; the phone joins the slices and parses the result as a normal message.

## Hub → phone (stats)

| `t` | Fields | When |
|---|---|---|
| `sys` | `seq`, `cpu`, `mem` (%), `memUsed`/`memTotal` (GB), `cores`, `energy`, `onPower`, `disk` (MB/s, macOS), `diskFree` (GB), `down`/`up` (KB/s), `procs` ([[name, %CPU] × 5]) | every 1 s |
| `time` | `ts` (Unix ms), `tz` (UTC offset, minutes) | on connect, then hourly (clock sync) |
| `power` | `asleep` (bool): sleep/lock = true, wake/unlock = false | on connect and on change |
| `bluetooth` | `scanning`, `devices` [{`id`, `name`, `kind`, `connected`, `paired`}] | on change (checked every 3 s) — macOS |
| `wifi` | `on`, `ssid` (needs Location permission) | on change (checked every 5 s) — macOS |
| `music` | `title`, `artist`, `album`, `playing`, `pos`, `dur`, `vol`, `liked`, `shuffle`, `queue` [[title, artist]]; empty when nothing plays | on change (checked every 2 s) — macOS, YouTube Music in Chrome |
| `claude` | `tokens7d`, `models` {name: share}, `sessions`, `waiting`; `h5`, `h5Reset` (min), `wk`, `wkReset` (weekday) once the status line is connected | on change (checked every 30 s) — macOS |
| `slack` | `unread` (Dock badge; never message text) | on change (checked every 10 s) — macOS |
| `event` | `title`, `start` | planned (Calendar) |

## Phone → Hub (command)

| `t` | Fields | When |
|---|---|---|
| `hello` | `name` (the phone's Bluetooth name) | right after subscribing; the Hub shows "Connected to <name>" |
| `cmd` | `c`: `music.toggle`, `music.next`, `music.previous`, `music.like`, `music.shuffle`, `music.volume:<0–1>`, `bt.scan`, `bt.connect:<id>`, `bt.disconnect:<id>`, `bt.pair:<id>`, `wifi.power:on|off` | on user action (macOS Hub handles them; Windows ignores them for now) |

The kickoff brief's target envelope (`{v, t, id, ts, d}`, chunking, bonding) replaces this when the protocol is formalised; bump `v` then.

## Wi-Fi link (v0.4.0+, macOS Hub)

- **Discovery:** Bonjour service `_deskmate._tcp`, port **47820**; or the computer's IP typed on the phone (shown in the Hub menu while pairing).
- **Framing:** 4-byte big-endian length, then the payload. Handshake frames are plain JSON; everything after is AES-256-GCM (`nonce(12) || ciphertext || tag(16)`), each payload one JSON message (no `part` splitting needed).
- **Pairing (once):** the Hub menu's "Pair a phone over Wi-Fi…" opens a 6-digit code for 2 minutes, **one attempt**.
  1. phone → `{"t":"hello","v":1,"mode":"pair","id","name","nonce":b64(16)}`
  2. Hub → `{"t":"challenge","nonce":b64(16)}` (or `{"t":"error","reason":"not-pairing"}`)
  3. both: `temp = PBKDF2-HMAC-SHA256(code, phoneNonce‖hubNonce, 100 000, 32)`; phone → `{"t":"proof","mac":b64(HMAC(temp,"deskmate-pair-phone"))}`
  4. Hub checks the proof (wrong → `wrong-code`, code burned), then → `{"t":"key","box":b64(AES-GCM_temp(K)),"hub":<name>}` with a random 256-bit long-term key K, and closes. The phone stores K; the Hub stores it in `~/Library/Application Support/Deskmate/paired-phones.json` (mode 600).
- **Session (every connection):** hello with `"mode":"resume"` → challenge → `session = HMAC(K, phoneNonce‖hubNonce)`; phone proves with `HMAC(session,"deskmate-phone")`; Hub replies encrypted `{"t":"ready"}`, then streams messages. Phone commands are encrypted `{"t":"cmd","c":…}`.
- **Policy:** while a phone is on Wi-Fi the Hub stops Bluetooth advertising and the phone drops its Bluetooth connection; if Wi-Fi drops, the phone goes back to Bluetooth and retries Wi-Fi every 15 s.
- Note: someone who records the one pairing exchange could brute-force the 6-digit code offline; pair on a network you trust, and re-pair if in doubt.
