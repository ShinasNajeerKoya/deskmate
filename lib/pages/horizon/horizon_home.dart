import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/chrome.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../../ui/widgets.dart';

/// Horizon · Home: a thin clock over a day timeline and three live readouts (Claude 5-hour, CPU, memory) on the
/// left; a tall, tappable Now-playing panel with two chips (Bluetooth, battery) on the right. The floating bar
/// overlays the bottom, so the page keeps room for it.
class HorizonHome extends StatelessWidget {
  const HorizonHome({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 16, 34, 0),
      child: LayoutBuilder(
        builder:
            (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: max(box.maxWidth, 847),
                height: max(box.maxHeight, 390),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 520, child: _Left(now: now)),
                    const SizedBox(width: 28),
                    const Expanded(child: Padding(padding: EdgeInsets.only(bottom: 68), child: _Right())),
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
  style: t.ui(size, weight: 600, color: color ?? t.muted).copyWith(letterSpacing: 2.4),
);

class _Left extends StatelessWidget {
  const _Left({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final (h, m) = clockDigits(now, scope.settings.use24h);
    final board = scope.link.board;
    final c = board.claude, s = board.system;
    final reset = c?.fiveHourResetMin;
    final hours = c?.blockHours ?? const <int>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => scope.open(PageId.timer),
          child: Semantics(
            button: true,
            label: 'Open timer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$h:$m', style: t.num(112, weight: 100, height: 0.9, letterSpacing: -5)),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(two(now.second), style: t.num(20, weight: 300, height: 1, color: t.muted)),
                    ),
                    const SizedBox(width: 22),
                    // The weekday above, the date below (more room under the clock).
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _caps(t, _weekday(now), color: t.text),
                          const SizedBox(height: 6),
                          Text(_date(now), style: t.ui(15, color: t.textSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(height: 28, child: CustomPaint(painter: _DayLine(now, t))),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Readout(
              label: 'Claude · 5h',
              value: c?.fiveHourPct,
              onTap: () => scope.open(PageId.claude),
              chart: _Columns(hours: hours),
              note: reset == null ? 'Claude' : 'resets in ${hm(Duration(minutes: reset))}',
            ),
            _Readout(
              label: 'CPU',
              value: s?.cpu,
              onTap: () => scope.open(PageId.system),
              chart: _Line(board.cpuHistory, t.text),
              note: s?.cores == null ? 'Processor' : '${s!.cores} cores',
            ),
            _Readout(
              label: 'Memory',
              value: s?.memPct,
              onTap: () => scope.open(PageId.system),
              chart: _Line(board.memHistory, t.text),
              note:
                  s?.memUsedGb == null || s?.memTotalGb == null
                      ? 'RAM'
                      : '${s!.memUsedGb!.toStringAsFixed(1)} of ${s.memTotalGb!.round()} GB',
            ),
          ],
        ),
        const SizedBox(height: 76),
      ],
    );
  }

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _weekday(DateTime d) => _days[d.weekday - 1];

  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}

/// One readout: caps label, big thin number, a small chart and a note. Tap opens its page.
class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.value, required this.chart, required this.note, this.onTap});

  final String label, note;
  final double? value;
  final Widget chart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _caps(t, label),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value == null ? '—' : '${value!.round()}',
                    style: t.num(42, weight: 200, height: 1, letterSpacing: -2),
                  ),
                  Text('%', style: t.ui(18, color: t.muted)),
                ],
              ),
            ),
            SizedBox(height: 44, child: chart),
            const SizedBox(height: 6),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.ui(11, weight: 500, color: t.muted.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hourly columns of the current 5-hour block; the newest hour is lime.
class _Columns extends StatelessWidget {
  const _Columns({required this.hours});

  final List<int> hours;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final maxHour = hours.isEmpty ? 1 : max(1, hours.reduce(max));
    final current = hours.lastIndexWhere((v) => v > 0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < hours.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: FractionallySizedBox(
              heightFactor: max(0.09, hours[i] / maxHour),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(1)),
                  color: i == current ? t.clay : null,
                  gradient:
                      i == current
                          ? null
                          : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [t.text.withValues(alpha: 0.85), t.text.withValues(alpha: 0.18)],
                          ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A smooth line with a soft fill (0–100 %).
class _Line extends StatelessWidget {
  const _Line(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LinePainter(values, color), size: Size.infinite);
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.v, this.color);

  final List<double> v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
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
    final area =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => true; // the lists grow in place
}

/// The day as a line: hourly ticks, 00 / 06 / 12 / 18 / 24 labels, the part already gone brighter, a lime marker now.
class _DayLine extends CustomPainter {
  _DayLine(this.now, this.t);

  final DateTime now;
  final DeskmateTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final frac = (now.hour * 60 + now.minute) / 1440;
    final base = t.text;
    canvas.drawRect(Rect.fromLTWH(0, 5, w, 1), Paint()..color = base.withValues(alpha: 0.14));
    canvas.drawRect(
      Rect.fromLTWH(0, 5, w * frac, 1),
      Paint()
        ..shader = LinearGradient(
          colors: [base.withValues(alpha: 0), base.withValues(alpha: 0.7)],
        ).createShader(Rect.fromLTWH(0, 0, max(1, w * frac), 1)),
    );
    for (var h = 0; h <= 24; h++) {
      final major = h % 6 == 0;
      final x = w * h / 24;
      canvas.drawRect(
        Rect.fromLTWH(x - (h == 24 ? 1 : 0), major ? 0 : 3, 1, major ? 10 : 5),
        Paint()..color = base.withValues(alpha: major ? 0.5 : 0.22),
      );
      if (major) {
        final tp = TextPainter(
          text: TextSpan(
            text: two(h),
            style: t.ui(10, weight: 500, color: t.muted.withValues(alpha: 0.8)).copyWith(letterSpacing: 1.5),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset((x - tp.width / 2).clamp(0.0, w - tp.width), 15));
      }
    }
    final x = w * frac;
    canvas.drawCircle(
      Offset(x, 5.5),
      7,
      Paint()
        ..color = t.clay.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(Offset(x, 5.5), 4, Paint()..color = t.clay);
  }

  @override
  bool shouldRepaint(_DayLine old) => old.now.minute != now.minute || old.now.hour != now.hour;
}

class _Right extends StatelessWidget {
  const _Right();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final link = scope.link;
    final m = link.board.music;
    final playing = m?.playing ?? false;
    final progress = (m == null || m.durationS == 0) ? 0.0 : m.positionS / m.durationS;
    final active = link.board.bluetooth?.active;
    final level = scope.battery.level;

    Widget round(DIcon icon, String label, String cmd, {required double w, required double h, bool main = false}) =>
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => link.sendCommand(cmd),
            child: Container(
              width: w,
              height: h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: main ? t.text : const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(h / 2),
                border: main ? null : Border.all(color: const Color(0x24FFFFFF)),
                boxShadow:
                    main ? const [BoxShadow(color: Color(0x598EA2FF), blurRadius: 24, offset: Offset(0, 10))] : null,
              ),
              child: DIconView(icon, size: main ? 26 : 22, color: main ? t.bg : t.text),
            ),
          ),
        );

    Widget chip(Widget child, {VoidCallback? onTap, String? label}) => Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: child,
        ),
      ),
    );

    final panel = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => scope.open(PageId.music),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            stops: [0, 0.62],
            colors: [Color(0x338EA2FF), Color(0x09FFFFFF)],
          ),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: ArtImage(bytes: link.board.art[m?.art], radius: 24, iconSize: 36),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _caps(t, playing ? 'Now playing' : 'Paused', size: 10),
                      const SizedBox(height: 6),
                      Text(
                        m?.title ?? 'Nothing playing',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(24, weight: 500, height: 1.12).copyWith(letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m?.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(15, color: t.textSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(mmss(m?.positionS ?? 0), style: t.ui(11, weight: 500, color: t.muted)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Stack(
                          children: [
                            Container(height: 3, color: t.text.withValues(alpha: 0.16)),
                            FractionallySizedBox(
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(height: 3, color: t.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(mmss(m?.durationS ?? 0), style: t.ui(11, weight: 500, color: t.muted)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    round(DIcon.previous, 'Previous', 'music.previous', w: 62, h: 56),
                    round(
                      playing ? DIcon.pause : DIcon.play,
                      playing ? 'Pause' : 'Play',
                      'music.toggle',
                      w: 78,
                      h: 64,
                      main: true,
                    ),
                    round(DIcon.next, 'Next', 'music.next', w: 62, h: 56),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: panel),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: chip(
                  label: 'Bluetooth',
                  onTap: () => scope.open(PageId.control),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DIconView(DIcon.bluetooth, size: 17, color: t.text),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          active?.name ?? 'Not connected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.ui(13, weight: 600),
                        ),
                      ),
                      if (active != null) ...[
                        const SizedBox(width: 9),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: t.clay,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: t.clay, blurRadius: 8)],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: chip(
                  label: 'Phone battery',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BatteryGlyph(level: level, charging: scope.battery.charging, color: t.text, bg: t.bg),
                      const SizedBox(width: 8),
                      Text(level == null ? '—' : '$level%', style: t.ui(13, weight: 600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A battery like the phone's own: an outline with a nub, filled (with a small gap) to the charge level, and a
/// bolt over it while charging. Red at 10% or less, orange up to 30%, green above.
class _BatteryGlyph extends StatelessWidget {
  const _BatteryGlyph({required this.level, required this.charging, required this.color, required this.bg});

  final int? level;
  final bool charging;
  final Color color, bg;

  static const red = Color(0xFFF2564D), orange = Color(0xFFFFA630), green = Color(0xFF4CD964);

  @override
  Widget build(BuildContext context) {
    final l = level;
    final fill = l == null ? color.withValues(alpha: 0.3) : (l <= 10 ? red : (l <= 30 ? orange : green));
    return Semantics(
      label: charging ? 'Charging' : 'On battery',
      child: CustomPaint(size: const Size(31, 15), painter: _BatteryPainter((l ?? 0) / 100, charging, fill, color, bg)),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter(this.f, this.charging, this.fill, this.outline, this.bg);

  final double f;
  final bool charging;
  final Color fill, outline, bg;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromLTRBR(0.6, 0.6, size.width - 3.4, size.height - 0.6, const Radius.circular(4.5));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = outline.withValues(alpha: 0.55),
    );
    // The nub.
    canvas.drawRRect(
      RRect.fromLTRBR(
        size.width - 2,
        size.height / 2 - 2.5,
        size.width,
        size.height / 2 + 2.5,
        const Radius.circular(1.2),
      ),
      Paint()..color = outline.withValues(alpha: 0.55),
    );
    // The charge, inset by a small gap.
    const gap = 2.0;
    final inner = body.deflate(gap + 0.6);
    final w = inner.width * f.clamp(0.0, 1.0);
    if (w > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(inner.left, inner.top, inner.left + max(w, 3.0), inner.bottom, const Radius.circular(2.6)),
        Paint()..color = fill,
      );
    }
    if (charging) {
      final cx = body.center.dx, cy = body.center.dy;
      final bolt =
          Path()
            ..moveTo(cx + 1.2, cy - 5.2)
            ..lineTo(cx - 3.4, cy + 0.8)
            ..lineTo(cx - 0.4, cy + 0.8)
            ..lineTo(cx - 1.2, cy + 5.2)
            ..lineTo(cx + 3.4, cy - 0.9)
            ..lineTo(cx + 0.4, cy - 0.9)
            ..close();
      canvas.drawPath(
        bolt,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = bg,
      );
      canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter old) =>
      old.f != f || old.charging != charging || old.fill != fill || old.outline != outline;
}
