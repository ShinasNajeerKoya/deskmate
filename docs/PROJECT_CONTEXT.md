# Deskmate — project context

Everything decided in the planning and design sessions so far. Read this before building anything.

## What it is

A desk display that sits beside a Mac and shows live info at a glance: Claude usage, music, system stats, calendar, Slack and more. It's inspired by github.com/zacharyinserra/deskhub (ESP32 board + Windows Python companion), but it's built from scratch with its own design, and it targets macOS plus an Android phone.

## Hardware and platform

- **Current test phone (Nov 2026): iQOO Neo 10R** (Android 15, Funtouch OS, AMOLED). The Poco isn't available for now. No device-specific code is needed; Funtouch OS needs the same background-killing setup as MIUI (allow background activity, auto-start, lock in recents).
- **Display:** Poco M2 Pro (preferred) or Poco M3, an old Android phone in **landscape only**. Usable area is about **915 × 412 dp**. The punch-hole camera sits on one side in landscape, so respect display cutouts.
- **Phone has no SIM and no internet.** Everything comes from the Mac.
- **Mac:** an office MacBook on office Wi-Fi. The phone **cannot** join the office Wi-Fi, because IT won't allow it.
- **Link (since v0.5.0): Wi-Fi only.** Bluetooth was removed as a link (23 Nov 2026) because it shared the Mac's radio with earphone audio and caused stutter. (v0.4.0 had Wi-Fi first, Bluetooth LE as backup.) Over Wi-Fi the phone and computer pair once with a 6-digit code from the Hub menu and every message is encrypted; Bluetooth is idle while Wi-Fi works, which fixes earphone audio stutter (the Mac's Bluetooth radio is shared with audio). The office phone needs IT to allow it on the same network as the Mac (device-to-device traffic; Bonjour or a typed IP). Original decision: **Bluetooth Low Energy**. The Mac is the peripheral and the phone is the central. No wires, Wi-Fi or cloud relay. Mac Bluetooth also runs the user's earphones, so keep traffic light: updates every 1–2 s, small album-art thumbnails.
- Only **one Mac** will ever pair.

## Architecture

```
Mac: Swift menu-bar app (CoreBluetooth peripheral)  ◄── BLE ──►  Phone: Flutter app (Android, landscape)
  collects stats, runs commands                                     all UI, sends control commands
```

- **Computer side: "Deskmate Hub"** (built 23 Nov 2026): `desktop/mac_driver/` (Swift menu-bar app) and `desktop/windows_driver/` (C# tray app, untested preview). Its own UI is only the connection status ("Connected to <phone name>"), Open at login and Quit; everything else is shown on the phone. It sends clock sync on every connection and hourly. Since v0.3.0 the macOS Hub sends live System, Bluetooth devices, Wi-Fi, YouTube Music (Chrome), Claude and Slack data; the Windows Hub sends System data only. One-time Mac setup for full data: Bluetooth (asked), Location (Wi-Fi name), Chrome → View → Developer → Allow JavaScript from Apple Events plus Automation (music), Accessibility (Slack badge), and "Connect Claude usage…" in the Hub menu (adds a status-line script to `~/.claude/settings.json`, with a backup; it never replaces an existing status line). Original planned responsibilities:
  - BLE GATT server
  - sleep/wake detection
  - stat collection
  - command execution: media keys, shortcuts, lock screen
  - starts at login
- **Phone side:** this Flutter project.
  - Link: encrypted Wi-Fi to the paired computer (v0.5.0+). `flutter_blue_plus` was removed with the Bluetooth link (it had been pinned to 1.36.8, the last BSD-3 release).
  - Uses a foreground service and wakelock to stay alive and connected. MIUI kills apps aggressively, so the setup checklist needs autostart on, no battery restrictions, and the app locked in recents.
- **The Mac syncs the phone's clock** on every connection, because the phone has no network time.
- **Build order:** prove the risky part first. Step 1: the Mac sends live CPU % over BLE and the phone shows it, tested on the office Mac (IT permissions) and with MIUI's background killing. Then theme system → sidebar and Home → night clock and states → pages.

## Data sources (Mac side)

- **Claude:**
  - token totals, the 7-day chart and per-model usage from Claude Code session logs `~/.claude/projects/**/*.jsonl` (token counts, model, timestamps only)
  - 5-hour and weekly limits through a Claude Code **status line** script that saves what Claude Code hands it. This only updates while the CLI is used; the desktop app doesn't feed it.
  - "waiting for you" alerts through Claude Code **hooks**
  - Don't use the undocumented usage endpoint. On macOS the credentials are in the Keychain.
- **System (Activity Monitor style):** CPU, memory and pressure, energy, disk read/write, network up/down, top processes. Skip temperatures in v1, since Apple Silicon needs private APIs.
- **Music: YouTube Music only.** The best route is the th-ch/youtube-music desktop app's API plugin (track, art, progress, controls). In a browser tab, media keys only work for controls. Still to confirm how the user plays it.
- **Calendar:** read from the Mac Calendar app (EventKit). **Not needed soon:** it's off Home (see below) and stays a sidebar tab to build later.
- **Mac Bluetooth (Control Center):** through IOBluetooth: the connected device (e.g. earphones), paired devices, and nearby devices found by scanning. The phone can disconnect the current device, connect a paired one, and scan and pair a new one. **Never turn the Mac's Bluetooth off**, because that would cut the phone's own BLE link and the phone couldn't turn it back on.
- **Mac Wi-Fi (Control Center):** through CoreWLAN: on/off and the network name. On macOS 14+ the network name needs Location permission for the Mac app; show "Wi-Fi" without a name if it's denied.
- **Slack:** **privacy mode**, so show counts only and never message text. v1 can read the Slack dock badge count. A full Slack app needs workspace admin approval.
- **Weather:** fetched by the Mac and sent over (the phone has no internet).

## Behaviour

- **Always on.** When the Mac sleeps, locks or shuts down (or BLE drops), the phone switches to a **dim night clock** at minimum brightness. It wakes back to the board when the Mac wakes. Tapping the night clock peeks at the board for 10 s.
- **Connection states (banners on Home only):**
  - Connecting: skeleton tiles with an **orange** banner ("Looking for your Mac…").
  - Reconnecting: a **blue** banner; tiles keep the last data.
  - Bluetooth off: a red banner.
- **Battery warnings:** no smart plug, warnings only. A banner shows above **70% while charging** ("unplug") and below **30% while not charging** ("plug in"). Both limits can be changed in Settings. The battery warning shows on every page.
- No "updated X minutes ago" labels anywhere.
- **No burn-in shift** (removed 23 Nov 2026: the drifting board and night clock looked odd). Revisit with a subtler approach if an OLED phone shows burn-in.
- **Night clock only when the computer sleeps or locks** (the Hub sends `power`). A dropped connection never puts the board to sleep; it shows the blue "Reconnecting" banner.

## UI structure

- **Sidebar (left):**
  - a slim icon rail with labels that scrolls normally
  - **Settings pinned at the bottom**
  - tap to open a page, with no auto-scroll
  - editable order and visibility
- **Pages:** Home, Claude, Music, System, **Control** (Control Center), Timer, Calendar, Slack, Weather, Shortcuts, GitHub, plus Settings.
- **Control Center** (sidebar label "Control", Bluetooth icon): a mint "connected device" block with Disconnect and Switch device, a Mac Wi-Fi card with an on/off toggle, and a device list with "My devices" (Connect) and "Nearby" (Pair).
- **Home:**
  - bento tiles of different sizes; each tile shows only its **one basic item**
  - tapping a tile opens its page
  - **long-press to edit**: drag or swap tile positions
  - **No Calendar tile on Home** (decided 23 Nov 2026). Its old slot (the mint "Next up" tile, 2×1) is now the **Bluetooth tile**: it shows the Mac's connected Bluetooth device and opens Control Center when tapped. **Every theme and every Home layout (including C and the other 3 themes) must follow this**: no calendar tile; a Bluetooth tile instead. Calendar stays a sidebar tab for later.
- **Home layouts:** there are 3 (A, B, C) that **rotate every 10 min**.
  - Settings → Home layouts: lock **1** (always shown) or pick **2–3** to rotate.
  - Every other page has **one layout only**.
- **Clock:** a large flip-clock style, with digits on split square cards.
- **Music tile:** previous, play/pause and next.
- **No quick-shortcut buttons on Home, and no Slack tile in Layout A** (decided 23 Nov 2026). In Layout A their slots (columns 5–6, rows 3–4) form one wide **Timer tile** (2 × 2): remaining time, a progress line, Start/Pause and Reset; tapping it opens the Timer page. It works without the Mac, so it never shows as a skeleton. Shortcuts and Slack remain sidebar pages, and Layout B keeps its small Slack tile. Every theme follows this.
- **Focus timer default: 10 minutes** ("Focus" preset). Presets: Short break 5, Long break 15, Focus 10, Deep work 50.

## Design (locked)

- **Live designs (Claude design canvas):** https://claude.ai/artifact/A4YezfL5M982Eo9coC9Gs7
- **Chosen theme for v1: "Color Blocks" (iteration 2).** Designed so far: Home A and B (with the Bluetooth tile), Night clock, and the Claude, Music, System, Timer, Settings and **Control Center** pages, plus the shared sidebar.
- **Four themes are planned** (Settings → Theme): Graphite (1), **Color Blocks (2, default)**, Paper (3), Paper Blocks (4).
  - Build the colours, fonts and corner sizes as **theme tokens** (ThemeExtension) from day one, so the other themes are just token swaps later.
- **Color Blocks tokens:**

| Token | Value | Use |
|---|---|---|
| bg | `#0F0F10` | screen background |
| panel | `#1A1A1D` | dark tiles, sidebar |
| panel2 | `#26262A` | inner surfaces |
| text | `#F3EEE6` | main text |
| muted | `#A5A39E` | secondary text |
| cream | `#F3EEE6` / `#E4DCCF` | clock tile and cards, ink text `#141414` |
| clay | `#E07A4F` | Claude, primary action, ink `#1A0F0A` |
| violet | `#2A2440` / `#3C3460` | music, text `#C9BFF2` |
| mint | `#BFE3CC` | Bluetooth / Control Center (and the Calendar page later), ink `#10261A` |
| butter | `#F2D16B` | Slack, ink `#2A2108` |
| ok | `#8FD6A8` | connected dot |

  - **Fonts:** DM Sans (UI) and Bricolage Grotesque (numbers and clock).
  - **Radius:** 20–26 on tiles, 16 on buttons.
  - **Sidebar:** a floating rounded panel; the active item is a cream pill with dark text.
- **Not designed yet:** Calendar, Slack, Weather, Shortcuts, GitHub pages and Home layout C (C must use the Bluetooth tile, not a calendar tile).
- **The other themes' boards** (Graphite, Paper, Paper Blocks) on the canvas still show the old "Next up" tile. Replace it with the Bluetooth tile when designing those themes.

## Later (phase 2)

- the other 3 themes
- Home tile drag-to-resize
- a full Slack integration
