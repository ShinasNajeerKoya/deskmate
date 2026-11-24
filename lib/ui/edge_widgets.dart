import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/deskmate_tokens.dart';
import 'icons.dart';

/// Small caps label used all over Edge: 10–11 px, uppercase, letter-spaced.
class EdgeLabel extends StatelessWidget {
  const EdgeLabel(this.text, {super.key, this.color, this.size = 10, this.spacing = 1.5});

  final String text;
  final Color? color;
  final double size, spacing;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.ui(size, color: color ?? t.muted).copyWith(letterSpacing: spacing),
    );
  }
}

/// A ring gauge: a faint track and a coloured arc with round caps. Edge never uses boxes.
class EdgeRing extends StatelessWidget {
  const EdgeRing({
    super.key,
    required this.size,
    required this.value,
    required this.color,
    this.stroke = 8,
    this.child,
  });

  final double size;

  /// 0..1 (clamped).
  final double value;
  final Color color;

  /// Stroke width on the design's 100-unit ring (7–8).
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(t.ringTrack, color, value.clamp(0.0, 1.0), stroke / 100 * size),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.track, this.color, this.value, this.width);

  final Color track, color;
  final double value, width;

  @override
  void paint(Canvas canvas, Size size) {
    // Radius 42 of 100, like the design.
    final radius = size.width * 0.42;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(rect.center, radius, paint..color = track);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.width != width;
}

/// A thin progress line with a round knob (Edge music).
class EdgeProgress extends StatelessWidget {
  const EdgeProgress({super.key, required this.value, this.height = 4, this.knob = 12});

  final double value;
  final double height, knob;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: knob,
      child: LayoutBuilder(
        builder:
            (context, box) => Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(color: t.ringTrack, borderRadius: BorderRadius.circular(height / 2)),
                ),
                Container(
                  height: height,
                  width: box.maxWidth * v,
                  decoration: BoxDecoration(color: t.text, borderRadius: BorderRadius.circular(height / 2)),
                ),
                Positioned(
                  left: box.maxWidth * v - knob / 2,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(color: t.text, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

/// The header of an Edge page: the page's icon and name on the left (tap to go Home) and a
/// small caps note on the right. Every Edge page except Home uses it.
class EdgePageHeader extends StatelessWidget {
  const EdgePageHeader({super.key, required this.icon, required this.color, required this.title, required this.note});

  final DIcon icon;
  final Color color;
  final String title, note;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AppScope.of(context).open(PageId.home),
            child: Semantics(
              button: true,
              label: 'Back to Home',
              child: Row(
                children: [
                  DIconView(icon, size: 16, color: color, strokeWidth: 2),
                  const SizedBox(width: 8),
                  Text(title, style: t.num(18, weight: 500)),
                ],
              ),
            ),
          ),
          EdgeLabel(note, size: 11),
        ],
      ),
    );
  }
}

/// One setting on an Edge page: a name with a small note, then its value or control on the right.
class EdgeSettingRow extends StatelessWidget {
  const EdgeSettingRow({
    super.key,
    required this.label,
    required this.sub,
    required this.trailing,
    this.onTap,
    this.chevron = true,
  });

  final String label, sub;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.hairline))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(15, weight: 500)),
                    const SizedBox(height: 2),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(11, color: t.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
              if (chevron) ...[const SizedBox(width: 8), DIconView(DIcon.chevronRight, size: 18, color: t.muted)],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill switch between a few options (12-hour / 24-hour).
class EdgeSegmented extends StatelessWidget {
  const EdgeSegmented({super.key, required this.options, required this.selected, required this.onSelect});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.text.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(17)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            Semantics(
              button: true,
              selected: i == selected,
              label: options[i],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? t.text : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    options[i],
                    style: t.ui(13, weight: i == selected ? 600 : 400, color: i == selected ? t.bg : t.textSoft),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
