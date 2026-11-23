import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../ble/mac_link.dart';
import '../pages/claude_page.dart';
import '../pages/control_page.dart';
import '../pages/home_page.dart';
import '../pages/link_diagnostics_page.dart';
import '../pages/music_page.dart';
import '../pages/night_clock.dart';
import '../pages/not_designed_page.dart';
import '../pages/settings_page.dart';
import '../pages/system_page.dart';
import '../pages/timer_page.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/burn_in_shift.dart';
import '../ui/chrome.dart';
import '../ui/format.dart';
import '../ui/rail.dart';
import 'app_scope.dart';
import 'demo_tour.dart';
import 'focus_timer.dart';
import 'phone_battery.dart';
import 'settings.dart';

/// The board: sidebar + header + current page, with the night clock on top
/// while the Mac sleeps or the link has been down for a while.
class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.link,
    required this.settings,
    required this.battery,
    required this.timer,
    this.tour,
    this.nightAfter = const Duration(seconds: 30),
  });

  final MacLink link;
  final SettingsController settings;
  final PhoneBattery battery;
  final FocusTimer timer;

  /// Simulator demo tour; it switches pages as it goes.
  final DemoTour? tour;

  /// How long a dropped link shows "Reconnecting" before falling back to the night clock.
  final Duration nightAfter;
  static const peekFor = Duration(seconds: 10);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  PageId _page = PageId.home;
  DateTime _now = DateTime.now();
  DateTime? _peekUntil;
  bool _dimmed = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    widget.tour?.addListener(_followTour);
  }

  void _followTour() {
    final page = widget.tour!.step.page;
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    widget.tour?.removeListener(_followTour);
    _tick?.cancel();
    _setDim(false);
    super.dispose();
  }

  bool get _night {
    final link = widget.link;
    if (!widget.settings.nightClock || !link.everConnected) return false;
    final now = DateTime.now();
    if (_peekUntil != null && now.isBefore(_peekUntil!)) return false;
    if (link.macAsleep && link.state != LinkState.connected) return true;
    final lost = link.lostAt;
    return link.state != LinkState.connected && lost != null && now.difference(lost) >= widget.nightAfter;
  }

  void _setDim(bool dim) {
    if (dim == _dimmed) return;
    _dimmed = dim;
    final b = ScreenBrightness.instance;
    (dim ? b.setApplicationScreenBrightness(0.01) : b.resetApplicationScreenBrightness()).catchError((_) {});
  }

  void _openDiagnostics() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LinkDiagnosticsPage(link: widget.link)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.link, widget.settings, widget.battery, widget.timer]),
      builder: (context, _) {
        final t = DeskmateTokens.of(context);
        final night = _night;
        WidgetsBinding.instance.addPostFrameCallback((_) => _setDim(night));
        return AppScope(
          link: widget.link,
          settings: widget.settings,
          battery: widget.battery,
          timer: widget.timer,
          open: (p) => setState(() => _page = p),
          child: Scaffold(
            backgroundColor: t.bg,
            body:
                night
                    // The night clock stays up for hours, so it drifts further and more often.
                    ? BurnInShift(
                      amplitude: 24,
                      interval: const Duration(minutes: 1),
                      child: NightClock(
                        now: _now,
                        use24h: widget.settings.use24h,
                        status: NightClock.statusFor(widget.link),
                        battery: widget.battery.level,
                        onTap: () => setState(() => _peekUntil = DateTime.now().add(Shell.peekFor)),
                      ),
                    )
                    : BurnInShift(child: _board(t)),
          ),
        );
      },
    );
  }

  Widget _board(DeskmateTokens t) {
    final home = _page == PageId.home;
    final s = widget.settings;
    final banners =
        [
          if (home) connectionBanner(t, widget.link.state),
          batteryBanner(t, widget.battery.level, widget.battery.charging, s.batteryLow, s.batteryHigh),
        ].whereType<Widget>().toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rail(active: _page, onSelect: (p) => setState(() => _page = p)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: home ? longDate(_now) : _page.label,
                    titleSize: home ? 15 : 16,
                    trailing:
                        home
                            ? (widget.battery.level == null ? '—' : '${widget.battery.level}%')
                            : clockText(_now, s.use24h),
                    onMacLongPress: _openDiagnostics,
                  ),
                  const SizedBox(height: 8),
                  // Two banners share one row so they take less height.
                  if (banners.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          for (var i = 0; i < banners.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: banners[i]),
                          ],
                        ],
                      ),
                    ),
                  Expanded(child: _pageBody()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageBody() => switch (_page) {
    PageId.home => HomePage(now: _now),
    PageId.claude => ClaudePage(now: _now),
    PageId.music => const MusicPage(),
    PageId.system => const SystemPage(),
    PageId.control => const ControlPage(),
    PageId.timer => const TimerPage(),
    PageId.settings => const SettingsPage(),
    _ => NotDesignedPage(page: _page),
  };
}
