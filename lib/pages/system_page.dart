import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../data/models.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/format.dart';
import '../ui/widgets.dart';

class SystemPage extends StatelessWidget {
  const SystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final board = AppScope.of(context).link.board;
    final s = board.system;

    String gb(double? v) => v == null ? '—' : (v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1));
    final stats = [
      ('CPU', pct(s?.cpu), s?.cores == null ? '—' : '${s!.cores} cores', t.clay, t.clayInk),
      (
        'Memory',
        pct(s?.memPct),
        s?.memUsedGb == null ? '—' : '${gb(s!.memUsedGb)} of ${gb(s.memTotalGb)} GB',
        t.violet,
        t.text,
      ),
      (
        'Energy',
        s?.energy ?? '—',
        s?.onPower == null ? '—' : (s!.onPower! ? 'On power' : 'On battery'),
        t.mint,
        t.mintInk,
      ),
      (
        'Disk',
        s?.diskMBs == null ? '—' : '${s!.diskMBs!.round()} MB/s',
        s?.diskFreeGb == null ? '—' : '${s!.diskFreeGb!.round()} GB free',
        t.butter,
        t.butterInk,
      ),
      (
        'Network',
        rate(s?.netDownKBs),
        s?.netUpKBs == null ? '—' : 'down · ${rate(s!.netUpKBs)} up',
        t.cream,
        t.creamInk,
      ),
    ];

    final statRow = Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Tile(
              color: stats[i].$4,
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              label: stats[i].$1,
              fitHeight: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stats[i].$1, style: t.ui(12, weight: 600, color: stats[i].$5)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(stats[i].$2, style: t.num(28, height: 1, color: stats[i].$5)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stats[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(11, weight: 500, color: stats[i].$5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    Widget legend(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: t.ui(12, color: t.muted)),
      ],
    );

    final chart = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Last 5 minutes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(12, weight: 600),
                ),
              ),
              const SizedBox(width: 8),
              // The chart tile is narrower now (two process lists sit beside it): the legend scales down to fit.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(children: [legend(t.clay, 'CPU'), const SizedBox(width: 12), legend(t.lilac, 'Memory')]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Semantics(
              label: 'CPU and memory pressure over the last 5 minutes',
              child: CustomPaint(
                painter: _TrendPainter(
                  series: [(board.memHistory, t.lilac, 2.0), (board.cpuHistory, t.clay, 2.5)],
                  axis: t.divider,
                  capacity: BoardData.historyLength,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Two short lists: the 5 apps using the most CPU and the 5 using the most memory.
    Widget procTile(String title, String unit, Color fill, List<(String, String, double)> rows) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(12, weight: 600))),
              Text(unit, style: t.ui(12, color: t.muted)),
            ],
          ),
          const SizedBox(height: 4),
          // Show as many as fit.
          Expanded(
            child: LayoutBuilder(
              builder:
                  (context, box) => Column(
                    children: [
                      for (final r in rows.take((box.maxHeight / 26).floor().clamp(0, rows.length)))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(r.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 36,
                                child: ProgressLine(value: r.$3, fill: fill, track: t.panel2, height: 5),
                              ),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  r.$2,
                                  maxLines: 1,
                                  textAlign: TextAlign.right,
                                  style: t.ui(13, color: t.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );

    final cpuRows = [
      for (final p in (s?.procs ?? const <ProcStat>[]).take(5)) (p.name, '${p.cpu.round()}%', min(1.0, p.cpu / 20)),
    ];
    final mem = s?.memProcs ?? const <MemProc>[];
    final totalMb = (s?.memTotalGb ?? 0) * 1024;
    final biggest = mem.isEmpty ? 1 : mem.map((m) => m.mb).reduce(max);
    final memRows = [
      for (final m in mem.take(5))
        (m.name, megabytes(m.mb), (totalMb > 0 ? m.mb / (totalMb * 0.25) : m.mb / biggest).clamp(0.02, 1.0)),
    ];
    final topCpu = procTile('Top CPU', '% CPU', t.clay, cpuRows);
    final topMem = procTile('Top memory', 'RAM', t.lilac, memRows);

    return LayoutBuilder(
      builder:
          (context, box) => Column(
            children: [
              SizedBox(height: (box.maxHeight * 0.32).clamp(64.0, 100.0), child: statRow),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: chart),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: topCpu),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: topMem),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}

/// Line chart of 0–100 values, newest on the right.
class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.series, required this.axis, required this.capacity});

  final List<(List<double>, Color, double)> series;
  final Color axis;
  final int capacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = axis);
    final dx = size.width / (capacity - 1);
    for (final (values, color, width) in series) {
      if (values.length < 2) continue;
      final path = Path();
      final start = capacity - values.length;
      for (var i = 0; i < values.length; i++) {
        final p = Offset((start + i) * dx, size.height * (1 - values[i].clamp(0, 100) / 100));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true;
}
