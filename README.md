# Deskmate

A desk display for a Mac. A Flutter app on an Android phone (landscape, no internet) shows Claude usage, music, system stats, a focus timer, the Mac's Bluetooth devices and more, live from a Swift app on the Mac over Bluetooth Low Energy.

- **Phone app:** Flutter (`lib/`), Android. Runs in demo mode on simulators and emulators.
- **Mac app:** Swift (`mac/`). Currently a command-line spike that sends CPU %.
- **Docs:** `docs/PROJECT_CONTEXT.md` (decisions), `docs/KICKOFF_PROMPT.md` (engineering brief), `CLAUDE.md`.

## Run

```bash
flutter run                 # phone, simulator or emulator (demo mode on simulators/emulators)
cd mac && swift run         # Mac side
```

## Install on a phone

Download the APK from the latest release and open it on the phone (allow "install unknown apps").
