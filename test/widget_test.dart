import 'dart:convert';

import 'package:deskmate/app/app_scope.dart';
import 'package:deskmate/app/demo_tour.dart';
import 'package:deskmate/app/focus_timer.dart';
import 'package:deskmate/app/phone_battery.dart';
import 'package:deskmate/app/settings.dart';
import 'package:deskmate/app/shell.dart';
import 'package:deskmate/ble/fake_mac_link.dart';
import 'package:deskmate/ble/mac_link.dart';
import 'package:deskmate/data/models.dart';
import 'package:deskmate/pages/home_page.dart';
import 'package:deskmate/theme/deskmate_tokens.dart';
import 'package:deskmate/ui/chrome.dart';
import 'package:deskmate/ui/rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// MacLink that never touches Bluetooth; tests feed it packets directly.
class TestLink extends MacLink {
  @override
  void start() {}

  void connect() => markConnected('test');
  void drop() {
    markLost('test drop');
    setLinkState(LinkState.reconnecting);
  }

  void feed(Map<String, Object?> json) => handlePacket(utf8.encode(jsonEncode(json)));
}

Future<void> pumpShell(
  WidgetTester tester,
  MacLink link, {
  Size dp = const Size(914, 411),
  PhoneBattery? battery,
}) async {
  tester.view.physicalSize = dp * 2.625; // Pixel-class landscape by default
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: DeskmateTokens.colorBlocks.toThemeData(),
      home: Shell(link: link, settings: SettingsController(), battery: battery ?? PhoneBattery(), timer: FocusTimer()),
    ),
  );
}

/// Taps a sidebar item, scrolling the rail to it first (the rail scrolls on short screens).
Future<void> openPage(WidgetTester tester, String label) async {
  final item = find.descendant(of: find.byType(Rail), matching: find.text(label));
  if (label != 'Settings') {
    final list = find.descendant(of: find.byType(Rail), matching: find.byType(Scrollable));
    await tester.drag(list, const Offset(0, 2000)); // back to the top
    await tester.pump();
    await tester.scrollUntilVisible(item, 40, scrollable: list);
  }
  await tester.tap(item.first);
  await tester.pump();
}

TestLink linkWithData() {
  final link = TestLink()..connect();
  link.feed({
    't': 'sys',
    'cpu': 85.0,
    'mem': 61.0,
    'cores': 8,
    'procs': [
      ['Google Chrome', 18.0],
    ],
  });
  link.feed({
    't': 'music',
    'title': 'Low Tide Static',
    'artist': 'Marlow Fen',
    'dur': 200,
    'pos': 50,
    'queue': [
      ['Next', 'A'],
    ],
  });
  link.feed({
    't': 'claude',
    'h5': 66.0,
    'h5Reset': 90,
    'wk': 39.0,
    'wkReset': 'Thu',
    'sessions': 2,
    'waiting': 1,
    'tokens7d': [1, 2, 3, 4, 5, 6, 7],
    'models': {'Opus': 0.6, 'Sonnet': 0.3, 'Haiku': 0.1},
  });
  link.feed({'t': 'event', 'title': 'Standup', 'start': 1795000000});
  link.feed({
    't': 'bluetooth',
    'scanning': true,
    'devices': [
      {'id': 'a', 'name': 'Earphones', 'kind': 'headphones', 'connected': true},
      {'id': 'b', 'name': 'Studio headphones', 'kind': 'headphones'},
      {'id': 'c', 'name': 'Earbuds', 'kind': 'headphones', 'paired': false},
    ],
  });
  link.feed({'t': 'wifi', 'on': true, 'ssid': 'Network name'});
  return link;
}

void main() {
  testWidgets('Home shows skeletons and the orange banner before the first connection', (tester) async {
    await pumpShell(tester, TestLink());
    expect(find.text('Looking for your computer on Wi-Fi…'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget); // rail label only; tiles are skeletons
  });

  testWidgets('Home fills tiles from Mac messages', (tester) async {
    final link = TestLink()..connect();
    link.feed({'t': 'sys', 'cpu': 23.4, 'mem': 61.0});
    link.feed({'t': 'claude', 'h5': 62.0});
    await pumpShell(tester, link);
    await tester.pump();
    expect(find.text('Looking for your computer on Wi-Fi…'), findsNothing);
    expect(find.text('62%'), findsWidgets);
    expect(find.text('Next up'), findsNothing, reason: 'no calendar tile on Home');
  });

  testWidgets('every designed page renders without overflow', (tester) async {
    final link = TestLink()..connect();
    link.feed({
      't': 'sys',
      'cpu': 23.4,
      'mem': 61.0,
      'procs': [
        ['Google Chrome', 18.0],
      ],
    });
    link.feed({
      't': 'music',
      'title': 'Song',
      'artist': 'Artist',
      'dur': 200,
      'pos': 50,
      'queue': [
        ['Next', 'A'],
      ],
    });
    link.feed({
      't': 'claude',
      'h5': 62.0,
      'tokens7d': [1, 2, 3, 4, 5, 6, 7],
      'models': {'Opus': 0.6},
    });
    await pumpShell(tester, link);
    for (final label in ['Claude', 'Music', 'System', 'Control', 'Timer', 'Calendar', 'Settings', 'Home']) {
      await openPage(tester, label);
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  test('Home layout rotates every 10 minutes between the selected layouts', () {
    final both = {HomeLayout.a, HomeLayout.b};
    final t0 = DateTime.fromMillisecondsSinceEpoch(0);
    expect(HomePage.layoutAt(t0, both), HomeLayout.a);
    expect(HomePage.layoutAt(t0.add(const Duration(minutes: 10)), both), HomeLayout.b);
    expect(HomePage.layoutAt(t0.add(const Duration(minutes: 20)), both), HomeLayout.a);
    expect(HomePage.layoutAt(t0.add(const Duration(minutes: 10)), {HomeLayout.b}), HomeLayout.b);
  });

  test('step-1 packets without a topic still update CPU', () {
    final board = BoardData()..apply({'seq': 1, 'cpu': 42.0});
    expect(board.system?.cpu, 42.0);
    expect(board.cpuHistory, [42.0]);
  });

  test('focus timer counts down and finishes a session', () {
    var now = DateTime(2026, 11, 23, 10);
    final timer = FocusTimer(clock: () => now)..select(FocusTimer.presets[0]); // 5 min
    timer.start();
    now = now.add(const Duration(minutes: 2));
    timer.pause();
    expect(timer.remaining, const Duration(minutes: 3));
    timer.dispose();
  });

  testWidgets('demo tour walks every link state, page and battery warning, 10 s each', (tester) async {
    final link = FakeMacLink();
    final battery = PhoneBattery(simulate: true);
    final tour = DemoTour(link: link, battery: battery);
    final states = <String>{}, pages = <PageId>{}, batteries = <(int?, bool)>{};
    link.addListener(() => states.add(link.macAsleep ? 'asleep' : link.state.name));
    battery.addListener(() => batteries.add((battery.level, battery.charging)));
    tour.addListener(() => pages.add(tour.step.page));
    link.start();
    battery.start();
    tour.start();
    expect(tour.stepLength, const Duration(seconds: 10));
    for (var s = 0; s < DemoTour.steps.length * 10; s++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(states, containsAll(['notPaired', 'scanning', 'connecting', 'connected', 'reconnecting', 'asleep']));
    expect(
      pages,
      containsAll([
        PageId.home,
        PageId.claude,
        PageId.music,
        PageId.system,
        PageId.control,
        PageId.timer,
        PageId.settings,
      ]),
    );
    expect(batteries, containsAll([(24, false), (82, true)]));
    expect(tour.index, 0, reason: 'loops back to the start');
    tour.dispose();
    link.dispose();
    battery.dispose();
  });

  // Screens from small phones up to the Poco/Pixel, with both banners (the
  // tightest case): nothing may overflow on any page or Home layout.
  for (final dp in const [Size(914, 411), Size(851, 393), Size(780, 360), Size(700, 320)]) {
    testWidgets('no overflow at ${dp.width.round()}×${dp.height.round()} with two banners', (tester) async {
      final link = linkWithData()..drop();
      final battery =
          PhoneBattery()
            ..level = 82
            ..charging = true;
      await pumpShell(tester, link, dp: dp, battery: battery);
      expect(find.textContaining('Reconnecting'), findsOneWidget);
      expect(find.textContaining('Unplug'), findsOneWidget);
      for (final label in ['Home', 'Claude', 'Music', 'System', 'Control', 'Timer', 'Settings']) {
        await openPage(tester, label);
        expect(tester.takeException(), isNull, reason: '$label at $dp');
        expect(find.text(label), findsWidgets);
      }
    });
  }

  test('Bluetooth: the connected audio device is the active one; unpaired ones are nearby', () {
    final board =
        BoardData()..apply({
          't': 'bluetooth',
          'devices': [
            {'id': 'k', 'name': 'Keyboard', 'kind': 'keyboard', 'connected': true},
            {'id': 'e', 'name': 'Earphones', 'kind': 'headphones', 'connected': true},
            {'id': 'n', 'name': 'Speaker', 'kind': 'speaker', 'paired': false},
          ],
        });
    expect(board.bluetooth!.active!.name, 'Earphones');
    expect(board.bluetooth!.nearby.map((d) => d.name), ['Speaker']);
  });

  test('focus timer defaults to 10 minutes', () {
    expect(FocusTimer().remaining, const Duration(minutes: 10));
  });

  test('clock sync follows the computer: offset and time zone', () {
    final link = TestLink()..connect();
    final hubNow = DateTime.now().toUtc().add(const Duration(minutes: 7));
    link.feed({'t': 'time', 'ts': hubNow.millisecondsSinceEpoch, 'tz': 330}); // UTC+5:30
    final shown = link.now();
    final expected = hubNow.add(const Duration(minutes: 330));
    expect(shown.difference(expected).inSeconds.abs(), lessThan(2));
    expect(link.clockOffset.inSeconds, closeTo(420, 2));
  });

  test('a locked computer shows the night clock even while still connected', () {
    final link = TestLink()..connect();
    link.feed({'t': 'power', 'asleep': true});
    expect(link.macAsleep, isTrue);
    link.feed({'t': 'power', 'asleep': false});
    expect(link.macAsleep, isFalse);
  });

  test('messages split into parts are rebuilt before parsing', () {
    final link = TestLink()..connect();
    final full = base64Encode(utf8.encode(jsonEncode({'t': 'claude', 'sessions': 7})));
    final half = full.length ~/ 2;
    link.feed({'t': 'part', 'id': 3, 'i': 1, 'n': 2, 'd': full.substring(half)});
    expect(link.board.claude, isNull);
    link.feed({'t': 'part', 'id': 3, 'i': 0, 'n': 2, 'd': full.substring(0, half)});
    expect(link.board.claude?.sessions, 7);
  });

  testWidgets('pairing page has its own number pad (no system keyboard) and fills the code', (tester) async {
    final link = TestLink();
    await pumpShell(tester, link);
    await openPage(tester, 'Settings');
    await tester.ensureVisible(find.text('Wi-Fi link')); // Settings scrolls on short screens
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wi-Fi link'));
    await tester.pumpAndSettle();
    expect(find.text('Pair with your computer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    for (final d in ['4', '8', '2', '9', '1', '3']) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    // 4, 8 and 9 aren't step numbers, so they appear exactly twice: keypad + code box.
    for (final d in ['4', '8', '9']) {
      expect(find.text(d), findsNWidgets(2), reason: 'digit $d on the keypad and in the code boxes');
    }
  });

  test('closing the unplug banner hides it until the next 10% step; 100% can\'t be closed', () {
    expect(unplugSnoozeUntil(74), 80);
    expect(unplugSnoozeUntil(80), 90);
    expect(unplugSnoozeUntil(95), 100);
    const t = DeskmateTokens.colorBlocks;
    InfoBanner? banner(int level, int? snoozed) =>
        batteryBanner(t, level, true, 30, 70, snoozedUntil: snoozed, onClose: () {}) as InfoBanner?;
    expect(banner(74, null)?.onClose, isNotNull);
    expect(banner(78, 80), isNull);
    expect(banner(80, 80), isNotNull);
    expect(banner(100, 100)?.onClose, isNull);
  });
}
