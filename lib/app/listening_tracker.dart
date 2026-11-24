/// How long music has been playing in one stretch. Runs on the phone from the
/// "playing" flag the computer sends; nothing is stored.
///
/// A pause shorter than [pauseLimit] keeps the same stretch (the time just stops
/// counting). A longer pause ends it: it moves to [last] and the next song starts a new one.
class ListeningTracker {
  ListeningTracker({this.pauseLimit = const Duration(minutes: 5)});

  final Duration pauseLimit;

  /// Time listened in the current stretch; null when none is running.
  Duration? current;

  /// The stretch that ended most recently.
  Duration? last;

  DateTime? _lastTick;
  DateTime? _pausedSince;

  void update(bool playing, DateTime now) {
    final previous = _lastTick;
    _lastTick = now;
    // Clamp so a clock sync or a stalled tick can't add a jump.
    final delta =
        previous == null
            ? Duration.zero
            : Duration(milliseconds: now.difference(previous).inMilliseconds.clamp(0, 3000));

    if (playing) {
      _pausedSince = null;
      current = (current ?? Duration.zero) + delta;
      return;
    }
    if (current == null) return;
    _pausedSince ??= now;
    if (now.difference(_pausedSince!) >= pauseLimit) {
      if (current! >= const Duration(seconds: 30)) last = current;
      current = null;
      _pausedSince = null;
    }
  }
}
