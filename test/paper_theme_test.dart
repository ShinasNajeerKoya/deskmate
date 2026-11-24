import 'package:deskmate/app/focus_timer.dart';
import 'package:deskmate/app/phone_battery.dart';
import 'package:deskmate/app/settings.dart';
import 'package:deskmate/app/shell.dart';
import 'package:deskmate/theme/deskmate_tokens.dart';
import 'package:deskmate/ui/rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show TestLink;

TestLink dataLink() {
  final link = TestLink()..connect();
  link.feed({
    't': 'sys',
    'cpu': 23.0,
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
      ['Terminal', 3.0],
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
  link.feed({
    't': 'music',
    'title': 'A fairly long song title for the board',
    'artist': 'Artist',
    'album': 'Album',
    'playing': true,
    'pos': 84,
    'dur': 232,
    'prev': [
      ['Previous track', 'Old Artist', 0],
    ],
    'next': [
      ['Next track', 'A', 2],
      ['Third', 'B', 3],
      ['Fourth', 'C', 4],
    ],
  });
  link.feed({
    't': 'claude',
    'h5': 62.0,
    'h5Reset': 108,
    'wk': 38.0,
    'wkReset': 'Thu',
    'wkResetTime': 930,
    'sessions': 2,
    'waiting': 1,
    'models': {'Opus': 0.64, 'Sonnet': 0.30, 'Haiku': 0.06},
    'tokens7d': [400000, 650000, 300000, 800000, 550000, 250000, 1200000],
  });
  link.feed({
    't': 'bluetooth',
    'devices': [
      {'id': 'a', 'name': 'Earphones', 'kind': 'headphones', 'connected': true, 'paired': true},
      {'id': 'b', 'name': 'Studio headphones', 'kind': 'headphones', 'connected': false, 'paired': true},
      {'id': 'd', 'name': 'Speaker', 'kind': 'speaker', 'connected': false, 'paired': false},
    ],
  });
  link.feed({'t': 'wifi', 'on': true, 'ssid': 'Office'});
  return link;
}

Future<SettingsController> pumpPaper(
  WidgetTester tester,
  Size dp, {
  Set<HomeLayout>? layouts,
  bool banners = true,
}) async {
  tester.view.physicalSize = dp * 2.625;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  Shell.hideUnplugBanner = false;
  final link = dataLink();
  if (banners) link.drop();
  final settings = SettingsController()..theme = ThemeId.paper;
  if (layouts != null) settings.homeLayouts = layouts;
  final battery =
      PhoneBattery()
        ..level = banners ? 82 : 50
        ..charging = banners;
  final timer = FocusTimer();
  addTearDown(timer.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: DeskmateTokens.paper.toThemeData(),
      home: Shell(link: link, settings: settings, battery: battery, timer: timer),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Future<void> openPaperPage(WidgetTester tester, String label) async {
  final item = find.descendant(of: find.byType(Rail), matching: find.text(label));
  if (label != 'Settings') {
    // The rail scrolls on short screens: bring the item into view first.
    final list = find.descendant(of: find.byType(Rail), matching: find.byType(Scrollable));
    await tester.drag(list, const Offset(0, 2000));
    await tester.pump();
    await tester.scrollUntilVisible(item, 40, scrollable: list);
  }
  await tester.tap(item.first);
  await tester.pumpAndSettle();
}

void main() {
  test('Layout C is only for Paper so far; a saved C is skipped on Color Blocks', () {
    expect(HomeLayout.c.availableIn(ThemeId.paper), isTrue);
    expect(HomeLayout.c.availableIn(ThemeId.colorBlocks), isFalse);
    final s =
        SettingsController()
          ..theme = ThemeId.colorBlocks
          ..homeLayouts = {HomeLayout.a, HomeLayout.c};
    expect(s.activeLayouts, {HomeLayout.a});
    s.homeLayouts = {HomeLayout.c};
    expect(s.activeLayouts, {HomeLayout.a}); // never empty
    s.theme = ThemeId.paper;
    expect(s.activeLayouts, {HomeLayout.c});
  });

  for (final dp in const [Size(915, 412), Size(780, 360), Size(700, 320)]) {
    final size = '${dp.width.round()}×${dp.height.round()}';
    for (final layout in HomeLayout.values) {
      testWidgets('Paper Home layout ${layout.label} has no overflow at $size with banners', (tester) async {
        await pumpPaper(tester, dp, layouts: {layout});
        expect(find.text('Home'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every Paper page renders without overflow at $size with banners', (tester) async {
      await pumpPaper(tester, dp);
      for (final label in ['Claude', 'Music', 'System', 'Control', 'Timer', 'Settings', 'Home']) {
        await openPaperPage(tester, label);
        expect(tester.takeException(), isNull, reason: '$label at $size');
      }
    });
  }

  testWidgets('the Paper sidebar lists only the designed pages, Settings apart', (tester) async {
    await pumpPaper(tester, const Size(915, 412), banners: false);
    final rail = find.byType(Rail);
    for (final label in ['Home', 'Claude', 'Music', 'System', 'Control', 'Timer', 'Settings']) {
      expect(find.descendant(of: rail, matching: find.text(label)), findsOneWidget, reason: label);
    }
    for (final label in ['Calendar', 'Weather', 'Shortcuts', 'GitHub']) {
      expect(find.descendant(of: rail, matching: find.text(label)), findsNothing, reason: label);
    }
  });

  testWidgets('Paper pages show their data', (tester) async {
    await pumpPaper(tester, const Size(915, 412), banners: false);
    await openPaperPage(tester, 'Claude');
    expect(find.text('62'), findsOneWidget);
    expect(find.text('Resets Thu · 3:30 PM'.toUpperCase()), findsOneWidget);
    expect(find.text('1 waiting for you'), findsOneWidget);
    await openPaperPage(tester, 'System');
    expect(find.text('TOP CPU'), findsOneWidget);
    expect(find.text('TOP MEMORY'), findsOneWidget);
    expect(find.text('3.3 GB'), findsOneWidget);
    await openPaperPage(tester, 'Control');
    expect(find.text('Earphones'), findsWidgets);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    await openPaperPage(tester, 'Timer');
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Short break'), findsOneWidget);
  });

  testWidgets('Paper Settings: Layout C can be switched on, and Sidebar opens the future pages', (tester) async {
    final settings = await pumpPaper(tester, const Size(915, 412), banners: false);
    await openPaperPage(tester, 'Settings');
    expect(find.text('Layout C'), findsOneWidget);
    expect(settings.homeLayouts, {HomeLayout.a, HomeLayout.b});
    await tester.tap(find.text('Layout C'));
    await tester.pump();
    expect(settings.homeLayouts, {HomeLayout.a, HomeLayout.b, HomeLayout.c});

    await tester.tap(find.text('Sidebar'));
    await tester.pumpAndSettle();
    for (final label in ['Calendar', 'Weather', 'Shortcuts', 'GitHub']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('NOT DESIGNED YET'), findsNWidgets(4));
    // The round back button at the top left returns to Settings.
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Back to Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Layout C'), findsOneWidget);
    handle.dispose();
    expect(tester.takeException(), isNull);
  });
}
