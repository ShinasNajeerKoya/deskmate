import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/deskmate_tokens.dart';
import 'icons.dart';

/// A cell in a [BentoGrid]: zero-based column/row plus spans.
class BentoCell {
  const BentoCell(this.col, this.row, this.child, {this.colSpan = 1, this.rowSpan = 1});
  final int col, row, colSpan, rowSpan;
  final Widget child;
}

/// Equal-fraction grid like the design's CSS `grid-template-columns: repeat(n, 1fr)`.
class BentoGrid extends StatelessWidget {
  const BentoGrid({super.key, required this.columns, required this.rows, this.gap = 8, required this.cells});

  final int columns, rows;
  final double gap;
  final List<BentoCell> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cw = (box.maxWidth - gap * (columns - 1)) / columns;
        final rh = (box.maxHeight - gap * (rows - 1)) / rows;
        return Stack(
          children: [
            for (final c in cells)
              Positioned(
                left: c.col * (cw + gap),
                top: c.row * (rh + gap),
                width: c.colSpan * cw + (c.colSpan - 1) * gap,
                height: c.rowSpan * rh + (c.rowSpan - 1) * gap,
                child: c.child,
              ),
          ],
        );
      },
    );
  }
}

/// A rounded colour block. Tappable when [onTap] is set.
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.color,
    required this.child,
    this.radius,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.label,
    this.fitHeight,
  });

  final Color color;
  final Widget child;

  /// If set, content shorter than this scales down instead of overflowing.
  final double? fitHeight;
  final double? radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap, onLongPress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? DeskmateTokens.of(context).radiusTile);
    return Semantics(
      label: label,
      button: onTap != null,
      child: Material(
        color: color,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: padding,
            child: fitHeight == null ? child : ShrinkToFit(minHeight: fitHeight!, child: child),
          ),
        ),
      ),
    );
  }
}

/// Placeholder block shown while looking for the Mac for the first time.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key, this.radius});
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Container(
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(radius ?? t.radiusTile)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_bar(t, 60, 10), const Spacer(), _bar(t, 90, 22)],
      ),
    );
  }

  Widget _bar(DeskmateTokens t, double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: t.panel2, borderRadius: BorderRadius.circular(h / 2)),
  );
}

/// Round or rounded-rect icon button used by the music controls etc.
class IconBlockButton extends StatelessWidget {
  const IconBlockButton({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.width = 44,
    this.height = 44,
    this.radius,
    this.iconSize = 18,
  });

  final DIcon icon;
  final String label;
  final Color background, foreground;
  final VoidCallback onTap;
  final double width, height, iconSize;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(radius ?? height / 2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: width,
              height: height,
              child: Center(child: DIconView(icon, size: iconSize, color: foreground)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of rounded segments, e.g. the Claude 10-step usage bar.
class SegmentBar extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.count,
    required this.filled,
    required this.on,
    required this.off,
    this.height = 10,
    this.gap = 4,
    this.radius,
  });

  final int count, filled;
  final Color on, off;
  final double height, gap;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: i < filled ? on : off,
                borderRadius: BorderRadius.circular(radius ?? height / 2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Thin progress bar.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, required this.fill, required this.track, this.height = 6});

  final double value; // 0..1
  final Color fill, track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(height / 2))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill, e.g. "5-hour limit" or the header chips.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.child, required this.color, this.padding});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
    child: child,
  );
}

/// Dot used in chips and status labels.
class Dot extends StatelessWidget {
  const Dot({super.key, required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Lays the child out at [minHeight] when the space is shorter than that, then
/// scales it down evenly (text included) to fit, so tiles never overflow when a
/// banner or a smaller screen takes height away.
class ShrinkToFit extends StatelessWidget {
  const ShrinkToFit({super.key, required this.minHeight, required this.child});

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedHeight || box.maxHeight >= minHeight) return child;
        final scale = box.maxHeight / minHeight;
        return FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topLeft,
          child: SizedBox(width: box.maxWidth / scale, height: minHeight, child: child),
        );
      },
    );
  }
}

/// Label above a big value when there's room; label and value side by side in
/// one row when the tile is too short. The value scales down to fit either way.
class LabelValue extends StatelessWidget {
  const LabelValue({super.key, required this.label, required this.value, this.columnMinHeight = 46});

  final Widget label, value;

  /// Below this height the tile switches to a single row.
  final double columnMinHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight >= columnMinHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topLeft, child: label),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft, child: value)),
            ],
          );
        }
        return Row(
          children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: label)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: value)),
          ],
        );
      },
    );
  }
}

/// Album artwork from the computer, or a music-note placeholder while it hasn't arrived.
class ArtImage extends StatelessWidget {
  const ArtImage({super.key, required this.bytes, this.radius = 14, this.iconSize = 24, this.fit = BoxFit.cover});

  final Uint8List? bytes;
  final double radius, iconSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final b = bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child:
          b == null
              ? ColoredBox(
                color: t.violet2,
                child: Center(child: DIconView(DIcon.music, size: iconSize, color: t.lilac, strokeWidth: 1.6)),
              )
              : Image.memory(b, fit: fit, gaplessPlayback: true, filterQuality: FilterQuality.medium),
    );
  }
}
