import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'mac_link.dart';

/// Simulated Mac for simulators and emulators (they can't reach real Bluetooth).
/// Used automatically there; force it with --dart-define=FAKE_MAC=true.
///
/// It feeds every message topic through the real [handlePacket] parser while
/// "connected". Which link state it shows is driven step by step by the demo
/// tour (lib/app/demo_tour.dart) through the show* methods below.
class FakeMacLink extends MacLink {
  final _rng = Random();
  Timer? _ticker;
  int _seq = 0;
  int _ticks = 0;

  double _cpu = 18, _mem = 61, _h5 = 58, _wk = 38;
  int _h5ResetMin = 108;

  static const _tracks = [
    ('Low Tide Static', 'Marlow Fen', 'Harbour Lights', 232),
    ('Paper Satellites', 'The Quiet Hours', 'Orbit Songs', 198),
    ('Copper Sky', 'Ines Valo', 'Weathervane', 254),
    ('Slow Machines', 'Northbound', 'Signals', 211),
    ('Glasshouse', 'Ada Kestrel', 'Glasshouse', 187),
    ('After the Rain', 'Marlow Fen', 'Harbour Lights', 243),
  ];
  int _track = 0, _pos = 84;
  bool _playing = true, _liked = false, _shuffle = false;
  double _vol = 0.6;

  // Mac Bluetooth: id → (name, kind, connected, paired)
  final _bt = <String, (String, String, bool, bool)>{
    'earphones': ('Earphones', 'headphones', true, true),
    'studio': ('Studio headphones', 'headphones', false, true),
    'keyboard': ('Keyboard', 'keyboard', true, true),
    'mouse': ('Mouse', 'mouse', true, true),
    'earbuds': ('Earbuds', 'headphones', false, false),
    'speaker': ('Speaker', 'speaker', false, false),
  };
  bool _wifiOn = true;

  @override
  void start() {
    logEvent('Fake Mac mode (no Bluetooth)');
    setLinkState(LinkState.scanning);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state == LinkState.connected) _tick();
    });
  }

  /// First launch: nothing found yet (skeleton tiles, orange banner).
  void showLooking() {
    resetForDemo();
    setLinkState(LinkState.scanning);
    logEvent('Looking for Mac (fake)');
  }

  void showConnecting() {
    setLinkState(LinkState.connecting);
    logEvent('Found Mac, connecting (fake)');
  }

  void showConnected() {
    if (state == LinkState.connected) return;
    markConnected('Connected (fake)');
    _sendAll();
  }

  /// Link dropped while the Mac is awake (blue banner, tiles keep their data).
  void showDrop() {
    markLost('Disconnected (fake)');
    setLinkState(LinkState.reconnecting);
  }

  /// The Mac says it's going to sleep (night clock right away).
  void showMacAsleep() {
    _send({'t': 'power', 'asleep': true});
    markLost('Mac asleep (fake)', asleep: true);
    setLinkState(LinkState.reconnecting);
  }

  /// The phone's own Bluetooth is off (red banner).
  void showBluetoothOff() {
    markLost('Bluetooth off (fake)');
    setLinkState(LinkState.bluetoothOff);
  }

  void _tick() {
    _ticks++;
    _cpu = (_cpu + (_rng.nextDouble() - 0.5) * 12).clamp(3, 95);
    if (_rng.nextDouble() < 0.05) _cpu = 60 + _rng.nextDouble() * 35;
    _mem = (_mem + (_rng.nextDouble() - 0.5) * 1.5).clamp(40, 85);
    if (_playing) {
      _pos++;
      if (_pos >= _tracks[_track].$4) _skip(1);
    }

    if (_rng.nextDouble() >= 0.03) _send(_sys()); // ~3% simulated packet loss
    _send(_music());
    if (_ticks % 5 == 0) _send(_claude());
    if (_ticks % 10 == 0) _send(_slack());
    if (_ticks % 30 == 0) _send(_event());
  }

  @override
  void sendCommand(String command) {
    logEvent('Command "$command" (fake)');
    switch (command) {
      case 'music.toggle':
        _playing = !_playing;
      case 'music.next':
        _skip(1);
      case 'music.previous':
        _pos > 5 ? _pos = 0 : _skip(-1);
      case 'music.like':
        _liked = !_liked;
      case 'music.shuffle':
        _shuffle = !_shuffle;
    }
    final arg = command.contains(':') ? command.substring(command.indexOf(':') + 1) : '';
    final dev = _bt[arg];
    if (command.startsWith('bt.disconnect:') && dev != null) {
      _bt[arg] = (dev.$1, dev.$2, false, dev.$4);
    } else if (command.startsWith('bt.connect:') && dev != null) {
      // One audio output at a time, like macOS.
      if (dev.$2 == 'headphones' || dev.$2 == 'speaker') {
        _bt.updateAll((_, d) => (d.$2 == 'headphones' || d.$2 == 'speaker') ? (d.$1, d.$2, false, d.$4) : d);
      }
      _bt[arg] = (dev.$1, dev.$2, true, true);
    } else if (command.startsWith('bt.pair:') && dev != null) {
      _bt[arg] = (dev.$1, dev.$2, false, true);
    } else if (command.startsWith('wifi.power:')) {
      _wifiOn = arg == 'on';
    }
    if (command.startsWith('bt.') && state == LinkState.connected) _send(_bluetooth());
    if (command.startsWith('wifi.') && state == LinkState.connected) _send(_wifi());
    if (command.startsWith('music.volume:')) {
      _vol = double.tryParse(command.split(':').last) ?? _vol;
    }
    if (state == LinkState.connected) _send(_music());
  }

  void _skip(int by) {
    _track = (_track + by) % _tracks.length;
    _pos = 0;
    _liked = false;
  }

  void _sendAll() {
    _send(_sys());
    _send(_claude());
    _send(_music());
    _send(_slack());
    _send(_event());
    _send(_bluetooth());
    _send(_wifi());
  }

  Map<String, Object?> _bluetooth() => {
    't': 'bluetooth',
    'scanning': true,
    'devices': [
      for (final e in _bt.entries)
        {'id': e.key, 'name': e.value.$1, 'kind': e.value.$2, 'connected': e.value.$3, 'paired': e.value.$4},
    ],
  };

  Map<String, Object?> _wifi() => {'t': 'wifi', 'on': _wifiOn, if (_wifiOn) 'ssid': 'Network name'};

  void _send(Map<String, Object?> json) {
    _seq++;
    handlePacket(utf8.encode(jsonEncode({'seq': _seq, ...json})));
  }

  double _r1(double v) => (v * 10).roundToDouble() / 10;

  Map<String, Object?> _sys() => {
    't': 'sys',
    'cpu': _r1(_cpu),
    'mem': _r1(_mem),
    'memUsed': _r1(_mem / 100 * 16),
    'memTotal': 16,
    'cores': 8,
    'energy': _cpu > 60 ? 'High' : 'Low',
    'onPower': true,
    'disk': _r1(2 + _rng.nextDouble() * 6),
    'diskFree': 212,
    'down': _r1(800 + _rng.nextDouble() * 900),
    'up': _r1(40 + _rng.nextDouble() * 80),
    'procs': [
      ['Google Chrome', _r1(_cpu * 0.45)],
      ['Xcode', _r1(_cpu * 0.2)],
      ['Claude', _r1(_cpu * 0.14)],
      ['Slack', _r1(_cpu * 0.07)],
      ['WindowServer', _r1(_cpu * 0.05)],
    ],
  };

  Map<String, Object?> _claude() {
    _h5 = (_h5 + _rng.nextDouble() * 0.8).clamp(0, 100);
    _wk = (_wk + _rng.nextDouble() * 0.1).clamp(0, 100);
    _h5ResetMin = max(1, _h5ResetMin - 1);
    return {
      't': 'claude',
      'h5': _r1(_h5),
      'h5Reset': _h5ResetMin,
      'wk': _r1(_wk),
      'wkReset': 'Thu',
      'sessions': 2,
      'waiting': (_ticks ~/ 20).isOdd ? 1 : 0,
      'models': {'Opus': 0.64, 'Sonnet': 0.30, 'Haiku': 0.06},
      'tokens7d': [820000, 1310000, 610000, 1650000, 1120000, 480000, 1200000 + _ticks * 1500],
    };
  }

  Map<String, Object?> _music() {
    final t = _tracks[_track];
    return {
      't': 'music',
      'title': t.$1,
      'artist': t.$2,
      'album': t.$3,
      'dur': t.$4,
      'pos': _pos,
      'playing': _playing,
      'liked': _liked,
      'shuffle': _shuffle,
      'vol': _vol,
      'queue': [
        for (var i = 1; i <= 5; i++)
          [_tracks[(_track + i) % _tracks.length].$1, _tracks[(_track + i) % _tracks.length].$2],
      ],
    };
  }

  Map<String, Object?> _slack() => {'t': 'slack', 'unread': 2 + _rng.nextInt(5)};

  Map<String, Object?> _event() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 30 : 60);
    return {'t': 'event', 'title': 'Standup', 'start': next.millisecondsSinceEpoch ~/ 1000};
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
