import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/edge_widgets.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';

/// Edge · System (Activity Monitor style): five rings, a 5-minute CPU and memory graph, and
/// the top processes.
class EdgeSystem extends StatelessWidget {
  const EdgeSystem({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EdgePageHeader(icon: DIcon.system, color: t.teal, title: 'System', note: link.wifiHubName ?? 'Computer'),
          Expanded(
            // Laid out at the design's size; shorter or narrower screens scale it down.
            child: LayoutBuilder(
              builder:
                  (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: max(box.maxWidth, 859),
                      height: max(box.maxHeight, 320),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 108, child: _Rings()),
                          SizedBox(height: 10),
                          Expanded(child: _Details()),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rings extends StatelessWidget {
  const _Rings();

  /// "1.2" and "MB/s" for 1200 KB/s; "80" and "KB/s" for 80.
  static (String, String) _speed(double? kbs) {
    if (kbs == null) return ('—', '');
    return kbs >= 1000 ? ((kbs / 1000).toStringAsFixed(1), 'MB/s') : (kbs.round().toString(), 'KB/s');
  }

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final s = AppScope.of(context).link.board.system;
    final energy = s?.energy;
    final (netValue, netUnit) = _speed(s?.netDownKBs);
    final disk = s?.diskMBs;
    final rings = [
      _RingSpec(
        'CPU',
        s?.cpu == null ? '—' : '${s!.cpu!.round()}',
        '%',
        s?.cores == null ? 'Processor' : '${s!.cores} cores',
        t.teal,
        (s?.cpu ?? 0) / 100,
      ),
      _RingSpec(
        'Memory',
        s?.memPct == null ? '—' : '${s!.memPct!.round()}',
        '%',
        s?.memUsedGb == null || s?.memTotalGb == null
            ? 'RAM'
            : '${s!.memUsedGb!.toStringAsFixed(1)} of ${s.memTotalGb!.round()} GB',
        t.accentViolet,
        (s?.memPct ?? 0) / 100,
      ),
      _RingSpec(
        'Energy',
        energy ?? '—',
        '',
        s?.onPower == null ? 'Impact' : (s!.onPower! ? 'On power' : 'On battery'),
        t.ok,
        switch (energy) {
          'Low' => 0.2,
          'Medium' => 0.5,
          'High' => 0.85,
          _ => 0.0,
        },
      ),
      _RingSpec(
        'Disk',
        disk == null ? '—' : (disk >= 10 ? '${disk.round()}' : disk.toStringAsFixed(1)),
        'MB/s',
        s?.diskFreeGb == null ? 'Storage' : '${s!.diskFreeGb!.round()} GB free',
        t.amber,
        ((disk ?? 0) / 40).clamp(0.0, 1.0),
      ),
      _RingSpec(
        'Network',
        netValue,
        netUnit,
        s?.netUpKBs == null ? 'Wi-Fi' : '${rate(s!.netUpKBs)} up',
        t.clay,
        ((s?.netDownKBs ?? 0) / 3000).clamp(0.0, 1.0),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < rings.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _RingTile(spec: rings[i])),
        ],
      ],
    );
  }
}

class _RingSpec {
  const _RingSpec(this.label, this.value, this.unit, this.sub, this.color, this.fill);

  final String label, value, unit, sub;
  final Color color;
  final double fill;
}

class _RingTile extends StatelessWidget {
  const _RingTile({required this.spec});

  final _RingSpec spec;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EdgeRing(
          size: 68,
          value: spec.fill,
          color: spec.color,
          child: SizedBox(
            width: 46,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(spec.value, style: t.num(18, weight: 500, height: 1)),
                  if (spec.unit.isNotEmpty) Text(spec.unit, style: t.ui(10, color: t.muted)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        EdgeLabel(spec.label, color: spec.color, size: 9),
        const SizedBox(height: 3),
        Text(spec.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(10, color: t.muted)),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final board = AppScope.of(context).link.board;
    final s = board.system;
    final cpu = [
      for (final p in (s?.procs ?? const <ProcStat>[]).take(5))
        (p.name, '${p.cpu.round()}%', (p.cpu / 20).clamp(0.02, 1.0)),
    ];
    final mem = s?.memProcs ?? const <MemProc>[];
    // The bar is each app's share of the computer's memory (full at a quarter of it), else relative to the biggest.
    final total = (s?.memTotalGb ?? 0) * 1024;
    final biggest = mem.isEmpty ? 1 : mem.map((m) => m.mb).reduce(max);
    final memRows = [
      for (final m in mem.take(5))
        (m.name, megabytes(m.mb), (total > 0 ? m.mb / (total * 0.25) : m.mb / biggest).clamp(0.02, 1.0)),
    ];
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.hairline))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Flexible(child: EdgeLabel('Last 5 minutes', size: 11)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: [
                            EdgeLabel('● CPU', size: 11, color: t.teal),
                            const SizedBox(width: 12),
                            EdgeLabel('● Memory', size: 11, color: t.accentViolet),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Semantics(
                    label: 'CPU and memory over the last 5 minutes',
                    child: CustomPaint(
                      painter: _GraphPainter(board.cpuHistory, board.memHistory, t.teal, t.accentViolet),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Expanded(flex: 8, child: _ProcList(title: 'Top CPU', unit: '% CPU', rows: cpu, color: t.teal)),
          const SizedBox(width: 28),
          Expanded(
            flex: 8,
            child: _ProcList(
              title: 'Top memory',
              unit: 'RAM',
              rows: mem.isEmpty ? const [] : memRows,
              color: t.accentViolet,
            ),
          ),
        ],
      ),
    );
  }
}

/// A short list of apps (name, a thin bar, the value). Shows as many as fit.
class _ProcList extends StatelessWidget {
  const _ProcList({required this.title, required this.unit, required this.rows, required this.color});

  final String title, unit;
  final List<(String, String, double)> rows; // name, value, bar 0..1
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [EdgeLabel(title, size: 11), EdgeLabel(unit, size: 11)],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder:
                (context, box) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in rows.take((box.maxHeight / 27).floor().clamp(0, rows.length)))
                      SizedBox(
                        height: 27,
                        child: Row(
                          children: [
                            Expanded(child: Text(r.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13))),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 44,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Stack(
                                  children: [
                                    Container(height: 4, color: t.ringTrack),
                                    FractionallySizedBox(widthFactor: r.$3, child: Container(height: 4, color: color)),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                r.$2,
                                textAlign: TextAlign.right,
                                maxLines: 1,
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
    );
  }
}

/// CPU as a line with a soft fill under it, memory as a thinner line, both 0–100%.
class _GraphPainter extends CustomPainter {
  _GraphPainter(this.cpu, this.mem, this.cpuColor, this.memColor);

  final List<double> cpu, mem;
  final Color cpuColor, memColor;

  Path _line(List<double> v, Size size) {
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = v.length == 1 ? size.width : size.width * i / (v.length - 1);
      final y = size.height * (1 - (v[i] / 100).clamp(0.0, 1.0));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cpu.length > 1) {
      final line = _line(cpu, size);
      final area =
          Path.from(line)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close();
      canvas.drawPath(area, Paint()..color = cpuColor.withValues(alpha: 0.12));
    }
    Paint stroke(Color c, double w) =>
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeJoin = StrokeJoin.round
          ..color = c;
    if (mem.length > 1) canvas.drawPath(_line(mem, size), stroke(memColor, 1.6));
    if (cpu.length > 1) canvas.drawPath(_line(cpu, size), stroke(cpuColor, 2));
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true; // the lists grow in place
}
