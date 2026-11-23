import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/fake_mac_link.dart';
import 'app_scope.dart';
import 'phone_battery.dart';

class DemoStep {
  const DemoStep(this.name, this.enter, {this.page = PageId.home, this.battery = (64, false)});

  final String name;
  final void Function(FakeMacLink link) enter;
  final PageId page;
  final (int, bool) battery; // (level %, charging)
}

/// Simulator/emulator demo: walks through every link state and every page,
/// one step at a time, then loops. Prints a countdown in the terminal
/// (`flutter run` output) so you can tell which step you're looking at.
class DemoTour extends ChangeNotifier {
  DemoTour({required this.link, required this.battery, this.stepLength = const Duration(seconds: 10)});

  final FakeMacLink link;
  final PhoneBattery battery;
  final Duration stepLength;

  static final steps = <DemoStep>[
    DemoStep('Not paired yet (orange "Pair with your computer" banner)', (l) => l.showNotPaired()),
    DemoStep('Looking for your computer on Wi-Fi (skeleton tiles)', (l) => l.showLooking()),
    DemoStep('Connecting', (l) => l.showConnecting()),
    DemoStep('Connected · Home', (l) => l.showConnected()),
    DemoStep('Connected · Claude page', (l) => l.showConnected(), page: PageId.claude),
    DemoStep('Connected · Music page', (l) => l.showConnected(), page: PageId.music),
    DemoStep('Connected · System page', (l) => l.showConnected(), page: PageId.system),
    DemoStep('Connected · Control Center (Bluetooth, Wi-Fi)', (l) => l.showConnected(), page: PageId.control),
    DemoStep('Connected · Timer page', (l) => l.showConnected(), page: PageId.timer),
    DemoStep('Connected · Settings page', (l) => l.showConnected(), page: PageId.settings),
    DemoStep('Battery low: "plug in" banner', (l) => l.showConnected(), battery: (24, false)),
    DemoStep('Battery high: "unplug" banner', (l) => l.showConnected(), battery: (82, true)),
    DemoStep('Link dropped: reconnecting (blue banner, board stays)', (l) => l.showDrop()),
    DemoStep('Reconnected', (l) => l.showConnected()),
    DemoStep('Computer asleep or locked: night clock', (l) => l.showMacAsleep()),
    DemoStep('Computer awake again', (l) => l.showConnected()),
  ];

  int index = 0;
  late int secondsLeft = stepLength.inSeconds;
  Timer? _timer;

  DemoStep get step => steps[index];

  void start() {
    debugPrint('[demo] Simulator demo: ${steps.length} steps × ${stepLength.inSeconds} s, then it loops.');
    _enter(0);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    secondsLeft--;
    if (secondsLeft <= 0) {
      _enter((index + 1) % steps.length);
    } else {
      _print();
    }
  }

  void _enter(int i) {
    index = i;
    secondsLeft = stepLength.inSeconds;
    step.enter(link);
    battery.setDemo(step.battery.$1, step.battery.$2);
    _print();
    notifyListeners();
  }

  void _print() {
    final n = (index + 1).toString().padLeft(2, '0');
    debugPrint('[demo] $n/${steps.length} ${step.name} · ⏱ ${secondsLeft}s left');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
