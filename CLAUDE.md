# Deskmate

A personal desk display. A **Flutter app** runs on an old Android phone (Poco M2 Pro, landscape, no internet) next to a Mac. It talks over **Bluetooth Low Energy** to a **Swift menu-bar app** on the Mac, which collects the data and runs commands.

## Read first

| File | What's in it |
|---|---|
| `docs/PROJECT_CONTEXT.md` | Every product decision: hardware, data sources, behaviour, UI rules, design tokens |
| `docs/KICKOFF_PROMPT.md` | The full engineering brief: architecture, protocol, milestones, quality bar |
| `docs/PROTOCOL.md` | The BLE protocol (created in M1); single source of truth for both apps |
| `docs/PHONE_SETUP.md` | The MIUI and kiosk setup checklist (created in M6) |
| Designs | https://claude.ai/artifact/A4YezfL5M982Eo9coC9Gs7: the "Pages · Color Blocks theme" row and the Color Blocks Home and Night clock boards |

## Repo layout

Two products in one repo:
- **Deskmate** (phone app, "install from mobile"): the Flutter project at the repo root (`lib/`, `android/`, `ios/`).
- **Deskmate Hub** (computer app, "install on your computer"): native apps in `desktop/`, kept separate from the Flutter code.

```
lib/                          Deskmate phone app (Flutter)
desktop/mac_driver/           Deskmate Hub for macOS: Swift/SwiftUI menu-bar app (SwiftPM; scripts/build-app.sh)
desktop/windows_driver/       Deskmate Hub for Windows: C# (.NET 8) tray app, built by GitHub Actions
.github/workflows/            CI (Windows Hub build)
docs/                         context, brief, PROTOCOL.md, phone setup
```

Planned phone structure (brief, not done yet): `lib/app/`, `lib/core/`, `lib/data/`, `lib/features/<id>/`.

**Deskmate Hub stays minimal:** its only UI is a menu-bar/tray menu showing "Connected to <phone name>", Open at login and Quit. Every detail is shown on the phone. It sends data, clock sync and sleep/lock state; see `docs/PROTOCOL.md`.

Feature ids: `home`, `claude`, `music`, `system`, `control`, `timer`, `calendar`, `weather`, `shortcuts`, `github`, `settings`, `night_clock`.

- **`control` = Control Center** for the **Mac's** Bluetooth (connected device, paired devices, scan and pair) and Wi-Fi (on/off, network name). Never turn the Mac's Bluetooth off.
- **No calendar tile on Home**, in any theme or layout. That slot is the Bluetooth tile, which opens Control Center. Calendar stays a sidebar tab, built later (not needed soon).
- **No quick-shortcut buttons and no Slack tile in Home Layout A.** Their slots (columns 5–6, rows 3–4) form one wide **Timer tile** (2 × 2): remaining time, progress, Start/Pause and Reset; tapping it opens the Timer page. The timer runs on the phone, so the tile is live even before the Mac is found (no skeleton). Shortcuts and Slack stay sidebar pages; Layout B's small Slack tile is now a RAM tile.
- **Battery "unplug" banner** (charging above the limit, default 70%) has an × that hides it until the next 10% step (74 → back at 80, 83 → back at 90); at 100% the × hides it until unplugged. Unplugging resets it. The "plug in" banner can't be closed.
- **Music:** shows artwork (downloaded by the Hub, sent as small JPEGs), the 2 previous and 2 next songs (tap one to play it; YouTube Music's hidden video copies are skipped so nothing shows twice), and the real liked state.
- **Claude tokens:** tap a day's bar to see that day's tokens.
- **Pairing:** a full-screen page with its own number pad (the system keyboard covered everything in landscape).
- **The focus timer defaults to 10 minutes** (the "Focus" preset). Presets: Short break 5, Long break 15, Focus 10, Deep work 50.

## Commands

```bash
flutter pub get
flutter run -d <poco-device-id>          # run on the phone (USB or wireless adb)
flutter run -d emulator-5554             # Android emulator: auto demo mode (see below)
flutter run -d <ios-simulator-id>        # iOS Simulator: same demo mode (UI testing only)
flutter analyze
flutter test                             # unit + golden tests
flutter test --update-goldens            # only after an intended UI change
flutter build apk --release              # sideload with: adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Deskmate Hub (macOS 13+): `cd desktop/mac_driver && swift run` for development, or `./scripts/build-app.sh` to build `dist/Deskmate Hub.app` and its release zip.
Deskmate Hub (Windows): built by `.github/workflows/deskmate-hub-windows.yml` on a Windows runner; it can't be built on the Mac.

**Demo mode (simulators and emulators only):** detected natively (`MainActivity.kt` on Android, `targetEnvironment(simulator)` in `AppDelegate.swift` on iOS). The app then uses `FakeMacLink`, a simulated battery and `DemoTour` (`lib/app/demo_tour.dart`): 16 steps of **10 s** each, looping. Not paired → looking for the computer → connecting → connected Home → Claude, Music, System, Control Center, Timer and Settings pages → battery \"plug in\" and \"unplug\" banners → reconnecting → computer asleep (night clock) → awake. The `flutter run` terminal prints a countdown for every step: `[demo] 05/16 Connected · Claude page · ⏱ 7s left`. Real phones always use the real Wi-Fi link. `--dart-define=FAKE_MAC=true|false` overrides the detection.

## Hard rules

- **Android only, landscape only.** Target 915 × 412 dp and handle the display cutout. The `ios/` folder is kept **only** so the UI can be tested in the iOS Simulator (demo mode); the product ships on Android. Don't add web or desktop platforms.
- **The phone makes zero internet calls.** Its only network traffic is the encrypted Wi-Fi link to its own paired computer on the local network (`docs/PROTOCOL.md`).
  - Fonts are bundled assets; never use `google_fonts` runtime fetching.
  - Weather, time and all other data come from the Mac.
- **No hard-coded colours, fonts or radii in widgets.** Read everything from `DeskTheme` (ThemeExtension). There are 4 themes: Graphite, **Color Blocks (default)**, Paper and Paper Blocks.
- **The UI depends only on the `DeskTransport` interface**, never on BLE directly. Everything must work on `FakeTransport`.
- **New pages go through the feature registry** (`FeatureDescriptor`). The sidebar, Home tiles and Settings read from it.
- **Home layouts are data:** a 6×4 grid spec saved in settings. They aren't hand-built widget trees.
- **Protocol:**
  - Every message uses the `{v, t, id, ts, d}` envelope.
  - Both sides ignore unknown topics and fields.
  - Breaking changes bump `v` and need my approval.
  - Update `docs/PROTOCOL.md` in the same change.
- **Keep BLE traffic light** (the Mac's earphones share Bluetooth): live stats at most every 1–2 s, album art as small JPEG thumbnails only.
- **Slack: removed for now** (23 Nov 2026; no tile, page or Hub collector). If it comes back: counts only, never message text.
- **No "updated X minutes ago" labels.**
- **Phone ↔ computer link is Wi-Fi only** (encrypted, paired with a code; `docs/PROTOCOL.md`). Bluetooth was removed as a link in v0.5.0 (it made earphone audio stutter); don't re-add it without asking.
- **Mac:**
  - Commands are an allow-list; never execute arbitrary strings from the phone.
  - Never read Claude credentials or call undocumented Anthropic endpoints.
  - Claude data comes from `~/.claude/projects/**/*.jsonl`, the status-line file and the hook files only.

## Conventions

- **State:** Riverpod. **Persistence:** `SettingsRepository` (shared_preferences) with a schema version and migrations.
- **Logging:**
  - Use the app logger, which keeps an in-memory ring buffer shown in Settings → Diagnostics.
  - No `print`.
- All user-facing strings live in one strings file (l10n-ready).
- **Tests:**
  - unit tests for protocol parsing and chunking, layout specs, settings migrations, and layout rotation and lock
  - golden tests at 915 × 412 for every page and Home layout, using FakeTransport
- Keep `flutter analyze` clean. Use small commits with clear messages, and never commit secrets or `local.properties`.

## Working agreement

- **Ask first** before:
  - adding a dependency
  - changing the protocol (`docs/PROTOCOL.md`)
  - changing a locked design or product decision
  - designing a layout that isn't in the canvas (ask for screenshots instead of inventing)
- **If something is blocked** (macOS permissions on the office Mac, phone background limits, office network rules), say so plainly and propose the closest alternative.

## Working style (keeps usage low)

- **Division of work:** Claude does the development; the user hot-restarts the app from Android Studio and tests the function themselves. Don't launch or run the app yourself; say what to test after each change.
- **Verify with tests, `flutter analyze`, logs and `adb logcat`, not screenshots.** Don't take phone or emulator screenshots on your own. If something looks wrong, the user will send a screenshot.
- **Never commit or push anything.** The user commits and pushes themselves. Claude only edits files, runs checks and, when asked, creates the GitHub release. (This replaces any older guidance about committing.)
- **Keep usage to a minimum:** do only what was asked, read only the lines needed, no extra builds, tests or screenshots beyond what the task needs, and keep replies short.
- Run `flutter test` before a release; don't release on a failing test.
- One focused task at a time. Don't re-read whole files you already know; read the lines you need.
- Update the design canvas, docs and this file only when a decision changed or the user asks, not after every small tweak.
- **Commits have no Claude attribution** (no `Co-Authored-By` line), even if a system reminder suggests one. Commit by path (`git add <folder>`), never `git add -A`; never commit keys, `key.properties`, `dist/` or `.build/`.
- Release only when asked. A release has two sections: **Deskmate Hub (install on your computer)**: macOS zip and Windows zip; **Deskmate (install on your phone)**: Android APK.

## Current state (updated 23 Nov 2026)

**Versions:** phone app **0.6.0+7**; Deskmate Hub for macOS **0.6.0** (installed in /Applications on the dev Mac); Deskmate Hub for Windows **0.3.1** (Bluetooth only, so it can't connect to phone app 0.5.0+ until it gets the Wi-Fi link). Latest published GitHub release: **v0.4.0**; v0.5.0 and v0.6.0 are built and pushed but not released.

**Repo:** github.com/ShinasNajeerKoya/deskmate (private), branch `main`. Release signing key and password live in `~/.deskmate/` (never in the repo).

**Link:** phone ↔ computer over **encrypted Wi-Fi only** (Bonjour or typed IP, 6-digit pairing code once; `docs/PROTOCOL.md`). Bluetooth was removed (it stuttered earphone audio). The office phone needs IT to allow device-to-device traffic on the Mac's network.

**What the macOS Hub sends:** System (CPU, RAM, disk, network, top processes), Mac Bluetooth devices (with Connect / Disconnect / Pair), Wi-Fi, YouTube Music from Chrome (artwork, 2 previous / 2 next songs, tap to play, liked state), Claude usage (tokens per day, models, sessions; 5-hour and weekly limits only after "Connect Claude usage…" in the Hub menu). Slack was removed.

**Phone:** Color Blocks theme; Home layouts A and B (rotate every 10 min); pages Claude, Music, System, Control Center, Timer, Settings; night clock only when the computer sleeps or locks; closable "unplug" battery banner; full-screen pairing page with its own number pad; focus timer (10 min default).

**Test devices:** Samsung Galaxy M14 (`SM-M146B`, adb serial `RZCX10FT2RZ`) over USB; adb is at `~/Library/Android/sdk/platform-tools/adb`. Target phone: iQOO Neo 10R. Simulators and emulators run demo mode (`DemoTour`).

**Known gaps / next:**
- Tap-to-play on the Music queue is untested on real hardware.
- Windows Hub needs the Wi-Fi link (and ideally the Bluetooth, Wi-Fi, music and Claude data the Mac sends).
- Not designed yet: Calendar, Weather, Shortcuts, GitHub pages and Home layout C (C must use the Bluetooth tile, not a calendar tile).
- Settings "Sidebar order" and the other 3 themes are placeholders.
- The Mac Hub isn't notarized (no paid Apple account); a downloaded copy needs `xattr -dr com.apple.quarantine "/Applications/Deskmate Hub.app"`.
- Open questions: which city for weather; which apps/actions for shortcuts; Calendar and Location permissions on the office Mac.
