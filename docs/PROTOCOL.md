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

## Hub → phone (stats)

| `t` | Fields | When |
|---|---|---|
| `sys` | `seq`, `cpu` (0–100); later `mem`, `memUsed`, `memTotal`, `cores`, `energy`, `onPower`, `disk`, `diskFree`, `down`, `up`, `procs` | every 1 s |
| `time` | `ts` (Unix ms), `tz` (UTC offset, minutes) | on connect, then hourly (clock sync) |
| `power` | `asleep` (bool): sleep/lock = true, wake/unlock = false | on connect and on change |
| `claude`, `music`, `slack`, `event`, `bluetooth`, `wifi` | see `lib/data/models.dart` | planned (demo mode sends them) |

## Phone → Hub (command)

| `t` | Fields | When |
|---|---|---|
| `hello` | `name` (the phone's Bluetooth name) | right after subscribing; the Hub shows "Connected to <name>" |
| `cmd` | `c`: command string, e.g. `music.toggle`, `bt.connect:<id>`, `wifi.power:on` | on user action (Hub handling planned) |

The kickoff brief's target envelope (`{v, t, id, ts, d}`, chunking, bonding) replaces this when the protocol is formalised; bump `v` then.
