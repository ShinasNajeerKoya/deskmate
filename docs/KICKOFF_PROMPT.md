# Deskmate — kickoff prompt

Paste everything below the line into Claude Code (in Cursor, opened in the `deskmate` folder) as your first message.

---

You're the lead engineer on **Deskmate**, my personal desk display. First read `CLAUDE.md` and `docs/PROJECT_CONTEXT.md`. Then follow this brief. Work milestone by milestone. At the end of each milestone, stop and show me what's done and how to verify it on the real phone.

## 1. The product in one paragraph

An old Android phone (Poco M2 Pro, Android 10–11, landscape only, **no SIM, no internet**) sits beside my office MacBook. It shows a live, always-on dashboard:
- the clock and Claude usage limits
- YouTube Music, with controls
- Mac system stats in an Activity Monitor style
- a Control Center for the Mac's Bluetooth (earphones) and Wi-Fi
- a focus timer, Slack counts, weather, shortcuts and GitHub, plus a calendar page later (not on Home)

The phone talks **only** to my Mac, over **Bluetooth Low Energy (BLE)**. My office IT won't let the phone join Wi-Fi, and I want no cables. When the Mac sleeps, the phone shows a dim night clock. When the Mac wakes, the board comes back.

## 2. Two apps, one repo

```
deskmate/
├── lib/                  Flutter phone app (this project, Android only)
├── android/
├── mac/DeskmateMac/      Swift + SwiftUI menu-bar app (to create): BLE peripheral, data collectors, command runner
├── docs/
│   ├── PROJECT_CONTEXT.md   all product decisions (already written)
│   ├── KICKOFF_PROMPT.md    this file
│   ├── PROTOCOL.md          BLE protocol: single source of truth (you create it in M1)
│   └── PHONE_SETUP.md       MIUI and kiosk setup checklist (you create it in M6)
└── CLAUDE.md
```

Delete the `linux/`, `macos/`, `web/` and `windows/` folders from the Flutter project. The phone app is Android only, and the Mac app is native Swift in `mac/`. Keep `ios/` only for testing the UI in the iOS Simulator (demo mode).
On Home there are **no calendar tile and no quick-shortcut buttons**, and Layout A has **no Slack tile**: their slots hold the Bluetooth tile and (Layout A) one wide 2 × 2 Timer tile. The focus timer defaults to 10 minutes.

## 3. Non-negotiable constraints

- **Android only, landscape only.** Design for **915 × 412 dp**. Handle the punch-hole display cutout.
- **No network calls from the phone.**
  - Fonts must be **bundled as assets**. Don't use the `google_fonts` runtime fetching.
  - Weather, time sync and everything else come from the Mac.
- **Bluetooth traffic:** Mac Bluetooth also drives my earphones, so keep BLE traffic light. Batch updates, send at most every 1–2 s for live stats, and keep album art to small JPEG thumbnails (about 96–128 px).
- **Slack privacy:** counts only, never message text.
- **No "updated X minutes ago" labels anywhere.**
- **Flutter 3.29.1 / Dart 3.7.** Use `flutter_blue_plus` **pinned to 1.36.8**. Don't upgrade it without asking (see PROJECT_CONTEXT for why).
- **Mac app:**
  - native Swift, macOS 13+
  - `MenuBarExtra` UI
  - launch at login via `SMAppService`
  - no third-party dependencies unless I approve them

## 4. Architecture: build it future-proof from day one

### Phone (Flutter)

- **State:** Riverpod (`flutter_riverpod`). **Persistence:** `shared_preferences`, behind a small `SettingsRepository` with a **schema version and migrations**.
- **Transport abstraction:**
  - `abstract class DeskTransport { Stream<Envelope> messages; Future<void> send(Command); Stream<LinkState> state; }`
  - `BleTransport` is the real implementation.
  - `FakeTransport` replays realistic fake data, so the whole UI can be built and tested **without the Mac**.
  - A Wi-Fi or USB transport could be added later without touching the UI.
- **Feature registry:** every page is a `FeatureDescriptor`:
  - `id`, `label`, `icon`
  - `pageBuilder`
  - `tileBuilders` keyed by tile size: 1×1, 1×2, 2×1, 2×2, 3×2, 3×4…
  - `requiredTopics`

  The sidebar, Settings and Home all read from this registry. Adding a feature means adding one folder and one registry entry.
- **Home layouts are data, not widgets.** Each layout is a 6-column × 4-row grid spec (JSON-serialisable): `{tileId, col, row, w, h}`.
  - Layouts A and B come from the designs; C will come later.
  - Long-press edit mode swaps tiles and saves the spec.
  - Rotation: every 10 min across the layouts the user picked in Settings. Picking exactly one locks it.
- **Theming:**
  - A `DeskTheme extends ThemeExtension` holds every colour, font family and radius, plus the semantic tile colours (claude, music, bluetooth, slack, system…).
  - Widgets **never** hard-code colours or fonts.
  - Ship **Color Blocks** fully. Create the other three (**Graphite, Paper, Paper Blocks**) as token stubs, so the Settings theme picker already lists all four.
- **Folder layout:**
  - `lib/app/` — app root, routing, shell with the sidebar
  - `lib/core/` — theme, shared widgets (flip clock, tile, banner, skeleton), utils, logging
  - `lib/data/` — transport, protocol models, settings repository
  - `lib/features/<id>/` — one folder per feature: `page.dart`, `tiles.dart`, `providers.dart`
  - Feature ids: `home`, `claude`, `music`, `system`, `control`, `timer`, `calendar`, `slack`, `weather`, `shortcuts`, `github`, `settings`, `night_clock`
  - Home has **no calendar tile**; its slot is the Bluetooth tile, which opens `control`.
- **Diagnostics:** an in-app log ring buffer, plus Settings → Diagnostics showing link state, RSSI, MTU, protocol version, the last messages and app version. This is essential for debugging on a phone with no cable attached.
- **Strings** live in one place, so they're l10n-ready even though English is the only language for now.

### Mac (Swift)

- `BLE/PeripheralService.swift`: CoreBluetooth `CBPeripheralManager` with one custom service.
- `Collectors/`, one class each, all behind a `Collector` protocol with its own interval:
  - `SystemCollector`: CPU, memory and pressure, energy, disk I/O, network, top processes
  - `ClaudeCollector`: the logs, plus status-line and hook files
  - `MusicCollector`: the YouTube Music desktop app API
  - `BluetoothCollector`: IOBluetooth: the connected device, paired devices and scan results (never powers Bluetooth off)
  - `WiFiCollector`: CoreWLAN: on/off and network name (the name needs Location permission on macOS 14+)
  - `CalendarCollector`: EventKit (later; Calendar isn't needed soon)
  - `SlackCollector`: dock badge
  - `WeatherCollector`: Open-Meteo, using a city from Settings
- `Commands/`: media keys, shortcuts (open app or URL, run script) and lock screen. Only **allow-listed** commands; never run arbitrary strings sent from the phone.
- `Power/SleepWakeMonitor.swift`: `NSWorkspace` sleep, wake, screen-lock and unlock notifications, which drive the phone's night clock.
- `Claude/`:
  - an installer for the Claude Code **status line script**, which writes the latest limits JSON to `~/Library/Application Support/Deskmate/claude-status.json`
  - **hooks** that write session state ("waiting for input") to `~/Library/Application Support/Deskmate/sessions/`
  - Never read credentials, and never call undocumented endpoints.
- The menu bar shows connection status, the paired phone, a pause toggle and Quit.

### BLE protocol (write it up in `docs/PROTOCOL.md`)

- **Service:** one custom 128-bit service. **Characteristics:**
  - `hello` (read): protocol version and capabilities
  - `stream` (notify): Mac → phone messages
  - `command` (write with response): phone → Mac
  - `art` (notify): album-art chunks
- **Security:**
  - Characteristics require **encryption**, so the phone and Mac pair or bond once.
  - The Mac only serves the bonded phone.
- **Envelope:** `{ "v": 1, "t": "<topic>", "id": <seq>, "ts": <unix ms>, "d": { … } }`.
  - Encoding: compact JSON for v1, with the option to switch to CBOR later behind the version number.
- **Framing:** messages larger than MTU−3 are chunked as `[msgId, chunkIndex, chunkCount, payload]`. Request MTU 247 or more on Android.
- **Topics and rates:**

| Topic | When it's sent |
|---|---|
| `time` | on connect, then hourly |
| `power` | on sleep, wake, lock or unlock |
| `system` | every 2 s |
| `claude` | every 30 s, plus at once when a session starts waiting |
| `music` | on change; the phone animates progress locally between updates |
| `bluetooth`, `wifi` | on change, and while scanning at most every 2 s |
| `calendar`, `slack`, `weather` | on change, at most once a minute |
| `art` | on track change |

- **Commands:** `media.playPause`, `media.next`, `media.prev`, `media.like`, `media.volume{0-100}`, `shortcut.run{id}`, `mac.lock`, `bt.connect{id}`, `bt.disconnect{id}`, `bt.scan{on}`, `bt.pair{id}`, `wifi.power{on}`, `timer.*` (the timer itself runs on the phone). There's deliberately no command to power the Mac's Bluetooth off.
- **Compatibility:** both sides must ignore unknown topics and fields. Bump `v` only for breaking changes, and handle older versions gracefully.

## 5. Behaviour to implement

| Situation | What the phone shows |
|---|---|
| App opens, Mac not found yet | **Connecting**: Home shows skeleton tiles plus an **orange** banner "Looking for your Mac…" (Home only) |
| BLE dropped while the Mac is awake | **Reconnecting**: tiles keep the last data, plus a **blue** banner (Home only). Show the night clock if it isn't back within about 30 s |
| Phone Bluetooth off | A **red** banner with a button to turn Bluetooth on (Home only) |
| Mac sleeps, locks or shuts down | **Night clock**: black, a large dim flip clock, minimum brightness via `screen_brightness`, no sidebar. Tapping it peeks at the board for 10 s |
| Mac wakes or unlocks | Board at normal brightness, on the Home layout |
| Battery above 70% and charging / below 30% and not charging | A battery banner on **every** page ("unplug" / "plug in"). The limits can be changed in Settings |

Always on: keep the screen awake with `wakelock_plus`, use immersive sticky mode, and use screen pinning or lock-task mode.

## 6. Milestones (stop after each one)

- **M0 — Clean setup**
  - Remove the non-Android platforms (keep `ios/` for Simulator testing), set the app id, force landscape, enable immersive mode and handle cutouts.
  - Bundle the DM Sans and Bricolage Grotesque fonts.
  - Add `DeskTheme` with Color Blocks plus 3 stub themes, `FakeTransport`, the folder structure and an empty feature registry.
  - **Done when** the app runs on the Poco showing an empty themed shell.
- **M1 — BLE link spike (the riskiest part)**
  - Create `mac/DeskmateMac` (menu-bar app, peripheral, `hello` + `stream` + `command` characteristics, bonding) and write `docs/PROTOCOL.md`.
  - The Mac sends `system.cpu` every 2 s; the phone shows the number live.
  - The phone sends `media.playPause`; the Mac presses the media key.
  - The Mac sends `power.sleep` / `power.wake`.
  - **Done when** it works on my **office Mac**, survives the phone screen turning off, recovers from Bluetooth toggling, reconnects after the Mac sleeps, and the earphones still play smoothly.
- **M2 — Shell and Home**
  - Registry-driven sidebar: scrollable, Settings pinned at the bottom, editable order and visibility.
  - The Home 6×4 grid engine, layouts A and B from the designs, and all Home tiles on FakeTransport.
  - Tile tap opens the page, long-press edit mode swaps tiles, and layouts rotate every 10 min with Settings lock/rotate.
- **M3 — States**
  - Connecting skeleton, reconnecting, Bluetooth off, battery banners, and the night clock with peek and brightness control.
- **M4 — Designed pages**
  - **Claude, Music, System, Control Center, Timer, Settings** (with the theme picker, layout lock, battery limits, Slack privacy, night clock toggle, time format and diagnostics), matching the designs.
  - Then the real Mac collectors for each, replacing fake data topic by topic.
- **M5 — Remaining features**, once they're designed: Slack, Weather, Shortcuts, GitHub and Home layout C; Calendar last (not needed soon).
- **M6 — Hardening**
  - A foreground service (`connectedDevice` type) to keep BLE alive, and autostart on boot.
  - `docs/PHONE_SETUP.md` (MIUI autostart, battery "no restrictions", lock in recents, developer options, no lock-screen PIN).
  - A 24-hour soak test, and a simple APK install flow (`adb install` or sideload).
- **Phase 2:** the other 3 themes, Home tile resize, full Slack integration.

## 7. Designs

The source of truth for every layout is https://claude.ai/artifact/A4YezfL5M982Eo9coC9Gs7: the "Pages · Color Blocks theme" row, plus the Home and Night clock boards in the Color Blocks row.
- If you can't open it, ask me for screenshots. **Don't invent layouts.**
- Match spacing, tile sizes and hierarchy, but build them from theme tokens.

## 8. Quality bar

- Unit tests for protocol parsing and chunking, layout specs, settings migrations, and rotation and lock logic.
- Golden tests at 915 × 412 for Home layout A, Home layout B, the night clock and every page, all on FakeTransport.
- `flutter analyze` clean, and no `print` (use the logger).
- Small commits per step, with clear messages. Don't commit secrets.

## 9. How to work with me

- Before each milestone, give a short plan. After each one, list what changed, how to test it on the phone and what's still open.
- Ask before:
  - adding any dependency
  - changing the protocol after M1
  - changing a locked design decision
- If something in this brief turns out to be impossible (macOS permissions, MIUI limits, Bluetooth quirks), say so plainly and propose the closest alternative.
- Open questions to confirm with me when you reach them:
  1. Do I play YouTube Music in the desktop app or in a browser?
  2. Which city should weather use?
  3. Which shortcuts should the 4 shortcut buttons run?
  4. Can I grant Bluetooth, Accessibility, Automation, Calendar and Location (Wi-Fi network name) permissions on the office Mac?

Start with **M0**.
