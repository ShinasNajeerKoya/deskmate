import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';

/// Horizon · System: five thin readouts across the top, then a smooth CPU and memory chart for the last
/// 5 minutes with the top 5 apps by CPU and by memory. The floating bar overlays the bottom.
class HorizonSystem extends StatelessWidget {
  const HorizonSystem({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final board = AppScope.of(context).link.board;
    final s = board.system;

    (String, String) speed(double? kbs) {
      if (kbs == null) return ('—', '');
      return kbs >= 1000 ? ((kbs / 1000).toStringAsFixed(1), 'MB/s') : (kbs.round().toString(), 'KB/s');
    }

    final (netV, netU) = speed(s?.netDownKBs);
    final disk = s?.diskMBs;
    final stats = [
      ('CPU', s?.cpu == null ? '—' : '${s!.cpu!.round()}', '%', s?.cores == null ? 'Processor' : '${s!.cores} cores'),
      (
        'Memory',
        s?.memPct == null ? '—' : '${s!.memPct!.round()}',
        '%',
        s?.memUsedGb == null || s?.memTotalGb == null
            ? 'RAM'
            : '${s!.memUsedGb!.toStringAsFixed(1)} of ${s.memTotalGb!.round()} GB',
      ),
      ('Energy', s?.energy ?? '—', '', s?.onPower == null ? 'Impact' : (s!.onPower! ? 'On power' : 'On battery')),
      (
        'Disk',
        disk == null ? '—' : (disk >= 10 ? '${disk.round()}' : disk.toStringAsFixed(1)),
        'MB/s',
        s?.diskFreeGb == null ? 'Storage' : '${s!.diskFreeGb!.round()} GB free',
      ),
      ('Network', netV, netU, s?.netUpKBs == null ? 'Wi-Fi' : '${rate(s!.netUpKBs)} up'),
    ];

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 16, 34, 78),
      child: LayoutBuilder(
        builder:
            (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: max(box.maxWidth, 847),
                height: max(box.maxHeight, 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 92,
                      child: Row(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0) const SizedBox(width: 22),
                            Expanded(child: _Stat(stats[i].$1, stats[i].$2, stats[i].$3, stats[i].$4)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: t.text.withValues(alpha: 0.10))),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _Chart(board.cpuHistory, board.memHistory)),
                            const SizedBox(width: 24),
                            SizedBox(width: 190, child: _List('Top CPU', '% CPU', t.clay, cpuRows)),
                            const SizedBox(width: 24),
                            SizedBox(width: 190, child: _List('Top memory', 'RAM', t.text, memRows)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

Widget _caps(DeskmateTokens t, String s, {double size = 11, Color? color}) => Text(
  s.toUpperCase(),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: t.ui(size, weight: 600, color: color ?? t.muted).copyWith(letterSpacing: size >= 11 ? 2.4 : 2.0),
);

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.unit, this.sub);

  final String label, value, unit, sub;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caps(t, label),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: t.num(40, weight: 200, height: 1, letterSpacing: -1.5)),
                if (unit.isNotEmpty) Text(unit, style: t.ui(16, color: t.muted)),
              ],
            ),
          ),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.ui(11, weight: 500, color: t.muted.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart(this.cpu, this.mem);

  final List<double> cpu, mem;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _caps(t, 'Last 5 minutes')),
            Text('● CPU', style: t.ui(11, weight: 600, color: t.clay)),
            const SizedBox(width: 12),
            Text('● Memory', style: t.ui(11, weight: 600, color: t.text)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Semantics(
            label: 'CPU and memory over the last 5 minutes',
            child: CustomPaint(painter: _ChartPainter(cpu, mem, t.clay, t.text)),
          ),
        ),
      ],
    );
  }
}

/// Memory as a thin light line, CPU as a lime line with a soft fill; both smooth, 0–100 %.
class _ChartPainter extends CustomPainter {
  _ChartPainter(this.cpu, this.mem, this.cpuColor, this.memColor);

  final List<double> cpu, mem;
  final Color cpuColor, memColor;

  Path _smooth(List<double> v, Size size) {
    final pts = [
      for (var i = 0; i < v.length; i++)
        Offset(size.width * i / (v.length - 1), 4 + (size.height - 8) * (1 - (v[i] / 100).clamp(0.0, 1.0))),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.length - 1)];
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
    return path;
  }

  Paint _stroke(Color c, double w) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = c.withValues(alpha: 0.92);

  @override
  void paint(Canvas canvas, Size size) {
    if (cpu.length > 1) {
      final line = _smooth(cpu, size);
      final area =
          Path.from(line)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [memColor.withValues(alpha: 0.22), memColor.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    if (mem.length > 1) canvas.drawPath(_smooth(mem, size), _stroke(memColor, 1.4));
    if (cpu.length > 1) canvas.drawPath(_smooth(cpu, size), _stroke(cpuColor, 1.8));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true; // the lists grow in place
}

class _List extends StatelessWidget {
  const _List(this.title, this.unit, this.color, this.rows);

  final String title, unit;
  final Color color;
  final List<(String, String, double)> rows;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [Expanded(child: _caps(t, title, size: 10)), _caps(t, unit, size: 10)]),
        const SizedBox(height: 4),
        for (final r in rows)
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Expanded(child: Text(r.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 500))),
                const SizedBox(width: 9),
                SizedBox(
                  width: 38,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(
                      children: [
                        Container(height: 3, color: t.text.withValues(alpha: 0.12)),
                        FractionallySizedBox(
                          widthFactor: r.$3.clamp(0.0, 1.0),
                          child: Container(height: 3, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 52,
                  child: Text(
                    r.$2,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: t.ui(13, weight: 500, color: t.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
