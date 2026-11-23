import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crypto from Android's built-in javax.crypto (MainActivity.kt), so no extra package.
class NativeCrypto {
  static const _ch = MethodChannel('deskmate/crypto');

  static Future<Uint8List> pbkdf2(String password, List<int> salt, int iterations) async =>
      (await _ch.invokeMethod<Uint8List>('pbkdf2', {
        'password': password,
        'salt': Uint8List.fromList(salt),
        'iterations': iterations,
      }))!;
  static Future<Uint8List> hmac(List<int> key, List<int> data) async =>
      (await _ch.invokeMethod<Uint8List>('hmac', {'key': Uint8List.fromList(key), 'data': Uint8List.fromList(data)}))!;

  /// AES-256-GCM; nonce(12) || ciphertext || tag(16), same as CryptoKit's "combined".
  static Future<Uint8List> seal(List<int> key, List<int> data) async =>
      (await _ch.invokeMethod<Uint8List>('seal', {'key': Uint8List.fromList(key), 'data': Uint8List.fromList(data)}))!;
  static Future<Uint8List> open(List<int> key, List<int> data) async =>
      (await _ch.invokeMethod<Uint8List>('open', {'key': Uint8List.fromList(key), 'data': Uint8List.fromList(data)}))!;
  static Future<Uint8List> random(int length) async => (await _ch.invokeMethod<Uint8List>('random', length))!;
}

/// What the phone remembers about its paired computer.
class WifiPairing {
  WifiPairing._(this._prefs);
  final SharedPreferences _prefs;

  static Future<WifiPairing> load() async => WifiPairing._(await SharedPreferences.getInstance());

  Uint8List? get key {
    final k = _prefs.getString('wifi.key');
    return k == null ? null : base64Decode(k);
  }

  bool get paired => key != null;
  String? get hubName => _prefs.getString('wifi.hubName');

  /// Typed Mac address, used when automatic discovery is blocked on the network.
  String? get manualHost => _prefs.getString('wifi.host');
  set manualHost(String? host) =>
      host == null || host.isEmpty ? _prefs.remove('wifi.host') : _prefs.setString('wifi.host', host);

  Future<String> phoneId() async {
    final existing = _prefs.getString('wifi.phoneId');
    if (existing != null) return existing;
    final id = base64UrlEncode(await NativeCrypto.random(12));
    await _prefs.setString('wifi.phoneId', id);
    return id;
  }

  Future<void> save(Uint8List key, String? hubName) async {
    await _prefs.setString('wifi.key', base64Encode(key));
    if (hubName != null) await _prefs.setString('wifi.hubName', hubName);
  }

  Future<void> forget() async {
    await _prefs.remove('wifi.key');
    await _prefs.remove('wifi.hubName');
  }
}

/// Encrypted TCP link to Deskmate Hub on the local network (see docs/PROTOCOL.md).
///
/// Frames are a 4-byte big-endian length + payload. The handshake is plain JSON;
/// everything after it is AES-GCM with a fresh per-session key.
class WifiChannel {
  static const port = 47820;
  static const serviceType = '_deskmate._tcp';
  static const _deviceChannel = MethodChannel('deskmate/device');

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;
  final _buffer = BytesBuilder();
  final _frames = StreamController<Uint8List>();
  StreamIterator<Uint8List>? _reader;
  Uint8List? _sessionKey;

  bool get isOpen => _sessionKey != null && _socket != null;

  /// Finds Deskmate Hubs on the network via Bonjour (mDNS). Returns host:port pairs.
  static Future<List<(String, int)>> discover({Duration timeout = const Duration(seconds: 3)}) async {
    final found = <(String, int)>[];
    try {
      await _deviceChannel.invokeMethod('multicastLock', true);
    } catch (_) {}
    final client = MDnsClient(
      // reusePort isn't supported on Android.
      rawDatagramSocketFactory:
          (host, port, {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) =>
              RawDatagramSocket.bind(host, port, reuseAddress: true, reusePort: false, ttl: ttl),
    );
    try {
      await client.start();
      await for (final ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('$serviceType.local'))
          .timeout(timeout, onTimeout: (s) => s.close())) {
        await for (final srv in client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .timeout(timeout, onTimeout: (s) => s.close())) {
          await for (final ip in client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
              .timeout(timeout, onTimeout: (s) => s.close())) {
            final entry = (ip.address.address, srv.port);
            if (!found.contains(entry)) found.add(entry);
          }
        }
      }
    } catch (_) {
      // Networks that block multicast just find nothing; manual IP still works.
    } finally {
      client.stop();
      try {
        await _deviceChannel.invokeMethod('multicastLock', false);
      } catch (_) {}
    }
    return found;
  }

  /// One-time pairing with the 6-digit code shown in the Hub menu.
  /// Returns the long-term key and the Hub's name. Throws a readable message on failure.
  static Future<(Uint8List, String?)> pair({
    required String host,
    required int port,
    required String code,
    required String phoneId,
    required String phoneName,
  }) async {
    final ch = WifiChannel();
    try {
      await ch._open(host, port);
      final phoneNonce = await NativeCrypto.random(16);
      ch._sendPlain({
        't': 'hello',
        'v': 1,
        'mode': 'pair',
        'id': phoneId,
        'name': phoneName,
        'nonce': base64Encode(phoneNonce),
      });
      final challenge = await ch._readPlain();
      if (challenge['t'] != 'challenge') throw _reason(challenge);
      final hubNonce = base64Decode(challenge['nonce'] as String);
      final temp = await NativeCrypto.pbkdf2(code, [...phoneNonce, ...hubNonce], 100000);
      final proof = await NativeCrypto.hmac(temp, utf8.encode('deskmate-pair-phone'));
      ch._sendPlain({'t': 'proof', 'mac': base64Encode(proof)});
      final reply = await ch._readPlain();
      if (reply['t'] != 'key') throw _reason(reply);
      final key = await NativeCrypto.open(temp, base64Decode(reply['box'] as String));
      return (key, reply['hub'] as String?);
    } finally {
      ch.close();
    }
  }

  /// Opens an encrypted session with an already paired Hub.
  Future<void> connect({
    required String host,
    required int port,
    required List<int> key,
    required String phoneId,
    required String phoneName,
  }) async {
    await _open(host, port);
    final phoneNonce = await NativeCrypto.random(16);
    _sendPlain({
      't': 'hello',
      'v': 1,
      'mode': 'resume',
      'id': phoneId,
      'name': phoneName,
      'nonce': base64Encode(phoneNonce),
    });
    final challenge = await _readPlain();
    if (challenge['t'] != 'challenge') throw _reason(challenge);
    final hubNonce = base64Decode(challenge['nonce'] as String);
    final session = await NativeCrypto.hmac(key, [...phoneNonce, ...hubNonce]);
    final proof = await NativeCrypto.hmac(session, utf8.encode('deskmate-phone'));
    _sendPlain({'t': 'proof', 'mac': base64Encode(proof)});
    final ready = jsonDecode(utf8.decode(await NativeCrypto.open(session, await _nextFrame())));
    if (ready['t'] != 'ready') throw 'Unexpected reply';
    _sessionKey = session;
  }

  /// Decrypted messages from the Hub; ends when the connection closes.
  Stream<List<int>> messages() async* {
    final key = _sessionKey;
    if (key == null) return;
    while (true) {
      final Uint8List frame;
      try {
        frame = await _nextFrame();
      } catch (_) {
        return;
      }
      yield await NativeCrypto.open(key, frame);
    }
  }

  Future<void> send(Map<String, Object?> json) async {
    final key = _sessionKey;
    final socket = _socket;
    if (key == null || socket == null) return;
    _writeFrame(await NativeCrypto.seal(key, utf8.encode(jsonEncode(json))));
  }

  void close() {
    _sessionKey = null;
    _sub?.cancel();
    _socket?.destroy();
    _socket = null;
    if (!_frames.isClosed) _frames.close();
  }

  // MARK: plumbing

  Future<void> _open(String host, int port) async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;
    _reader = StreamIterator(_frames.stream);
    _sub = socket.listen(
      (data) {
        _buffer.add(data);
        _drain();
      },
      onDone: close,
      onError: (_) => close(),
      cancelOnError: true,
    );
  }

  void _drain() {
    while (true) {
      final bytes = _buffer.toBytes();
      if (bytes.length < 4) return;
      final length = ByteData.sublistView(bytes, 0, 4).getUint32(0);
      if (length > 1 << 20) return close(); // nonsense length
      if (bytes.length < 4 + length) return;
      _frames.add(Uint8List.sublistView(bytes, 4, 4 + length));
      _buffer.clear();
      _buffer.add(Uint8List.sublistView(bytes, 4 + length));
    }
  }

  Future<Uint8List> _nextFrame() async {
    final reader = _reader;
    if (reader == null || !await reader.moveNext().timeout(const Duration(seconds: 30))) {
      throw 'Connection closed';
    }
    return reader.current;
  }

  Future<Map<String, dynamic>> _readPlain() async =>
      jsonDecode(utf8.decode(await _nextFrame().timeout(const Duration(seconds: 6)))) as Map<String, dynamic>;

  void _sendPlain(Map<String, Object?> json) => _writeFrame(utf8.encode(jsonEncode(json)));

  void _writeFrame(List<int> payload) {
    final header = ByteData(4)..setUint32(0, payload.length);
    _socket?.add([...header.buffer.asUint8List(), ...payload]);
  }

  static String _reason(Map<String, dynamic> reply) => switch (reply['reason']) {
    'not-pairing' => 'Choose "Pair a phone over Wi-Fi…" in the Deskmate Hub menu first.',
    'wrong-code' => 'Wrong code. Choose "Pair a phone over Wi-Fi…" again for a new code.',
    'unknown-phone' => 'The computer doesn\'t know this phone any more. Pair again.',
    _ => 'The computer refused the connection.',
  };
}
