import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

/// The phone's own battery, for the header chip and the plug/unplug warnings.
class PhoneBattery extends ChangeNotifier {
  PhoneBattery({this.simulate = false});

  /// Demo mode: don't read the real battery; the demo tour sets values with [setDemo].
  final bool simulate;

  final _battery = Battery();
  int? level;
  bool charging = false;
  StreamSubscription? _sub;
  Timer? _poll;

  void start() {
    if (simulate) {
      setDemo(64, false);
      return;
    }
    try {
      _sub = _battery.onBatteryStateChanged.listen((s) {
        charging = s == BatteryState.charging || s == BatteryState.full;
        _refresh();
      }, onError: (_) {});
      _refresh();
      _poll = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
    } catch (e) {
      debugPrint('Battery unavailable: $e');
    }
  }

  void setDemo(int level, bool charging) {
    if (this.level == level && this.charging == charging) return;
    this.level = level;
    this.charging = charging;
    notifyListeners();
  }

  Future<void> _refresh() async {
    try {
      final s = await _battery.batteryState;
      charging = s == BatteryState.charging || s == BatteryState.full;
      level = await _battery.batteryLevel;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}
