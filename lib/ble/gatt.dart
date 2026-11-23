import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Shared BLE contract. Keep in sync with mac/Sources/DeskmateMac/GATT.swift.
class Gatt {
  static final service = Guid('CC8A9226-538A-41AA-B390-85DB92127C62');

  /// Notify + read. UTF-8 JSON messages with a topic "t"; see data/models.dart.
  static final stats = Guid('46ABD5B3-C525-463B-9E0A-5EB81163CCBB');
}
