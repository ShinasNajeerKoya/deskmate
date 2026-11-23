import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/models.dart';
import 'gatt.dart';

enum LinkState { bluetoothOff, scanning, connecting, connected, reconnecting }

/// Finds the Mac, keeps the connection alive and exposes the latest board data.
/// Also tracks reliability counters for the link soak test (MIUI background killing).
class MacLink extends ChangeNotifier {
  LinkState state = LinkState.scanning;
  final board = BoardData();

  /// The Mac said it's going to sleep (or locked). Cleared on reconnect.
  bool macAsleep = false;

  /// When the link was last lost (null while connected or never connected).
  DateTime? lostAt;

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

  /// Whether a link has been up before (so a loss shows as "reconnecting").
  bool get everConnected => _everConnected;

  /// Sends a control command to the Mac (media keys, shortcuts, lock).
  /// The Mac side doesn't accept commands yet, so this only logs for now.
  void sendCommand(String command) {
    logEvent('Command "$command" (Mac commands not built yet)');
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
        if (state == LinkState.connected) lostAt = DateTime.now();
        _running = false;
        _teardown();
        setLinkState(LinkState.bluetoothOff);
        logEvent('Bluetooth ${s.name}');
      }
    });
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) => _checkSilence());
  }

  Future<void> _scan() async {
    if (!_running) return;
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
    if (_device == null) _scheduleRetry(const Duration(seconds: 3));
  }

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;
    await FlutterBluePlus.stopScan();
    setLinkState(LinkState.connecting);
    logEvent('Found Mac, connecting');
    try {
      await device.connect(timeout: const Duration(seconds: 15)); // requests MTU 512
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
      _valueSub = chr.onValueReceived.listen(handlePacket);
      device.cancelWhenDisconnected(_valueSub!);
      await chr.setNotifyValue(true);
      markConnected('Connected (MTU ${device.mtuNow})');
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
      if (macAsleep) logEvent('Mac going to sleep');
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
    super.dispose();
  }
}
