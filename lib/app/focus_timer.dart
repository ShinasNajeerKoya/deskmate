import 'dart:async';

import 'package:flutter/foundation.dart';

class TimerPreset {
  const TimerPreset(this.name, this.minutes, {this.isFocus = false});
  final String name;
  final int minutes;
  final bool isFocus;
}

/// Pomodoro-style focus timer. Runs on the phone; no Mac needed.
class FocusTimer extends ChangeNotifier {
  FocusTimer({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const presets = [
    TimerPreset('Short break', 5),
    TimerPreset('Long break', 15),
    TimerPreset('Focus', 10, isFocus: true), // default: 10 minutes
    TimerPreset('Deep work', 50, isFocus: true),
  ];
  static const sessionsPerRound = 4;

  final DateTime Function() _clock;
  TimerPreset preset = presets[2];
  late Duration remaining = Duration(minutes: preset.minutes);
  bool running = false;
  int focusDoneToday = 0;
  Duration focusedToday = Duration.zero;
  DateTime? _endsAt;
  DateTime _day = DateTime.now();
  Timer? _ticker;

  Duration get total => Duration(minutes: preset.minutes);
  double get progress => 1 - remaining.inMilliseconds / total.inMilliseconds;
  bool get started => remaining < total;

  /// 1-based session within the current round of four.
  int get session => focusDoneToday % sessionsPerRound + 1;

  void select(TimerPreset p) {
    _stop();
    preset = p;
    remaining = total;
    notifyListeners();
  }

  void toggle() => running ? pause() : start();

  void start() {
    if (running) return;
    _rollDay();
    running = true;
    _endsAt = _clock().add(remaining);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _tick();
    _stop();
    notifyListeners();
  }

  void reset() {
    _stop();
    remaining = total;
    notifyListeners();
  }

  void _tick() {
    final before = remaining;
    final left = _endsAt!.difference(_clock());
    remaining = left.isNegative ? Duration.zero : left;
    if (preset.isFocus) focusedToday += before - remaining;
    if (remaining == Duration.zero) {
      _stop();
      if (preset.isFocus) focusDoneToday++;
      remaining = total;
    }
    if (before.inSeconds != remaining.inSeconds) notifyListeners();
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    running = false;
  }

  void _rollDay() {
    final now = _clock();
    if (now.day != _day.day || now.month != _day.month || now.year != _day.year) {
      _day = now;
      focusDoneToday = 0;
      focusedToday = Duration.zero;
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
