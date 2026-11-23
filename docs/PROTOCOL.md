# Deskmate BLE protocol (current, v0)

Deskmate Hub (computer) is the BLE **peripheral**; the Deskmate phone app is the **central**.
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
