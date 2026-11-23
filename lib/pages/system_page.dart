import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
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
              Expanded(child: Text('Last 5 minutes', style: t.ui(12, weight: 600))),
              legend(t.clay, 'CPU'),
              const SizedBox(width: 12),
              legend(t.lilac, 'Memory pressure'),
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
                  capacity: 300,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final procs = s?.procs ?? const [];
    final top = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Top processes', style: t.ui(12, weight: 600))),
              Text('% CPU', style: t.ui(12, color: t.muted)),
            ],
          ),
          const SizedBox(height: 4),
          // Show as many processes as fit (up to 5).
          Expanded(
            child: LayoutBuilder(
              builder:
                  (context, box) => Column(
                    children: [
                      for (final p in procs.take((box.maxHeight / 26).floor().clamp(0, 5)))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13)),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 60,
                                child: ProgressLine(
                                  value: min(1, p.cpu / 20),
                                  fill: t.clay,
                                  track: t.panel2,
                                  height: 5,
                                ),
                              ),
                              SizedBox(
                                width: 38,
                                child: Text(
                                  '${p.cpu.round()}%',
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

    return LayoutBuilder(
      builder:
          (context, box) => Column(
            children: [
              SizedBox(height: (box.maxHeight * 0.32).clamp(64.0, 100.0), child: statRow),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(flex: 3, child: chart), const SizedBox(width: 8), Expanded(flex: 2, child: top)],
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
