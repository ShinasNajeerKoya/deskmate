import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/models.dart';
import 'gatt.dart';
import 'wifi_channel.dart';

enum LinkState { bluetoothOff, scanning, connecting, connected, reconnecting }

/// Finds the computer (Deskmate Hub), keeps the connection alive and exposes the
/// latest board data. Wi-Fi first when paired (keeps the Bluetooth radio free for
/// earphones), Bluetooth LE as the backup. Also tracks reliability counters.
class MacLink extends ChangeNotifier {
  LinkState state = LinkState.scanning;
  final board = BoardData();

  /// The Mac said it's going to sleep (or locked). Cleared on reconnect.
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

  BluetoothDevice? _device;
  StreamSubscription? _adapterSub, _scanSub, _connSub, _valueSub;
  Timer? _retry, _watchdog;
  int? _lastSeq;
  DateTime? _lastPacketAt;
  bool _running = false;
  bool _everConnected = false;

  // Wi-Fi link (preferred when paired).
  WifiPairing? _pairing;
  WifiChannel? _wifi;
  Timer? _wifiTimer;
  bool _wifiBusy = false;

  /// True while connected over Wi-Fi (Bluetooth is idle then).
  bool wifiActive = false;
  bool get wifiPaired => _pairing?.paired ?? false;
  String? get wifiHubName => _pairing?.hubName;
  String? get wifiManualHost => _pairing?.manualHost;

  /// Whether a link has been up before (so a loss shows as "reconnecting").
  bool get everConnected => _everConnected;

  /// Sends a control command to the Mac (media keys, shortcuts, lock).
  /// The Mac side doesn't accept commands yet, so this only logs for now.
  void sendCommand(String command) {
    final wifi = _wifi;
    if (wifiActive && wifi != null) {
      wifi.send({'t': 'cmd', 'c': command});
      logEvent('Command "$command" sent over Wi-Fi');
      return;
    }
    final chr = _commandChr;
    if (chr == null || state != LinkState.connected) {
      logEvent('Command "$command" not sent (not connected)');
      return;
    }
    _write(chr, {'t': 'cmd', 'c': command});
    logEvent('Command "$command" sent');
  }

  void start() {
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      if (s == BluetoothAdapterState.on) {
        if (!_running) {
          _running = true;
          logEvent('Bluetooth on');
          _scan();
        }
      } else if (s == BluetoothAdapterState.off || s == BluetoothAdapterState.unauthorized) {
        _running = false;
        logEvent('Bluetooth ${s.name}');
        if (wifiActive) return; // Wi-Fi keeps working without Bluetooth
        if (state == LinkState.connected) lostAt = DateTime.now();
        _teardown();
        setLinkState(LinkState.bluetoothOff);
      }
    });
    _initWifi();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) => _checkSilence());
  }

  Future<void> _scan() async {
    if (!_running || wifiActive) return;
    setLinkState(_everConnected ? LinkState.reconnecting : LinkState.scanning);
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isEmpty || _device != null) return;
      _connect(results.last.device);
    });
    try {
      // Android throttles >5 scan starts per 30 s, so scan in long windows.
      await FlutterBluePlus.startScan(withServices: [Gatt.service], timeout: const Duration(seconds: 20));
      await FlutterBluePlus.isScanning.where((s) => !s).first;
    } catch (e) {
      logEvent('Scan error: $e');
    }
    if (_device == null && !wifiActive) _scheduleRetry(const Duration(seconds: 3));
  }

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;
    await FlutterBluePlus.stopScan();
    setLinkState(LinkState.connecting);
    logEvent('Found Mac, connecting');
    try {
      await device.connect(timeout: const Duration(seconds: 15)); // requests MTU 512
      // The computer's Bluetooth radio also streams your earphones' audio. A low-power
      // connection (~100 ms between exchanges instead of ~30 ms) leaves it far more
      // air time, so music doesn't stutter. Deskmate's updates easily fit in that.
      try {
        await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.lowPower);
      } catch (_) {} // Android only
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && _device == device) {
          drops++;
          lostAt = DateTime.now();
          logEvent(
            'Disconnected${device.disconnectReason != null ? ' (${device.disconnectReason!.description})' : ''}',
          );
          _onLost();
        }
      });
      final services = await device.discoverServices();
      final chr = services
          .firstWhere((s) => s.uuid == Gatt.service)
          .characteristics
          .firstWhere((c) => c.uuid == Gatt.stats);
      final service = services.firstWhere((s) => s.uuid == Gatt.service);
      _commandChr = service.characteristics.where((c) => c.uuid == Gatt.command).firstOrNull;
      _valueSub = chr.onValueReceived.listen(handlePacket);
      device.cancelWhenDisconnected(_valueSub!);
      await chr.setNotifyValue(true);
      markConnected('Connected (MTU ${device.mtuNow})');
      await _sayHello();
    } catch (e) {
      logEvent('Connect failed: $e');
      await device.disconnect().catchError((_) {});
      _onLost();
    }
  }

  /// Call once the link is up and notifications are on.
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

  /// Marks the link as lost (used by the fake link; the real one gets this from BLE).
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
    // Messages larger than one BLE packet arrive as base64 parts; rebuild them first.
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

  BluetoothCharacteristic? _commandChr;
  final _parts = _PartBuffer();

  /// Tells the Hub this phone's name, so the computer can show "Connected to (phone name)".
  Future<void> _sayHello() async {
    final chr = _commandChr;
    if (chr == null) return; // older Hub without a command channel
    await _write(chr, {'t': 'hello', 'name': await _phoneName()});
  }

  Future<String> _phoneName() async {
    try {
      final n = await FlutterBluePlus.adapterName;
      if (n.trim().isNotEmpty) return n.trim();
    } catch (_) {}
    return 'Android phone';
  }

  // MARK: Wi-Fi

  Future<void> _initWifi() async {
    try {
      _pairing = await WifiPairing.load();
    } catch (_) {
      return;
    }
    _wifiTimer = Timer.periodic(const Duration(seconds: 15), (_) => _tryWifi());
    unawaited(_tryWifi());
  }

  /// Tries the typed address first, then computers found on the network.
  Future<void> _tryWifi() async {
    final pairing = _pairing;
    final key = pairing?.key;
    if (pairing == null || key == null || wifiActive || _wifiBusy) return;
    _wifiBusy = true;
    try {
      final manual = pairing.manualHost;
      final hosts = <(String, int)>[if (manual != null) (manual, WifiChannel.port), ...await WifiChannel.discover()];
      for (final (host, port) in hosts) {
        final channel = WifiChannel();
        try {
          await channel.connect(
            host: host,
            port: port,
            key: key,
            phoneId: await pairing.phoneId(),
            phoneName: await _phoneName(),
          );
        } catch (e) {
          channel.close();
          continue;
        }
        _useWifi(channel, host);
        return;
      }
    } finally {
      _wifiBusy = false;
    }
  }

  void _useWifi(WifiChannel channel, String host) {
    _wifi = channel;
    wifiActive = true;
    // Bluetooth goes idle, so the radio is free for earphones.
    _retry?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan().catchError((_) {});
    final ble = _device;
    _device = null;
    _connSub?.cancel();
    _valueSub?.cancel();
    _commandChr = null;
    ble?.disconnect().catchError((_) {});
    markConnected('Connected over Wi-Fi ($host)');
    () async {
      await for (final message in channel.messages()) {
        handlePacket(message);
      }
      if (_wifi != channel) return; // replaced or forgotten
      _wifi = null;
      wifiActive = false;
      markLost('Wi-Fi link lost');
      setLinkState(LinkState.reconnecting);
      if (_running) _scan(); // Bluetooth takes over until Wi-Fi is back
    }();
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
      logEvent('Paired over Wi-Fi with ${hubName ?? hosts.first.$1}');
      notifyListeners();
      unawaited(_tryWifi());
      return null;
    } on SocketException {
      return 'Couldn\'t reach the computer at ${hosts.first.$1}. Check that both are on the same Wi-Fi.';
    } catch (e) {
      return e is String ? e : 'Pairing failed: $e';
    }
  }

  /// Unpairs: back to Bluetooth only.
  Future<void> forgetWifi() async {
    await _pairing?.forget();
    final wifi = _wifi;
    _wifi = null;
    final wasActive = wifiActive;
    wifiActive = false;
    wifi?.close();
    if (wasActive) {
      markLost('Wi-Fi forgotten');
      setLinkState(LinkState.reconnecting);
      if (_running) _scan();
    }
    notifyListeners();
  }

  Future<void> _write(BluetoothCharacteristic chr, Map<String, Object?> json) async {
    try {
      await chr.write(utf8.encode(jsonEncode(json)), withoutResponse: chr.properties.writeWithoutResponse);
    } catch (e) {
      logEvent('Write failed: $e');
    }
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

  void _onLost() {
    _connSub?.cancel();
    _valueSub?.cancel();
    _device = null;
    if (_running) _scheduleRetry(const Duration(seconds: 1));
  }

  void _scheduleRetry(Duration delay) {
    _retry?.cancel();
    _retry = Timer(delay, _scan);
  }

  void _teardown() {
    _retry?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    _valueSub?.cancel();
    FlutterBluePlus.stopScan().catchError((_) {});
    _device?.disconnect().catchError((_) {});
    _device = null;
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
    _teardown();
    _adapterSub?.cancel();
    _watchdog?.cancel();
    _wifiTimer?.cancel();
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
