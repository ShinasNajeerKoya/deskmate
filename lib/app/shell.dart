import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../ble/mac_link.dart';
import '../pages/claude_page.dart';
import '../pages/control_page.dart';
import '../pages/edge/edge_claude.dart';
import '../pages/edge/edge_control.dart';
import '../pages/paper/paper_claude.dart';
import '../pages/paper/paper_control.dart';
import '../pages/paper/paper_home.dart';
import '../pages/paper/paper_music.dart';
import '../pages/paper/paper_settings.dart';
import '../pages/paper/paper_system.dart';
import '../pages/paper/paper_timer.dart';
import '../pages/edge/edge_home.dart';
import '../pages/edge/edge_music.dart';
import '../pages/edge/edge_settings.dart';
import '../pages/edge/edge_system.dart';
import '../pages/edge/edge_timer.dart';
import '../pages/home_page.dart';
import '../pages/horizon/horizon_claude.dart';
import '../pages/horizon/horizon_control.dart';
import '../pages/horizon/horizon_home.dart';
import '../pages/horizon/horizon_timer.dart';
import '../pages/horizon/horizon_system.dart';
import '../pages/link_diagnostics_page.dart';
import '../pages/music_page.dart';
import '../pages/night_clock.dart';
import '../pages/pair_page.dart';
import '../pages/not_designed_page.dart';
import '../pages/settings_page.dart';
import '../pages/system_page.dart';
import '../pages/timer_page.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/chrome.dart';
import '../ui/edge_glow.dart';
import '../ui/horizon_bar.dart';
import '../ui/page_dots.dart';
import '../ui/format.dart';
import '../ui/rail.dart';
import 'app_scope.dart';
import 'demo_tour.dart';
import 'feature_registry.dart';
import 'focus_timer.dart';
import 'listening_tracker.dart';
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
  });

  final MacLink link;
  final SettingsController settings;
  final PhoneBattery battery;
  final FocusTimer timer;

  /// Simulator demo tour; it switches pages as it goes.
  final DemoTour? tour;

  static const peekFor = Duration(seconds: 10);

  /// While developing (debug builds) the "unplug the charger" banner is off, because the dev
  /// phone sits on a cable all day. Profile and release builds show it. Tests turn this off.
  static bool hideUnplugBanner = kDebugMode;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  PageId _page = PageId.home;
  late DateTime _now = widget.link.now(); // the computer's clock once synced
  DateTime? _peekUntil;
  bool _dimmed = false;
  Timer? _tick;
  final _listening = ListeningTracker();

  /// Navigation style of the current theme: Edge swipes between tabs with page dots,
  /// the others use the sidebar. [_nav] animates between them: 0 = sidebar, 1 = swipe tabs.
  late bool _swipe = widget.settings.theme.swipes;
  late final AnimationController _nav = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: _swipe ? 1 : 0,
  );
  late PageController _pager = PageController(initialPage: _ringPage(_tabIndex));
  final _tabs = edgeTabs();

  /// The tab shown (dots follow it without rebuilding the whole board while swiping).
  late final ValueNotifier<int> _activeTab = ValueNotifier(_tabIndex);

  /// Tabs loop: swiping past the last one goes to Home and the other way round. The page
  /// view counts pages without end; start far from zero so both directions have room.
  /// Pages that already have their Edge screen (the rest still show the old page until built).
  static const _edgeScreens = {
    PageId.home,
    PageId.claude,
    PageId.music,
    PageId.system,
    PageId.control,
    PageId.timer,
    PageId.settings,
  };

  /// Pages that already have their Paper screen.
  static const _paperScreens = {
    PageId.home,
    PageId.claude,
    PageId.music,
    PageId.system,
    PageId.control,
    PageId.timer,
    PageId.settings,
  };

  int? _dragStart; // the tab page showing when the current swipe began

  int _ringPage(int tab) => _tabs.length * 1000 + tab;

  int get _tabIndex => _tabs.indexOf(_page).clamp(0, _tabs.length - 1);

  /// The "unplug" banner was closed until the battery reaches this level (reset when unplugged).
  int? _unplugSnoozedUntil;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = widget.link.now();
      _listening.update(widget.link.board.music?.playing ?? false, _now);
      setState(() {});
    });
    widget.tour?.addListener(_followTour);
  }

  void _go(PageId page) {
    if (_swipe) {
      final i = _tabs.indexOf(page);
      if (i < 0) return; // not an Edge tab
      if (_pager.hasClients) {
        // Take the shorter way round the loop.
        final n = _tabs.length;
        final from = _pager.page!.round();
        var step = (i - from % n) % n;
        if (step > n / 2) step -= n;
        _pager.animateToPage(from + step, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    }
    setState(() => _page = page);
  }

  void _followTour() {
    final page = widget.tour!.step.page;
    if (page != _page) _go(page);
  }

  /// Called from build when the theme's navigation style changed: swap controllers and animate.
  void _syncNavigation(bool swipe) {
    _swipe = swipe;
    if (swipe) {
      if (!_tabs.contains(_page)) _page = PageId.home;
      final old = _pager;
      _pager = PageController(initialPage: _ringPage(_tabIndex));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
        _activeTab.value = _tabIndex;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nav.animateTo(swipe ? 1 : 0, curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    widget.tour?.removeListener(_followTour);
    _tick?.cancel();
    _nav.dispose();
    _pager.dispose();
    _activeTab.dispose();
    _setDim(false);
    super.dispose();
  }

  bool get _night {
    final link = widget.link;
    if (!widget.settings.nightClock || !link.everConnected) return false;
    final now = DateTime.now();
    if (_peekUntil != null && now.isBefore(_peekUntil!)) return false;
    // Only when the computer itself sleeps or locks. A dropped connection never
    // puts the board to sleep; it shows the "Reconnecting" banner instead.
    return link.macAsleep;
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
        final swipe = widget.settings.theme.swipes;
        if (swipe != _swipe) _syncNavigation(swipe);
        final night = _night;
        WidgetsBinding.instance.addPostFrameCallback((_) => _setDim(night));
        return AppScope(
          link: widget.link,
          settings: widget.settings,
          battery: widget.battery,
          timer: widget.timer,
          open: _go,
          child: Scaffold(
            backgroundColor: t.bg,
            body:
                night
                    ? NightClock(
                      now: _now,
                      use24h: widget.settings.use24h,
                      status: NightClock.statusFor(widget.link),
                      battery: widget.battery.level,
                      onTap: () => setState(() => _peekUntil = DateTime.now().add(Shell.peekFor)),
                    )
                    : _board(t),
          ),
        );
      },
    );
  }

  Widget _board(DeskmateTokens t) {
    if (!widget.battery.charging) _unplugSnoozedUntil = null; // unplugged: start over
    return SafeArea(
      child: AnimatedBuilder(
        animation: _nav,
        builder: (context, _) {
          final c = _nav.value; // 0 = sidebar, 1 = swipe tabs
          final p = 1 - c;
          return Stack(
            children: [
              // The pages keep the full height; only their width changes with the sidebar.
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The sidebar slides out to the left while it fades and its width collapses.
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: p,
                        child: Opacity(
                          opacity: p,
                          child: Transform.translate(
                            offset: Offset(-24 * c, 0),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Rail(active: _page, onSelect: _go),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      // Switching theme fades the old page into the new one (for example the old Settings
                      // into the Edge Settings) while the sidebar and the dots slide.
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        layoutBuilder:
                            (current, previous) =>
                                Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
                        child:
                            _swipe
                                ? KeyedSubtree(
                                  key: const ValueKey('swipe'),
                                  child: NotificationListener<ScrollNotification>(
                                    onNotification: (n) {
                                      if (n.depth != 0) return false;
                                      // Remember where a swipe began; forget it when the page view stops, so a later
                                      // tap-to-open animation isn't pulled back toward the old start.
                                      if (n is ScrollStartNotification && n.dragDetails != null) {
                                        _dragStart = _pager.page?.round();
                                      } else if (n is ScrollEndNotification) {
                                        _dragStart = null;
                                      }
                                      return false;
                                    },
                                    child: PageView.builder(
                                      controller: _pager,
                                      // The default page snapping would wrap (and ignore) our physics.
                                      pageSnapping: false,
                                      physics: _SnappyPagePhysics(startPage: () => _dragStart),
                                      // Neighbour tabs are built ahead, so a swipe doesn't start with a build hitch.
                                      allowImplicitScrolling: true,
                                      onPageChanged: (i) {
                                        _page = _tabs[i % _tabs.length];
                                        _activeTab.value = i % _tabs.length;
                                      },
                                      itemBuilder:
                                          (context, i) => _framed(t, _tabs[i % _tabs.length], 10 * c, glow: true),
                                    ),
                                  ),
                                )
                                : KeyedSubtree(key: const ValueKey('sidebar'), child: _framed(t, _page, 10 * c)),
                      ),
                    ),
                  ],
                ),
              ),
              // The page dots float over the bottom edge: they fade in and slide up.
              if (c > 0 && widget.settings.theme.navigation == NavStyle.floatingBar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: c,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _activeTab,
                      builder: (context, active, _) => HorizonBar(tabs: _tabs, active: _tabs[active], onSelect: _go),
                    ),
                  ),
                )
              else if (c > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: c,
                      child: Transform.translate(
                        offset: Offset(0, 14 * p),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _activeTab,
                          builder: (context, active, _) => PageDots(count: _tabs.length, active: active),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// One page with its header and banners. Edge gives each page its own background glow.
  /// (The old Color Blocks page bodies are reused until each Edge screen is built.)
  Widget _framed(DeskmateTokens t, PageId page, double left, {bool glow = false}) {
    final home = page == PageId.home;
    final s = widget.settings;
    final banners =
        [
          if (home)
            connectionBanner(
              t,
              widget.link.state,
              onPair:
                  () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PairPage(link: widget.link))),
            ),
          batteryBanner(
            t,
            widget.battery.level,
            widget.battery.charging,
            s.batteryLow,
            s.batteryHigh,
            snoozedUntil: _unplugSnoozedUntil,
            showUnplug: !Shell.hideUnplugBanner,
            onClose: () => setState(() => _unplugSnoozedUntil = unplugSnoozeUntil(widget.battery.level ?? 0)),
          ),
        ].whereType<Widget>().toList();

    if (!glow && s.theme == ThemeId.paper && _paperScreens.contains(page)) {
      // A Paper page draws its own header; banners sit above it.
      return Padding(
        padding: EdgeInsets.fromLTRB(left, 10, 10, 10),
        child: Column(
          children: [
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
            Expanded(child: _paperBody(page)),
          ],
        ),
      );
    }

    if (glow &&
        s.theme == ThemeId.horizon &&
        (page == PageId.claude ||
            page == PageId.home ||
            page == PageId.system ||
            page == PageId.control ||
            page == PageId.timer)) {
      // Horizon draws its own page; the other pages use the Edge screens until they are built.
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -1.1),
            radius: 1.0,
            colors: [const Color(0x218EA2FF), t.bg.withValues(alpha: 0)],
          ),
        ),
        child: Column(
          children: [
            if (banners.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < banners.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: banners[i]),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: switch (page) {
                PageId.home => HorizonHome(now: _now),
                PageId.system => const HorizonSystem(),
                PageId.control => const HorizonControl(),
                PageId.timer => const HorizonTimer(),
                _ => HorizonClaude(now: _now, use24h: s.use24h),
              },
            ),
          ],
        ),
      );
    }

    if (glow && _edgeScreens.contains(page)) {
      // An Edge screen draws its own header and padding; banners sit along its top edge.
      return EdgeGlow(
        page: page,
        child: Column(
          children: [
            if (banners.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < banners.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: banners[i]),
                    ],
                  ],
                ),
              ),
            Expanded(child: _edgeBody(page)),
          ],
        ),
      );
    }

    final body = Padding(
      padding: EdgeInsets.fromLTRB(left, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: home ? longDate(_now) : page.label,
            titleSize: home ? 15 : 16,
            trailing:
                home ? (widget.battery.level == null ? '—' : '${widget.battery.level}%') : clockText(_now, s.use24h),
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
          Expanded(child: _pageBody(page)),
        ],
      ),
    );
    return glow ? EdgeGlow(page: page, child: body) : body;
  }

  Widget _paperBody(PageId page) => switch (page) {
    PageId.home => PaperHome(now: _now),
    PageId.claude => PaperClaude(now: _now, use24h: widget.settings.use24h),
    PageId.music => PaperMusic(now: _now, use24h: widget.settings.use24h, listening: _listening),
    PageId.system => PaperSystem(now: _now, use24h: widget.settings.use24h),
    PageId.control => PaperControl(now: _now, use24h: widget.settings.use24h),
    PageId.timer => PaperTimer(now: _now, use24h: widget.settings.use24h),
    PageId.settings => PaperSettings(now: _now, use24h: widget.settings.use24h),
    _ => _pageBody(page),
  };

  Widget _edgeBody(PageId page) => switch (page) {
    PageId.home => EdgeHome(now: _now),
    PageId.claude => EdgeClaude(now: _now, use24h: widget.settings.use24h),
    PageId.system => const EdgeSystem(),
    PageId.timer => EdgeTimer(now: _now, use24h: widget.settings.use24h),
    PageId.settings => EdgeSettings(now: _now, use24h: widget.settings.use24h),
    PageId.control => EdgeControl(now: _now, use24h: widget.settings.use24h),
    PageId.music => EdgeMusic(
      now: _now,
      use24h: widget.settings.use24h,
      listening: _listening,
      // Under Horizon the play controls sit higher, above the floating bar.
      controlsLift: widget.settings.theme == ThemeId.horizon ? 30 : 0,
      pillControls: widget.settings.theme == ThemeId.horizon,
    ),
    _ => _pageBody(page),
  };

  Widget _pageBody(PageId page) => switch (page) {
    PageId.home => HomePage(now: _now),
    PageId.claude => ClaudePage(now: _now, use24h: widget.settings.use24h),
    PageId.music => MusicPage(listening: _listening),
    PageId.system => const SystemPage(),
    PageId.control => const ControlPage(),
    PageId.timer => const TimerPage(),
    PageId.settings => const SettingsPage(),
    _ => NotDesignedPage(page: page),
  };
}

/// Page swiping that switches on a light touch. A swipe changes the tab when it is a quick
/// flick or when the finger moved a few percent of the width, however slowly. It never skips
/// a tab, and it settles with a stiff spring so it doesn't feel slow.
class _SnappyPagePhysics extends PageScrollPhysics {
  const _SnappyPagePhysics({super.parent, required this.startPage});

  /// The page that was showing when the finger went down.
  final int? Function() startPage;

  static const _flick = 30.0; // px/s: any flick this fast switches tab
  static const _distance = 0.03; // or moving the finger this fraction of the page

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPagePhysics(parent: buildParent(ancestor), startPage: startPage);

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(mass: 0.4, stiffness: 320, ratio: 1.0);

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final start = startPage();
    if (start == null) return super.createBallisticSimulation(position, velocity);
    final moved = position.pixels / position.viewportDimension - start;
    final direction =
        velocity.abs() > _flick
            ? velocity.sign
            : moved.abs() > _distance
            ? moved.sign
            : 0.0;
    final target = (start + direction).roundToDouble() * position.viewportDimension;
    if ((target - position.pixels).abs() < toleranceFor(position).distance &&
        velocity.abs() < toleranceFor(position).velocity) {
      return null;
    }
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: toleranceFor(position));
  }
}
