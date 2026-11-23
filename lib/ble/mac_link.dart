import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import 'wifi_channel.dart';

/// notPaired: no computer paired yet (Settings → Wi-Fi link).
/// scanning: paired, looking for the computer on the network.
enum LinkState { notPaired, scanning, connecting, connected, reconnecting }

/// Keeps the encrypted Wi-Fi link to the computer (Deskmate Hub) alive and exposes
/// the latest board data. Wi-Fi only: no Bluetooth, so the computer's Bluetooth radio
/// stays free for earphones. Also tracks reliability counters for diagnostics.
class MacLink extends ChangeNotifier {
  LinkState state = LinkState.scanning;
  final board = BoardData();

  /// The computer said it's going to sleep or locked. Cleared on reconnect.
  bool macAsleep = false;

  /// When the link was last lost (null while connected or never connected).
  DateTime? lostAt;

  /// Clock sync: the phone has no network time, so it follows the computer's
  /// clock and time zone (sent by Deskmate Hub on every connection and hourly).
  Duration clockOffset = Duration.zero;
  int? hubTimezoneMinutes;

  /// The current time as the computer sees it (falls back to the phone's clock).
  /// With a synced time zone this is a UTC value holding the computer's wall time,
  /// so only read its fields (hour, minute, day…), not its zone.
  DateTime now() {
    final tz = hubTimezoneMinutes;
    if (tz == null) return DateTime.now().add(clockOffset);
    return DateTime.now().toUtc().add(clockOffset).add(Duration(minutes: tz));
  }

  // Reliability counters.
  final startedAt = DateTime.now();
  int packets = 0;
  int missed = 0; // seq gaps while connected
  int connects = 0;
  int drops = 0;
  Duration longestSilence = Duration.zero;
  final events = <String>[]; // newest first

  Timer? _watchdog, _retry;
  int? _lastSeq;
  DateTime? _lastPacketAt;
  bool _everConnected = false;
  final _parts = _PartBuffer();

  WifiPairing? _pairing;
  WifiChannel? _wifi;
  bool _connecting = false;
  String? _lastHost;

  /// Whether a link has been up before (so a loss shows as "reconnecting").
  bool get everConnected => _everConnected;

  bool get wifiActive => _wifi != null && state == LinkState.connected;
  bool get wifiPaired => _pairing?.paired ?? false;
  String? get wifiHubName => _pairing?.hubName;
  String? get wifiManualHost => _pairing?.manualHost;

  /// Sends a control command to the computer (music, Bluetooth devices, Wi-Fi).
  void sendCommand(String command) {
    final wifi = _wifi;
    if (wifi == null || state != LinkState.connected) {
      logEvent('Command "$command" not sent (not connected)');
      return;
    }
    wifi.send({'t': 'cmd', 'c': command});
    logEvent('Command "$command" sent');
  }

  void start() {
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) => _checkSilence());
    _init();
  }

  Future<void> _init() async {
    try {
      _pairing = await WifiPairing.load();
    } catch (e) {
      logEvent('Settings unavailable: $e');
      return;
    }
    if (!wifiPaired) {
      setLinkState(LinkState.notPaired);
      logEvent('Not paired yet (Settings → Wi-Fi link)');
      return;
    }
    _connect();
  }

  /// Tries the last working address, the typed address, then computers found via Bonjour.
  Future<void> _connect() async {
    final pairing = _pairing;
    final key = pairing?.key;
    if (pairing == null || key == null || _wifi != null || _connecting) return;
    _connecting = true;
    _retry?.cancel();
    setLinkState(_everConnected ? LinkState.reconnecting : LinkState.scanning);
    try {
      final hosts = <(String, int)>[
        if (_lastHost != null) (_lastHost!, WifiChannel.port),
        if (pairing.manualHost != null && pairing.manualHost != _lastHost) (pairing.manualHost!, WifiChannel.port),
      ];
      if (hosts.isEmpty) hosts.addAll(await WifiChannel.discover());
      for (final (host, port) in hosts) {
        if (!_everConnected) setLinkState(LinkState.connecting);
        final channel = WifiChannel();
        try {
          await channel.connect(
            host: host,
            port: port,
            key: key,
            phoneId: await pairing.phoneId(),
            phoneName: await _phoneName(),
          );
        } catch (_) {
          channel.close();
          continue;
        }
        _use(channel, host);
        return;
      }
      // Not found: try discovery next time too, in case the computer's address changed.
      _lastHost = null;
      setLinkState(_everConnected ? LinkState.reconnecting : LinkState.scanning);
    } finally {
      _connecting = false;
      if (_wifi == null && wifiPaired) _retry = Timer(const Duration(seconds: 5), _connect);
    }
  }

  void _use(WifiChannel channel, String host) {
    _wifi = channel;
    _lastHost = host;
    markConnected('Connected over Wi-Fi ($host)');
    () async {
      await for (final message in channel.messages()) {
        handlePacket(message);
      }
      if (_wifi != channel) return; // forgotten
      _wifi = null;
      markLost('Wi-Fi link lost');
      setLinkState(LinkState.reconnecting);
      _retry = Timer(const Duration(seconds: 2), _connect);
    }();
  }

  /// The phone's name as set in Android settings (shown on the computer).
  Future<String> _phoneName() async {
    try {
      final name = await const MethodChannel('deskmate/device').invokeMethod<String>('deviceName');
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return 'Android phone';
  }

  /// One-time pairing with the code from the Deskmate Hub menu. Returns an error message, or null.
  Future<String?> pairWifi(String code, {String? host}) async {
    final pairing = _pairing ??= await WifiPairing.load();
    pairing.manualHost = host;
    final hosts = (host != null && host.isNotEmpty) ? [(host, WifiChannel.port)] : await WifiChannel.discover();
    if (hosts.isEmpty) {
      return 'Couldn\'t find your computer on this network. Type its IP address (shown in the Deskmate Hub menu).';
    }
    try {
      final (key, hubName) = await WifiChannel.pair(
        host: hosts.first.$1,
        port: hosts.first.$2,
        code: code,
        phoneId: await pairing.phoneId(),
        phoneName: await _phoneName(),
      );
      await pairing.save(key, hubName);
      _lastHost = hosts.first.$1;
      logEvent('Paired over Wi-Fi with ${hubName ?? hosts.first.$1}');
      notifyListeners();
      unawaited(_connect());
      return null;
    } on SocketException {
      return 'Couldn\'t reach the computer at ${hosts.first.$1}. Check that both are on the same Wi-Fi.';
    } catch (e) {
      return e is String ? e : 'Pairing failed: $e';
    }
  }

  /// Unpairs from the computer.
  Future<void> forgetWifi() async {
    await _pairing?.forget();
    _retry?.cancel();
    final wifi = _wifi;
    _wifi = null;
    wifi?.close();
    _lastHost = null;
    setLinkState(LinkState.notPaired);
    logEvent('Wi-Fi pairing forgotten');
  }

  /// Call once the link is up.
  @protected
  void markConnected(String message) {
    connects++;
    _everConnected = true;
    _lastSeq = null;
    _lastPacketAt = DateTime.now();
    macAsleep = false;
    lostAt = null;
    setLinkState(LinkState.connected);
    logEvent(message);
  }

  /// Demo only: back to "never connected" so the first-launch state can be shown again.
  @protected
  void resetForDemo() {
    _everConnected = false;
    lostAt = null;
    macAsleep = false;
  }

  /// Marks the link as lost.
  @protected
  void markLost(String message, {bool asleep = false}) {
    drops++;
    lostAt = DateTime.now();
    macAsleep = asleep;
    logEvent(message);
  }

  /// Parses one notification (UTF-8 JSON with a topic) and updates the board.
  @protected
  void handlePacket(List<int> bytes) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      logEvent('Bad packet (${bytes.length} B)');
      return;
    }
    // Messages larger than one Bluetooth packet arrive as base64 parts (older Hubs); rebuild them first.
    if (json['t'] == 'part') {
      final whole = _parts.add(json);
      if (whole != null) handlePacket(whole);
      return;
    }
    final seq = json['seq'] as int?;
    if (seq != null) {
      final last = _lastSeq;
      if (last != null && seq > last + 1) missed += seq - last - 1;
      if (last != null && seq <= last) logEvent('Mac restarted (seq reset)');
      _lastSeq = seq;
    }
    packets++;
    _lastPacketAt = DateTime.now();
    if (json['t'] == 'power') {
      macAsleep = json['asleep'] == true;
      logEvent(macAsleep ? 'Mac asleep or locked' : 'Mac awake');
    } else if (json['t'] == 'time') {
      final ts = json['ts'] as int?;
      if (ts != null) {
        clockOffset = Duration(milliseconds: ts - DateTime.now().millisecondsSinceEpoch);
        hubTimezoneMinutes = json['tz'] as int?;
        logEvent('Clock synced (phone off by ${clockOffset.inSeconds}s)');
      }
    } else if (!board.apply(json)) {
      logEvent('Unknown message "${json['t']}"');
    }
    notifyListeners();
  }

  void _checkSilence() {
    final at = _lastPacketAt;
    if (state != LinkState.connected || at == null) return;
    final silence = DateTime.now().difference(at);
    if (silence > longestSilence) {
      longestSilence = silence;
      notifyListeners();
    }
  }

  @protected
  void setLinkState(LinkState s) {
    state = s;
    notifyListeners();
  }

  @protected
  void logEvent(String message) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    events.insert(0, '${two(t.hour)}:${two(t.minute)}:${two(t.second)}  $message');
    if (events.length > 50) events.removeLast();
    debugPrint('[MacLink] $message');
    notifyListeners();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _retry?.cancel();
    _wifi?.close();
    super.dispose();
  }
}

/// Reassembles {"t":"part","id","i","n","d"} messages (base64 slices of one JSON message).
class _PartBuffer {
  final _pending = <int, List<String?>>{};

  /// Returns the full message bytes once every part of [part]'s message has arrived.
  List<int>? add(Map<String, dynamic> part) {
    final id = part['id'] as int?, i = part['i'] as int?, n = part['n'] as int?, d = part['d'] as String?;
    if (id == null || i == null || n == null || d == null || i >= n || n > 200) return null;
    final slots = _pending.putIfAbsent(id, () => List<String?>.filled(n, null));
    if (slots.length != n) return null;
    slots[i] = d;
    if (slots.any((s) => s == null)) return null;
    _pending.remove(id);
    // Forget unfinished messages from long ago (a dropped part never completes).
    _pending.removeWhere((k, _) => (id - k).abs() > 50);
    try {
      return base64Decode(slots.join());
    } catch (_) {
      return null;
    }
  }
}
