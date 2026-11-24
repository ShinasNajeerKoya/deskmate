import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';
import '../../ui/paper_widgets.dart';

/// Paper · System: five stat cards, a 5-minute CPU and memory graph, and the top 5 apps by CPU and by memory.
class PaperSystem extends StatelessWidget {
  const PaperSystem({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final board = scope.link.board;
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

    final statRow = Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PaperCard(
              label: stats[i].$1,
              fitHeight: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PaperLabel(stats[i].$1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(stats[i].$2, style: t.num(26, weight: 600, height: 1)),
                        if (stats[i].$3.isNotEmpty)
                          Text(' ${stats[i].$3}', style: t.num(12, weight: 500, color: t.muted)),
                      ],
                    ),
                  ),
                  Text(stats[i].$4, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(11, color: t.muted)),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    final graph = PaperCard(
      label: 'Last 5 minutes',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Flexible(child: PaperLabel('Last 5 minutes')),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      PaperLabel('● CPU', color: t.clay),
                      const SizedBox(width: 12),
                      PaperLabel('● Memory', color: t.ink),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Semantics(
              label: 'CPU and memory over the last 5 minutes',
              child: CustomPaint(painter: _GraphPainter(board.cpuHistory, board.memHistory, t.clay, t.ink)),
            ),
          ),
        ],
      ),
    );

    Widget list(String title, String unit, Color fill, List<(String, String, double)> rows) => PaperCard(
      label: title,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: PaperLabel(title)), const SizedBox(width: 6), PaperLabel(unit)]),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder:
                  (context, box) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final r in rows.take((box.maxHeight / 24).floor().clamp(0, rows.length)))
                        SizedBox(
                          height: 24,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(r.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(width: 40, child: PaperBar(value: r.$3, fill: fill)),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  r.$2,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  style: t.num(12, weight: 500, color: t.muted),
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

    return Column(
      children: [
        PaperHeader(
          title: 'System',
          notes: [PaperNote(scope.link.wifiHubName ?? 'Computer'), PaperNote(clockText(now, use24h))],
        ),
        SizedBox(height: 92, child: statRow),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: graph),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: list('Top CPU', '% CPU', t.clay, cpuRows)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: list('Top memory', 'RAM', t.ink, memRows)),
            ],
          ),
        ),
      ],
    );
  }
}

/// CPU as a line with a soft fill, memory as a thinner ink line, both 0–100%.
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
      final area =
          Path.from(_line(cpu, size))
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
