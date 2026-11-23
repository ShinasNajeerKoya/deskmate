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

Feature ids: `home`, `claude`, `music`, `system`, `control`, `timer`, `calendar`, `slack`, `weather`, `shortcuts`, `github`, `settings`, `night_clock`.

- **`control` = Control Center** for the **Mac's** Bluetooth (connected device, paired devices, scan and pair) and Wi-Fi (on/off, network name). Never turn the Mac's Bluetooth off.
- **No calendar tile on Home**, in any theme or layout. That slot is the Bluetooth tile, which opens Control Center. Calendar stays a sidebar tab, built later (not needed soon).
- **No quick-shortcut buttons and no Slack tile in Home Layout A.** Their slots (columns 5–6, rows 3–4) form one wide **Timer tile** (2 × 2): remaining time, progress, Start/Pause and Reset; tapping it opens the Timer page. The timer runs on the phone, so the tile is live even before the Mac is found (no skeleton). Shortcuts and Slack stay sidebar pages; Layout B keeps its small Slack tile.
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

**Demo mode (simulators and emulators only):** detected natively (`MainActivity.kt` on Android, `targetEnvironment(simulator)` in `AppDelegate.swift` on iOS). The app then uses `FakeMacLink`, a simulated battery and `DemoTour` (`lib/app/demo_tour.dart`): 18 steps of **10 s** each, looping. Looking for Mac → connecting → connected Home → Claude, Music, System, Control Center, Timer and Settings pages → battery "plug in" and "unplug" banners → reconnecting → Mac asleep (night clock) → Bluetooth off → long drop ending on the night clock. The `flutter run` terminal prints a countdown for every step: `[demo] 04/18 Connected · Claude page · ⏱ 7s left`. Real phones always use real Bluetooth. `--dart-define=FAKE_MAC=true|false` overrides the detection.

## Hard rules

- **Android only, landscape only.** Target 915 × 412 dp and handle the display cutout. The `ios/` folder is kept **only** so the UI can be tested in the iOS Simulator (demo mode); the product ships on Android. Don't add web or desktop platforms.
- **The phone makes zero network calls.**
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
- **Slack:** counts only. Never transfer or show message text.
- **No "updated X minutes ago" labels.**
- **`flutter_blue_plus` stays pinned at 1.36.8** unless I approve an upgrade.
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
  - changing the protocol after M1
  - changing a locked design or product decision
  - designing a layout that isn't in the canvas (ask for screenshots instead of inventing)
- **At the end of each milestone:** say what changed, how to verify it on the Poco, and what's still open.
- **If something is blocked** (macOS permissions on the office Mac, MIUI background limits, Bluetooth quirks), say so plainly and propose the closest alternative.

## Status

- **Done:**
  - planning and designs (Color Blocks: Home A and B, night clock, and the Claude, Music, System, Timer and Settings pages)
  - Flutter project created, with `flutter_blue_plus` 1.36.8 and `wakelock_plus` added
- **Next:** **M0** (clean setup: remove extra platforms, landscape and immersive mode, bundled fonts, theme tokens, FakeTransport, registry), then **M1** (BLE spike: the Mac sends live CPU %, the phone shows it).
- **Designed 23 Nov 2026:** Control Center page and the Home Bluetooth tile (replaces the calendar tile in Home A and B).
- **Not designed yet:** Calendar, Slack, Weather, Shortcuts, GitHub pages and Home layout C.
- **Open questions:**
  1. YouTube Music: desktop app or browser?
  2. Which city for weather?
  3. Which apps or actions for the 4 shortcut buttons?
  4. Can Bluetooth, Accessibility, Automation, Calendar and Location (for the Wi-Fi network name) permissions be granted on the office Mac?
