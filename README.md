# Deskmate

A desk display for a Mac. A Flutter app on an Android phone (landscape, no internet) shows Claude usage, music, system stats, a focus timer, the Mac's Bluetooth devices and more, live from a Swift app on the Mac over Bluetooth Low Energy.

- **Deskmate** (phone app): Flutter (`lib/`), Android. Runs in demo mode on simulators and emulators.
- **Deskmate Hub** (computer app): macOS in `desktop/mac_driver/` (Swift menu-bar app), Windows in `desktop/windows_driver/` (C# tray app, preview). It runs in the background and starts at login.
- **Docs:** `docs/PROJECT_CONTEXT.md` (decisions), `docs/KICKOFF_PROMPT.md` (engineering brief), `CLAUDE.md`.

## Run

```bash
flutter run                 # phone, simulator or emulator (demo mode on simulators/emulators)
cd desktop/mac_driver && swift run    # Deskmate Hub for macOS (development)
```

## Install

From the latest release:
1. **Deskmate Hub** on your computer (macOS or Windows).
2. **Deskmate** on your phone (APK; allow "install unknown apps").
