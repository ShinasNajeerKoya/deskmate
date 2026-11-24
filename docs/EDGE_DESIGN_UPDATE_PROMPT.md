# Deskmate — Edge design update (prompt for Claude Code)

Paste everything below the line into Claude Code (in Cursor, opened in the `deskmate` folder).

> **Corrections (24 Nov 2026), these win over the text below:** Slack is removed (no Settings row, no tab); the phone ↔ Mac link is Wi-Fi only (ignore any BLE-link wording); **never commit**, the owner commits; the **Timer is an Edge tab** (order: Home, Claude, Music, System, Control, Timer, Settings; dots = 7, not 6); Edge stays non-default until its shell and screens are built.

---

Read `CLAUDE.md`, `docs/PROJECT_CONTEXT.md` and `docs/KICKOFF_PROMPT.md` first. This message is a **design update** that changes the navigation model and the default theme. **Where it conflicts with those files, this message wins.** Update those files as described in section 9 before you write any UI code.

Design canvas (source of truth): https://claude.ai/artifact/A4YezfL5M982Eo9coC9Gs7
- Boards to match: `Edge · Home`, `Edge · Claude`, `Edge · Music`, `Edge · System`, `Edge · Control Center`, `Edge · Settings`, plus the shared `Page dots`.
- If you can't open the canvas, ask me for screenshots. Don't invent layouts.

## 1. What changed

1. **New default theme: "Edge".** It's borderless: content sits directly on a dark background with soft colour glows. There are no container boxes and no sidebar.
2. **Navigation is swipe tabs.**
   - Every page is a full-screen tab in one horizontally swipeable `PageView`.
   - A row of **page dots** at the bottom shows the current tab.
   - Swiping left or right moves between tabs, and tapping a Home element jumps to its tab.
3. **Tab order (final):** `Home → Claude → Music → System → Control Center → Settings`.
   - Settings is always the last tab.
   - Calendar, Weather, Shortcuts and GitHub are **not part of the Edge tab set yet** (not designed). **Timer is an Edge tab** (designed 24 Nov 2026, see section 3). Don't build them now, but keep them in the feature registry so they can slot in later.
4. **Four themes:** `Edge` (default), `Color Blocks`, `Paper`, `Paper Blocks`. Graphite is **removed**.
   - Edge uses swipe tabs and dots.
   - **Color Blocks, Paper and Paper Blocks keep the sidebar** layout from the earlier boards (`Page-*` and `Rail`).
   - So **navigation style is a property of the theme**: `DeskTheme.navigation = NavStyle.swipeDots | NavStyle.sidebar`.
5. **Animated switch between navigation styles.** In Settings, picking a theme changes the navigation live:
   - Picking Edge: the sidebar slides out to the left (about 24 px) while fading and collapsing its width to 0, over about 500 ms with an ease-in-out curve. The content widens to fill the space, and the page dots fade in and slide up from the bottom at the same time.
   - Picking any sidebar theme: the exact reverse.
   - Implement it with one shell widget that animates `sidebarWidth`, `sidebarOpacity` and `dotsHeight/opacity/offset` from a single `AnimationController` (or implicit animations). **No hard jumps.**
   - **Edge is the only theme with swipe tabs and dots.** The other three get the sidebar back (see section 4).

## 2. Edge theme tokens (add to `DeskTheme`, don't hard-code)

| Token | Value |
|---|---|
| bg | `#07090D` |
| bgGlowTeal | `rgba(44,140,150,0.22)` at the top left |
| bgGlowViolet | `rgba(120,80,200,0.2)` at the bottom right |
| text | `#EAF0F7` |
| textMuted | `#7E8A9C` |
| textSoft | `#9AA6B8` |
| hairline | `rgba(255,255,255,0.08)` |
| ringTrack | `rgba(255,255,255,0.09)` |
| clay | `#E07A4F` (Claude, primary accent) |
| amber | `#F2D16B` (weekly limit) |
| teal | `#4FD1C5` (CPU) |
| violet | `#A58BFF` (memory, music accent) |
| mint | `#5ED3A4` (connected, OK) |
| blue | `#7FB2FF` (timer) |

- **Fonts:** Inter (UI) and Outfit (numbers and clock, light weights 200–300 for the big digits). Bundle both as assets; no runtime download.
- **Shapes:** rings use stroke 7–8 with round caps. Dividers are 1 px hairlines, never boxes.
- **Label style:** small caps with letter-spacing, 10–11 px, uppercase, in the tile's accent or muted colour.
- Each page has its own subtle background glow (the glow colours shift per page, as in the canvas). Keep `bgGlow` as per-page tokens.
- **Page dots:** 6 dots, 6 px high. The active one is a 22 px wide pill in `text` and the others are 6 px circles at 25% white.

## 3. Screens to build (Edge)

All screens target 915 × 412 dp, landscape, with a 28 px left/right padding and a 14 px top padding. The dots row is 30 px high at the bottom.

- **Home**
  - The big flip-less thin clock "HH:MM" on the left (Outfit 200, about 124 px), with small seconds and the date.
  - Music on the right: art 76 px, song, artist, a progress line and prev / play-pause / next.
  - A row of 5 ring gauges at the bottom: **Claude 5-hour, Weekly, CPU, Memory, Timer**.
  - **Taps:** clock → Timer *(the Timer tab is not built yet; show nothing or a placeholder)*, music → Music, Claude and Weekly → Claude, CPU and Memory → System, Timer ring → Timer *(same placeholder)*.
- **Claude:** two big rings (5-hour 62%, weekly 38%) on the left; on the right the sessions count (with "N waiting for you"), tokens today, usage by model (3 thin bars) and a 7-day bar chart.
- **Music:**
  - Large art (280 px), the song title in Outfit 300, artist and album, a progress line with times, and shuffle / prev / play-pause / next / like plus a volume line.
  - A right column with **1 previous track** (dimmed) and **3 up next** tracks.
- **System** (Activity Monitor style): five smaller rings (CPU, Memory, Energy, Disk, Network; 68 px), and below them more room for a 5-minute CPU and memory graph, a **Top CPU** list (5 apps) and a **Top memory** list (5 apps, with their memory in MB or GB). The sidebar themes' System page shows the same two lists.
- **Control Center:** the connected device (name, state, Disconnect and Switch device), the Mac Wi-Fi toggle, "My devices" with connect actions and "Nearby" with Pair buttons. This is Bluetooth device management **on the Mac** (the Mac performs the actions through commands from the phone); don't confuse it with the phone's own BLE link to the Mac.
- **Timer** (board `Edge · Timer`, 24 Nov 2026; the tab before Settings):
  - A 250 px tick dial on the left (blue `#7FB2FF`): 60 outer ticks that count the **seconds** (the lit ticks sweep down once every minute: 07:42 lights 42, 07:00 lights 60; the ticks are numbered 0 at the top, 1, 2, 3 … down the right side, 59, 58, 57 … down the left. At the start of a minute all 60 are lit; then 59, 58, 57 … go dark. When 20 are left (0 .. 19) a second end starts moving: tick 59 lights mostly blue, then 58, 57, 56, 55 appear fading to grey, then from 14 on the solid part follows (59 turns solid, then 58 …) with the 5-tick fade moving on, so 20 ticks stay lit. The head is thick and solid. It never resets after that: from the second minute on the 20 ticks (15 solid + the 5-tick fade) keep going round once a minute, one tick per second), and a thin inner arc with a glowing dot for the time left in the whole timer. In the middle the time in Outfit 200 (40 px), "Focus · running" and "of 10 min".
  - A right column with the four **presets** as plain rows (Short break 5, Long break 15, **Focus 10** (default, selected), Deep work 50), then Start/Pause (68 px circle) and Reset (52 px outlined circle).
  - On the right of the controls: "Session 3 of 4" with four small bars and "1h 20m focused today".
  - The timer runs on the phone, so this tab works before the Mac is found. Home's clock and Timer ring open it.
- **Settings (last tab)**, redesigned 24 Nov 2026 in the Edge style (borderless, caps labels, hairlines; board `Edge · Settings`):
  - Theme: four small previews in a row (Edge, Color Blocks, Paper, Paper Blocks) with a light ring on the one in use; picking one runs the navigation animation from section 1.
  - Below the theme, the settings in two columns: Wi-Fi link, Tab order, Battery warnings (30% · 70%) and Time format (a 12-hour / 24-hour switch). No sub page.
  - No Home layouts (Edge has only one Home layout; layouts are only in the sidebar themes' Settings) and no "Night clock when Mac sleeps" toggle (the night clock is always on).
  - The sidebar themes keep their old Settings page with its items (also without the night clock toggle). Switching theme cross-fades the old Settings into the new one.

## 4. Behaviour rules

- **The phone never shows swipe tabs and a sidebar at the same time.** The navigation style comes from the active theme.
- **Edge Home has a single layout** for now (the screens above). The A / B / C rotation and lock in Settings applies to the sidebar themes, where those layouts are designed. Keep the Settings UI, but note in a code comment that Edge Home layout rotation isn't designed yet. **Ask me before inventing extra Edge Home layouts.**
- Connection states, night clock and battery banners still apply:
  - They sit on the Home tab's top edge (banners use the same orange, blue and red colours as before).
  - The battery banner shows on every tab.
  - The night clock replaces everything and hides the dots.
- Swiping must feel native: a `PageView` with snapping physics. Tapping a ring or tile animates to the target tab (about 350 ms).
- The tab list must come from the **feature registry** (`FeatureDescriptor`): the registry decides tab order and which features exist. Settings is pinned last.
- Persist the chosen theme and tab order in `SettingsRepository`. Bump the **schema version** and add a migration: any saved "Graphite" theme maps to Edge, and a missing nav style defaults from the theme.

## 5. Implementation plan

1. Update docs (section 9).
2. Extend `DeskTheme` with the Edge tokens, `NavStyle` and per-page glows. Make **Edge the default**. Remove Graphite.
3. Build the `AppShell` that switches between the swipe-tabs layout and the sidebar layout, with the animated transition from section 1.
4. Build the Edge screens on `FakeTransport`, in this order: Home, Claude, Music, System, Control Center, Settings.
5. Add golden tests at 915 × 412 for each Edge screen, plus one animation test that checks the navigation switch ends in the right state.
6. Show me the result on the Poco and list what's left.

## 6. Quality bar

- Never hard-code colours, fonts or radii in widgets.
- Keep `flutter analyze` clean and avoid `print`.
- Unit-test the theme migration and the tab order logic.
- Make small commits with clear messages.

## 7. Ask me before

- adding any dependency
- designing anything that isn't in the canvas (extra Edge Home layouts, Calendar, Weather, Shortcuts or GitHub tabs)
- changing the protocol or a locked decision

## 8. Open questions

1. Do we show a Timer tab in the Edge set later, or keep Timer only as a Home ring and clock link?
2. Should Edge get its own Home layouts later, so the A / B / C rotation works there too?

## 9. Doc updates to make first

- `CLAUDE.md`:
  - Replace the sidebar rule with: *navigation style belongs to the theme; Edge (default) uses swipe tabs and bottom dots, the other themes use the sidebar*.
  - Replace the design-token note and the theme list: Edge, Color Blocks, Paper, Paper Blocks.
  - Add the feature ids for the Edge tab order.
  - Update **Status** with this design update.
- `docs/PROJECT_CONTEXT.md`:
  - Update the **UI structure**, **Design** and **Later** sections to match this message.
  - Add the Edge token table.
- `docs/KICKOFF_PROMPT.md`:
  - Add a note at the top: *superseded where it conflicts by `docs/EDGE_DESIGN_UPDATE_PROMPT.md`*.

Start with the doc updates, then M-next from this plan.
