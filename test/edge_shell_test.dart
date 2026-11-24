import 'package:deskmate/app/app_scope.dart';
import 'package:deskmate/app/feature_registry.dart';
import 'package:deskmate/app/focus_timer.dart';
import 'package:deskmate/app/phone_battery.dart';
import 'package:deskmate/app/settings.dart';
import 'package:deskmate/app/shell.dart';
import 'package:deskmate/theme/deskmate_tokens.dart';
import 'package:deskmate/pages/edge/edge_timer.dart' show dialTicks, litTicks, tickState;
import 'package:deskmate/ui/page_dots.dart';
import 'package:deskmate/ui/rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show TestLink;

void main() {
  group('timer ticks', () {
    List<int> litAt(int lit) => [
      for (var i = 0; i < 60; i++)
        if (tickState(i, lit) != null) i,
    ];
    double mix(int i, int lit) => tickState(i, lit)!.mix;

    test('everything is active at the start, then 59, 58, 57 … go dark', () {
      expect(litAt(60).length, 60);
      expect(litAt(59), [for (var i = 0; i < 59; i++) i]);
      expect(litAt(25), [for (var i = 0; i < 25; i++) i]);
      for (final i in litAt(25)) {
        expect(mix(i, 25), 1); // no fade yet
      }
    });

    test('at 20 nothing has changed: 0 .. 19 are solid', () {
      expect(litAt(20), [for (var i = 0; i < 20; i++) i]);
      expect(mix(0, 20), 1);
      expect(tickState(59, 20), isNull);
    });

    test('19 .. 15: tick 59, 58, 57, 56, 55 appear, fading from blue to grey', () {
      expect(mix(59, 19), 0.85);
      expect(tickState(58, 19), isNull);
      expect(mix(59, 18), 0.85); // stays like the last step
      expect(mix(58, 18), 0.68);
      expect(mix(57, 17), 0.5); // half and half
      expect(mix(58, 17), 0.68);
      expect(mix(56, 16), 0.28); // more towards grey
      expect(mix(55, 15), 0); // only grey
      expect(mix(59, 15), 0.85);
      for (var lit = 15; lit <= 19; lit++) {
        expect(litAt(lit).length, 20, reason: 'always 20 ticks lit at $lit');
      }
    });

    test('14 and below: 59 turns solid and the fade moves on, one tick per second', () {
      expect(mix(59, 14), 1); // solid now
      expect(mix(58, 14), 0.85);
      expect(mix(54, 14), 0);
      expect(mix(58, 13), 1);
      expect(mix(59, 13), 1);
      expect(mix(57, 13), 0.85);
      expect(mix(41, 1), 0); // the grey end of the fade, near the end of the minute
      expect(mix(45, 1), 0.85);
      for (var lit = 1; lit <= 14; lit++) {
        expect(litAt(lit).length, 20, reason: 'always 20 ticks lit at $lit');
      }
      expect(litAt(0), isEmpty);
    });

    test('after the first minute it never resets: the 20 ticks keep going round', () {
      const total = Duration(minutes: 10);
      // The first minute: full at the start, then the collapse described above.
      expect(dialTicks(total, total), (lit: 60, snake: false));
      expect(dialTicks(const Duration(minutes: 9, seconds: 41), total), (lit: 41, snake: false));
      expect(dialTicks(const Duration(minutes: 9, seconds: 1), total), (lit: 1, snake: false));
      // At 09:00 the old behaviour jumped back to a full ring; now the snake carries on.
      expect(dialTicks(const Duration(minutes: 9), total), (lit: 0, snake: true));
      expect(dialTicks(const Duration(minutes: 8, seconds: 59), total), (lit: 59, snake: true));
      expect(dialTicks(const Duration(minutes: 8, seconds: 30), total), (lit: 30, snake: true));
      for (var c = 0; c < 60; c++) {
        final lit = [
          for (var i = 0; i < 60; i++)
            if (tickState(i, c, snake: true) != null) i,
        ];
        expect(lit.length, 20, reason: 'snake at $c');
        expect(tickState((c - 1) % 60, c, snake: true)!.head, isTrue);
      }
      // c = 0: ticks 40 .. 59 (the fade is 40 .. 44, the head is 59), continuing from 1 → 0 → 59.
      expect(tickState(59, 0, snake: true)!.mix, 1);
      expect(tickState(44, 0, snake: true)!.mix, 0.85);
      expect(tickState(40, 0, snake: true)!.mix, 0);
      expect(tickState(39, 0, snake: true), isNull);
      expect(tickState(0, 0, snake: true), isNull);
    });

    test('the head is thick', () {
      expect(tickState(19, 20)!.head, isTrue);
      expect(tickState(16, 20)!.head, isFalse);
      expect(tickState(11, 12)!.head, isTrue);
    });
  });

  test('Timer ticks count the seconds: a full sweep every minute', () {
    expect(litTicks(const Duration(minutes: 10)), 60);
    expect(litTicks(const Duration(minutes: 9, seconds: 59)), 59);
    expect(litTicks(const Duration(minutes: 7, seconds: 42)), 42);
    expect(litTicks(const Duration(minutes: 7)), 60);
    expect(litTicks(const Duration(seconds: 1)), 1);
    expect(litTicks(Duration.zero), 0);
  });

  test('Edge tabs come from the registry, Settings last', () {
    expect(edgeTabs(), [
      PageId.home,
      PageId.claude,
      PageId.music,
      PageId.system,
      PageId.control,
      PageId.timer,
      PageId.settings,
    ]);
  });

  test('Settings stays last even if the registry lists it earlier', () {
    final reordered = [
      const FeatureDescriptor(PageId.settings, edgeTab: true),
      const FeatureDescriptor(PageId.music, edgeTab: true),
      const FeatureDescriptor(PageId.home, edgeTab: true),
      const FeatureDescriptor(PageId.weather),
    ];
    expect(edgeTabs(reordered), [PageId.music, PageId.home, PageId.settings]);
  });

  testWidgets('switching to Edge slides the sidebar out and the dots in, and back', (tester) async {
    tester.view.physicalSize = const Size(914, 411) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final settings = SettingsController();
    await tester.pumpWidget(
      MaterialApp(
        theme: DeskmateTokens.colorBlocks.toThemeData(),
        home: Shell(link: TestLink()..connect(), settings: settings, battery: PhoneBattery(), timer: FocusTimer()),
      ),
    );

    double railWidth() =>
        tester.getSize(find.ancestor(of: find.byType(Rail), matching: find.byType(ClipRect)).first).width;
    double dotsOpacity() {
      final o = find.ancestor(of: find.byType(PageDots), matching: find.byType(Opacity));
      return o.evaluate().isEmpty ? 0 : tester.widget<Opacity>(o.first).opacity;
    }

    // Color Blocks: sidebar, no dots.
    expect(railWidth(), greaterThan(60));
    expect(dotsOpacity(), 0);

    settings.setTheme(ThemeId.edge);
    await tester.pump(); // rebuild; the animation starts after this frame
    await tester.pump(); // its first tick
    await tester.pump(const Duration(milliseconds: 250)); // halfway: no hard jump
    expect(railWidth(), allOf(greaterThan(0), lessThan(86)));
    expect(dotsOpacity(), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(railWidth(), 0);
    expect(dotsOpacity(), 1);
    // The page height doesn't change: the pages sit under the dots, not above them.
    expect(tester.getSize(find.byType(PageView)).height, tester.view.physicalSize.height / 2.625 - 0);
    expect(tester.widget<PageDots>(find.byType(PageDots)).count, 7);

    // Swipe to the next tab.
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).active, 1);

    // A light, slow swipe (about 8% of the width) still switches the tab.
    await tester.drag(find.byType(PageView), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).active, 2);
    await tester.drag(find.byType(PageView), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).active, 1);

    // Tabs loop: back to the first, then one more swipe right wraps to the last (Settings).
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).active, 0);
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).active, 6);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).active, 0);

    settings.setTheme(ThemeId.colorBlocks);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(railWidth(), greaterThan(60));
    expect(dotsOpacity(), 0);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('Edge Home shows the five rings and every element opens its tab', (tester) async {
    tester.view.physicalSize = const Size(915, 412) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final settings = SettingsController()..theme = ThemeId.edge;
    final link = TestLink()..connect();
    link.feed({'t': 'sys', 'cpu': 23.0, 'mem': 61.0, 'cores': 8});
    await tester.pumpWidget(
      MaterialApp(
        theme: DeskmateTokens.edge.toThemeData(),
        home: Shell(link: link, settings: settings, battery: PhoneBattery(), timer: FocusTimer()),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['CLAUDE', 'WEEKLY', 'CPU', 'MEMORY', 'TIMER']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('23'), findsOneWidget); // CPU ring value
    expect(tester.takeException(), isNull);

    int active() => tester.widget<PageDots>(find.byType(PageDots)).active;
    final taps = {'CPU': 3, 'CLAUDE': 1, 'TIMER': 5};
    for (final e in taps.entries) {
      await tester.tap(find.text(e.key));
      await tester.pumpAndSettle();
      expect(active(), e.value, reason: '${e.key} ring');
      // Back to Home (first tab) by swiping.
      while (active() != 0) {
        await tester.drag(find.byType(PageView), const Offset(600, 0));
        await tester.pumpAndSettle();
      }
    }
  });

  for (final dp in const [Size(915, 412), Size(851, 393), Size(780, 360), Size(700, 320)]) {
    testWidgets('Edge Home has no overflow at ${dp.width.round()}×${dp.height.round()} with banners', (tester) async {
      tester.view.physicalSize = dp * 2.625;
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      Shell.hideUnplugBanner = false;
      final link = TestLink()..connect();
      link.feed({'t': 'sys', 'cpu': 23.0, 'mem': 61.0, 'cores': 8});
      link.feed({
        't': 'music',
        'title': 'A fairly long song title for the board',
        'artist': 'Artist',
        'album': 'Album',
        'playing': true,
        'pos': 80,
        'dur': 232,
      });
      link.drop();
      final battery =
          PhoneBattery()
            ..level = 82
            ..charging = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: DeskmateTokens.edge.toThemeData(),
          home: Shell(
            link: link,
            settings: SettingsController()..theme = ThemeId.edge,
            battery: battery,
            timer: FocusTimer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Unplug'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dp in const [Size(915, 412), Size(780, 360), Size(700, 320)]) {
    testWidgets('Edge Claude shows the limits and has no overflow at ${dp.width.round()}×${dp.height.round()}', (
      tester,
    ) async {
      tester.view.physicalSize = dp * 2.625;
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      Shell.hideUnplugBanner = false;
      final link = TestLink()..connect();
      link.feed({
        't': 'claude',
        'h5': 62.0,
        'h5Reset': 108,
        'h5Est': true,
        'b5Tokens': 1300000,
        'b5StartHour': 9,
        'b5Hours': [880000, 280000, 120000, 20000, 0],
        'wk': 38.0,
        'wkReset': 'Thu',
        'wkResetTime': 930,
        'sessions': 2,
        'waiting': 1,
        'models': {'Opus': 0.64, 'Sonnet': 0.30, 'Haiku': 0.06},
        'tokens7d': [400000, 650000, 300000, 800000, 550000, 250000, 1200000],
      });
      final battery =
          PhoneBattery()
            ..level = 82
            ..charging = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: DeskmateTokens.edge.toThemeData(),
          home: Shell(
            link: link,
            settings: SettingsController()..theme = ThemeId.edge,
            battery: battery,
            timer: FocusTimer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLAUDE'));
      await tester.pumpAndSettle();
      expect(find.text('62'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('5-hour block · 1.3M'.toUpperCase()), findsOneWidget);
      expect(find.text('9'), findsOneWidget); // first hour of the block
      expect(find.text('Resets in ~1h 48m'), findsOneWidget); // from the logs: approximate
      expect(find.text('Resets Thu · 3:30 PM'), findsOneWidget);
      expect(find.text('1 waiting for you'), findsOneWidget);
      expect(find.text('1.2M'), findsOneWidget); // tokens today
      // Tap an earlier day: its tokens replace today's.
      await tester.tap(find.bySemanticsLabel(RegExp('650K tokens')), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dp in const [Size(915, 412), Size(780, 360), Size(700, 320)]) {
    testWidgets(
      'Edge Music shows the song, queue and listening timer, no overflow at ${dp.width.round()}×${dp.height.round()}',
      (tester) async {
        tester.view.physicalSize = dp * 2.625;
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        Shell.hideUnplugBanner = false;
        final link = TestLink()..connect();
        link.feed({
          't': 'music',
          'title': 'A fairly long song title for the board',
          'artist': 'Artist',
          'album': 'Album',
          'playing': true,
          'pos': 84,
          'dur': 232,
          'vol': 0.6,
          'liked': true,
          'prev': [
            ['Previous track', 'Old Artist', 0],
          ],
          'next': [
            ['Next track', 'A', 2],
            ['Third', 'B', 3],
            ['Fourth', 'C', 4],
          ],
        });
        link.drop();
        final battery =
            PhoneBattery()
              ..level = 82
              ..charging = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: DeskmateTokens.edge.toThemeData(),
            home: Shell(
              link: link,
              settings: SettingsController()..theme = ThemeId.edge,
              battery: battery,
              timer: FocusTimer(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Home's music block opens the Music tab.
        await tester.tap(find.text('YOUTUBE MUSIC').first);
        await tester.pumpAndSettle();
        expect(find.text('NOW PLAYING'), findsOneWidget);
        expect(find.text('VOLUME'), findsNothing);
        expect(find.text('Previous track'), findsOneWidget);
        expect(find.text('Fourth'), findsOneWidget);
        expect(find.text('1:24'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dp in const [Size(915, 412), Size(780, 360), Size(700, 320)]) {
    testWidgets('Edge System shows rings, processes and no overflow at ${dp.width.round()}×${dp.height.round()}', (
      tester,
    ) async {
      tester.view.physicalSize = dp * 2.625;
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      Shell.hideUnplugBanner = false;
      final link = TestLink()..connect();
      for (var i = 0; i < 20; i++) {
        link.feed({
          't': 'sys',
          'cpu': 20.0 + i,
          'mem': 61.0,
          'memUsed': 9.8,
          'memTotal': 16.0,
          'cores': 8,
          'energy': 'Low',
          'onPower': true,
          'disk': 4.2,
          'diskFree': 212.0,
          'down': 1200.0,
          'up': 80.0,
          'procs': [
            ['Google Chrome', 18.0],
            ['Xcode', 9.0],
            ['Claude', 6.0],
            ['Slack', 3.0],
            ['WindowServer', 2.0],
          ],
          'mprocs': [
            ['Google Chrome', 3418],
            ['Xcode', 1520],
            ['Claude', 512],
            ['Terminal', 300],
            ['Slack', 200],
          ],
        });
      }
      link.drop();
      final battery =
          PhoneBattery()
            ..level = 82
            ..charging = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: DeskmateTokens.edge.toThemeData(),
          home: Shell(
            link: link,
            settings: SettingsController()..theme = ThemeId.edge,
            battery: battery,
            timer: FocusTimer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('MEMORY'));
      await tester.pumpAndSettle();
      expect(find.text('TOP CPU'), findsOneWidget);
      expect(find.text('TOP MEMORY'), findsOneWidget);
      expect(find.text('Google Chrome'), findsNWidgets(2)); // in both lists
      expect(find.text('18%'), findsOneWidget);
      expect(find.text('3.3 GB'), findsOneWidget); // Chrome's memory
      expect(find.text('512 MB'), findsOneWidget);
      expect(find.text('WindowServer'), findsOneWidget); // the 5th app by CPU
      expect(find.text('Terminal'), findsOneWidget); // the 4th app by memory
      expect(find.text('200 MB'), findsOneWidget); // the 5th app by memory
      expect(find.text('ENERGY'), findsOneWidget);
      expect(find.text('9.8 of 16 GB'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dp in const [Size(915, 412), Size(780, 360), Size(700, 320)]) {
    testWidgets(
      'Edge Control Center shows the device, Wi-Fi and lists, no overflow at ${dp.width.round()}×${dp.height.round()}',
      (tester) async {
        tester.view.physicalSize = dp * 2.625;
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        Shell.hideUnplugBanner = false;
        final link = TestLink()..connect();
        link.feed({
          't': 'bluetooth',
          'devices': [
            {'id': 'a', 'name': 'Earphones', 'kind': 'headphones', 'connected': true, 'paired': true},
            {'id': 'b', 'name': 'Studio headphones', 'kind': 'headphones', 'connected': false, 'paired': true},
            {'id': 'c', 'name': 'Keyboard', 'kind': 'keyboard', 'connected': true, 'paired': true},
            {'id': 'd', 'name': 'Speaker', 'kind': 'speaker', 'connected': false, 'paired': false},
          ],
        });
        link.feed({'t': 'wifi', 'on': true, 'ssid': 'Office'});
        link.drop();
        final battery =
            PhoneBattery()
              ..level = 82
              ..charging = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: DeskmateTokens.edge.toThemeData(),
            home: Shell(
              link: link,
              settings: SettingsController()..theme = ThemeId.edge,
              battery: battery,
              timer: FocusTimer(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Swipe to Control Center (the 5th tab).
        for (var i = 0; i < 4; i++) {
          await tester.drag(find.byType(PageView), const Offset(-600, 0));
          await tester.pumpAndSettle();
        }
        expect(find.text('Earphones'), findsWidgets);
        expect(find.text('Disconnect'), findsOneWidget);
        expect(find.text('Switch device'), findsOneWidget);
        expect(find.text('Office'), findsOneWidget);
        expect(find.text('Pair'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dp in const [Size(915, 412), Size(780, 360), Size(700, 320)]) {
    testWidgets('Edge Timer: presets, start and reset work, no overflow at ${dp.width.round()}×${dp.height.round()}', (
      tester,
    ) async {
      tester.view.physicalSize = dp * 2.625;
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      Shell.hideUnplugBanner = false;
      final link = TestLink()..connect();
      link.drop();
      final timer = FocusTimer();
      addTearDown(timer.dispose);
      final battery =
          PhoneBattery()
            ..level = 82
            ..charging = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: DeskmateTokens.edge.toThemeData(),
          home: Shell(link: link, settings: SettingsController()..theme = ThemeId.edge, battery: battery, timer: timer),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TIMER')); // Home's Timer ring opens the Timer tab
      await tester.pumpAndSettle();
      expect(tester.widget<PageDots>(find.byType(PageDots)).active, 5);
      expect(find.text('10:00'), findsOneWidget); // the Focus preset: 10 minutes by default
      expect(find.text('FOCUS · READY'), findsOneWidget);
      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('SESSION 1 OF 4'), findsOneWidget);

      await tester.tap(find.text('Short break'));
      await tester.pumpAndSettle();
      expect(find.text('05:00'), findsOneWidget);
      expect(timer.preset.name, 'Short break');

      await tester.tap(find.bySemanticsLabel('Start'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
      timer.start();
      await tester.pump(const Duration(seconds: 2));
      expect(timer.running, isTrue);
      timer.reset();
      await tester.pumpAndSettle();
      expect(find.text('05:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  Future<(SettingsController, Shell)> pumpEdgeSettings(WidgetTester tester, Size dp) async {
    tester.view.physicalSize = dp * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    Shell.hideUnplugBanner = false;
    final link = TestLink()..connect();
    link.drop();
    final settings = SettingsController()..theme = ThemeId.edge;
    final battery =
        PhoneBattery()
          ..level = 82
          ..charging = true;
    final shell = Shell(link: link, settings: settings, battery: battery, timer: FocusTimer());
    await tester.pumpWidget(MaterialApp(theme: DeskmateTokens.edge.toThemeData(), home: shell));
    await tester.pumpAndSettle();
    // One swipe right from Home wraps round to the last tab, Settings.
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    return (settings, shell);
  }

  for (final dp in const [Size(915, 412), Size(780, 360), Size(700, 320)]) {
    testWidgets(
      'Edge Settings: theme, then the settings below it, no layouts, no overflow at ${dp.width.round()}×${dp.height.round()}',
      (tester) async {
        final (settings, _) = await pumpEdgeSettings(tester, dp);
        expect(tester.widget<PageDots>(find.byType(PageDots)).active, 6);
        expect(find.text('THEME'), findsOneWidget);
        expect(find.text('Wi-Fi link'), findsOneWidget);
        expect(find.text('Tab order'), findsOneWidget);
        expect(find.text('Battery warnings'), findsOneWidget);
        expect(find.text('Time format'), findsOneWidget);
        expect(find.text('HOME LAYOUTS'), findsNothing); // layouts are only for the sidebar themes
        expect(find.text('App settings'), findsNothing); // no sub page: everything is on this page
        expect(find.text('Night clock when Mac sleeps'), findsNothing);
        expect(tester.takeException(), isNull);

        expect(settings.use24h, isFalse);
        await tester.tap(find.text('24-hour'));
        await tester.pump();
        expect(settings.use24h, isTrue);
        await tester.tap(find.text('12-hour'));
        await tester.pump();
        expect(settings.use24h, isFalse);
      },
    );
  }

  testWidgets('switching theme on the Settings tab fades the old Settings into the new one', (tester) async {
    final (settings, _) = await pumpEdgeSettings(tester, const Size(915, 412));
    expect(find.text('THEME'), findsOneWidget); // Edge Settings

    settings.setTheme(ThemeId.colorBlocks);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // half way: both pages are on screen
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('Home layouts'), findsOneWidget); // the sidebar theme's Settings fading in
    await tester.pumpAndSettle();
    expect(find.text('THEME'), findsNothing);
    expect(find.text('Home layouts'), findsOneWidget);
    expect(find.text('Night clock when Mac sleeps'), findsNothing); // removed in the old Settings too
    expect(find.text('Wi-Fi link'), findsOneWidget); // the other old items are still there
    expect(find.text('Time format'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    settings.setTheme(ThemeId.edge);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Home layouts'), findsOneWidget);
    expect(find.text('THEME'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('Home layouts'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
