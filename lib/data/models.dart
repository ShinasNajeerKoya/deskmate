// Data sent from the Mac. Every BLE message is UTF-8 JSON with a topic "t":
//   {"t":"sys", ...}  {"t":"claude", ...}  {"t":"music", ...}
//   {"t":"slack", ...}  {"t":"event", ...}  {"t":"power", ...}
// Fields are optional: the Mac sends what it has, the UI shows "—" for the rest.

double? _d(Object? v) => (v as num?)?.toDouble();
int? _i(Object? v) => (v as num?)?.toInt();

class ProcStat {
  const ProcStat(this.name, this.cpu);
  final String name;
  final double cpu;
}

class SystemStats {
  const SystemStats({
    this.cpu,
    this.memPct,
    this.memUsedGb,
    this.memTotalGb,
    this.cores,
    this.energy,
    this.onPower,
    this.diskMBs,
    this.diskFreeGb,
    this.netDownKBs,
    this.netUpKBs,
    this.procs = const [],
  });

  final double? cpu, memPct, memUsedGb, memTotalGb, diskMBs, diskFreeGb, netDownKBs, netUpKBs;
  final int? cores;
  final String? energy;
  final bool? onPower;
  final List<ProcStat> procs;

  factory SystemStats.fromJson(Map<String, dynamic> j) => SystemStats(
    cpu: _d(j['cpu']),
    memPct: _d(j['mem']),
    memUsedGb: _d(j['memUsed']),
    memTotalGb: _d(j['memTotal']),
    cores: _i(j['cores']),
    energy: j['energy'] as String?,
    onPower: j['onPower'] as bool?,
    diskMBs: _d(j['disk']),
    diskFreeGb: _d(j['diskFree']),
    netDownKBs: _d(j['down']),
    netUpKBs: _d(j['up']),
    procs: [
      for (final p in (j['procs'] as List? ?? const [])) ProcStat((p as List)[0] as String, (p[1] as num).toDouble()),
    ],
  );
}

class ModelShare {
  const ModelShare(this.name, this.share);
  final String name;
  final double share; // 0..1
}

class ClaudeUsage {
  const ClaudeUsage({
    this.fiveHourPct,
    this.fiveHourResetMin,
    this.weeklyPct,
    this.weeklyReset,
    this.sessions,
    this.waiting,
    this.models = const [],
    this.tokens7d = const [],
  });

  final double? fiveHourPct, weeklyPct;
  final int? fiveHourResetMin, sessions, waiting;
  final String? weeklyReset; // e.g. "Thu"
  final List<ModelShare> models;
  final List<int> tokens7d; // oldest → today

  int? get tokensToday => tokens7d.isEmpty ? null : tokens7d.last;

  factory ClaudeUsage.fromJson(Map<String, dynamic> j) => ClaudeUsage(
    fiveHourPct: _d(j['h5']),
    fiveHourResetMin: _i(j['h5Reset']),
    weeklyPct: _d(j['wk']),
    weeklyReset: j['wkReset'] as String?,
    sessions: _i(j['sessions']),
    waiting: _i(j['waiting']),
    models: [
      for (final e in (j['models'] as Map<String, dynamic>? ?? const {}).entries)
        ModelShare(e.key, (e.value as num).toDouble()),
    ],
    tokens7d: [for (final v in (j['tokens7d'] as List? ?? const [])) (v as num).toInt()],
  );
}

class QueueItem {
  const QueueItem(this.title, this.artist);
  final String title, artist;
}

class NowPlaying {
  const NowPlaying({
    this.title,
    this.artist,
    this.album,
    this.playing = false,
    this.positionS = 0,
    this.durationS = 0,
    this.volume,
    this.liked = false,
    this.shuffle = false,
    this.queue = const [],
  });

  final String? title, artist, album;
  final bool playing, liked, shuffle;
  final int positionS, durationS;
  final double? volume; // 0..1
  final List<QueueItem> queue;

  factory NowPlaying.fromJson(Map<String, dynamic> j) => NowPlaying(
    title: j['title'] as String?,
    artist: j['artist'] as String?,
    album: j['album'] as String?,
    playing: j['playing'] as bool? ?? false,
    positionS: _i(j['pos']) ?? 0,
    durationS: _i(j['dur']) ?? 0,
    volume: _d(j['vol']),
    liked: j['liked'] as bool? ?? false,
    shuffle: j['shuffle'] as bool? ?? false,
    queue: [for (final q in (j['queue'] as List? ?? const [])) QueueItem((q as List)[0] as String, q[1] as String)],
  );
}

class CalendarEvent {
  const CalendarEvent(this.title, this.start);
  final String title;
  final DateTime start;

  static CalendarEvent? fromJson(Map<String, dynamic> j) {
    final start = _i(j['start']);
    final title = j['title'] as String?;
    if (start == null || title == null) return null;
    return CalendarEvent(title, DateTime.fromMillisecondsSinceEpoch(start * 1000));
  }
}

enum BtKind { headphones, keyboard, mouse, speaker, other }

/// A Bluetooth device as the Mac sees it.
class BtDevice {
  const BtDevice({
    required this.id,
    required this.name,
    required this.kind,
    this.connected = false,
    this.paired = true,
  });

  final String id, name;
  final BtKind kind;
  final bool connected, paired;

  factory BtDevice.fromJson(Map<String, dynamic> j) => BtDevice(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Device',
    kind: BtKind.values.asNameMap()[j['kind']] ?? BtKind.other,
    connected: j['connected'] as bool? ?? false,
    paired: j['paired'] as bool? ?? true,
  );
}

/// The Mac's Bluetooth: paired devices plus nearby ones found while scanning.
class MacBluetooth {
  const MacBluetooth({this.devices = const [], this.scanning = false});

  final List<BtDevice> devices;
  final bool scanning;

  List<BtDevice> get paired => [
    for (final d in devices)
      if (d.paired) d,
  ];
  List<BtDevice> get nearby => [
    for (final d in devices)
      if (!d.paired) d,
  ];

  /// The audio device in use (e.g. earphones), else any connected device.
  BtDevice? get active {
    final connected = [
      for (final d in devices)
        if (d.connected) d,
    ];
    if (connected.isEmpty) return null;
    return connected.firstWhere(
      (d) => d.kind == BtKind.headphones || d.kind == BtKind.speaker,
      orElse: () => connected.first,
    );
  }

  factory MacBluetooth.fromJson(Map<String, dynamic> j) => MacBluetooth(
    devices: [for (final d in (j['devices'] as List? ?? const [])) BtDevice.fromJson(d as Map<String, dynamic>)],
    scanning: j['scanning'] as bool? ?? false,
  );
}

/// The Mac's Wi-Fi. [ssid] is null when off or when macOS hides it (no Location permission).
class MacWifi {
  const MacWifi({required this.on, this.ssid});

  final bool on;
  final String? ssid;

  factory MacWifi.fromJson(Map<String, dynamic> j) =>
      MacWifi(on: j['on'] as bool? ?? false, ssid: j['ssid'] as String?);
}

/// Everything the board shows, plus short history for the System chart.
class BoardData {
  SystemStats? system;
  ClaudeUsage? claude;
  NowPlaying? music;
  CalendarEvent? nextEvent;
  int? slackUnread;
  MacBluetooth? bluetooth;
  MacWifi? wifi;

  /// Last 5 minutes of CPU / memory pressure samples (one per sys message, every 2 s).
  final cpuHistory = <double>[];
  final memHistory = <double>[];
  static const historyLength = 150; // 5 minutes at one sample every 2 s

  /// Applies one message. Returns false for unknown topics.
  bool apply(Map<String, dynamic> j) {
    // Step-1 Mac builds sent {"seq","cpu"} without a topic.
    final topic = j['t'] as String? ?? (j.containsKey('cpu') ? 'sys' : null);
    switch (topic) {
      case 'sys':
        final s = SystemStats.fromJson(j);
        system = s;
        if (s.cpu != null) _push(cpuHistory, s.cpu!);
        if (s.memPct != null) _push(memHistory, s.memPct!);
      case 'claude':
        claude = ClaudeUsage.fromJson(j);
      case 'music':
        music = NowPlaying.fromJson(j);
      case 'event':
        nextEvent = CalendarEvent.fromJson(j);
      case 'slack':
        slackUnread = _i(j['unread']);
      case 'bluetooth':
        bluetooth = MacBluetooth.fromJson(j);
      case 'wifi':
        wifi = MacWifi.fromJson(j);
      default:
        return false;
    }
    return true;
  }

  void _push(List<double> list, double v) {
    list.add(v);
    if (list.length > historyLength) list.removeAt(0);
  }
}
