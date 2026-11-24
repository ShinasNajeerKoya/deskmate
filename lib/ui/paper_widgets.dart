import 'package:flutter/material.dart';

import '../theme/deskmate_tokens.dart';
import 'icons.dart';
import 'widgets.dart';

/// The Paper theme's building blocks: an off-white card with a thin border (or a dark "ink" card),
/// small mono caps labels, tick bars and round or pill buttons.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.ink = false,
    this.label,
    this.fitHeight,
  });

  final Widget child;

  /// The content's natural height: a card that is shorter scales its content down instead of overflowing.
  final double? fitHeight;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool ink;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final radius = BorderRadius.circular(t.radiusTile);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(color: ink ? t.ink : t.panel, borderRadius: radius),
      // The border is drawn over the card, so it takes no room: the padding is the same as in Color Blocks.
      foregroundDecoration: ink ? null : BoxDecoration(borderRadius: radius, border: Border.all(color: t.border)),
      child: fitHeight == null ? child : ShrinkToFit(minHeight: fitHeight!, child: child),
    );
    return Semantics(
      label: label,
      button: onTap != null,
      child: onTap == null ? card : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card),
    );
  }
}

/// A small mono caps label ("CLAUDE", "5H LIMIT").
class PaperLabel extends StatelessWidget {
  const PaperLabel(this.text, {super.key, this.color, this.size = 11});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.num(size, weight: 500, color: color ?? t.muted, letterSpacing: 1),
    );
  }
}

/// A row of thin ticks, [lit] of [count] filled.
class PaperTicks extends StatelessWidget {
  const PaperTicks({super.key, required this.count, required this.lit, this.height = 22, this.litColor, this.offColor});

  final int count, lit;
  final double height;
  final Color? litColor, offColor;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: i < lit ? (litColor ?? t.clay) : (offColor ?? t.border),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A round button: outlined, or filled with ink (the main one).
class PaperRoundButton extends StatelessWidget {
  const PaperRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
    this.filled = false,
    this.iconSize = 18,
    this.color,
  });

  final DIcon icon;
  final String label;
  final VoidCallback? onTap;
  final double size, iconSize;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? t.ink : Colors.transparent,
            border: filled ? null : Border.all(color: t.divider),
          ),
          child: Center(child: DIconView(icon, size: iconSize, color: color ?? (filled ? t.onInk : t.text))),
        ),
      ),
    );
  }
}

/// A rounded text button: filled with ink or outlined; [dark] is for use on an ink card.
class PaperPillButton extends StatelessWidget {
  const PaperPillButton({super.key, required this.label, required this.onTap, this.filled = true, this.dark = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled, dark;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final bg = filled ? (dark ? t.onInk : t.ink) : Colors.transparent;
    final fg = filled ? (dark ? t.ink : t.onInk) : (dark ? t.onInk : t.text);
    final border = filled ? null : Border.all(color: dark ? t.onInk.withValues(alpha: 0.3) : t.divider);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.radiusButton - 2), border: border),
          child: Text(label, maxLines: 1, style: t.ui(13, weight: filled ? 600 : 500, color: fg)),
        ),
      ),
    );
  }
}

/// The header of a Paper page: the page name on the left and small mono notes on the right.
class PaperHeader extends StatelessWidget {
  const PaperHeader({super.key, required this.title, this.subtitle, this.notes = const [], this.leading});

  final String title;
  final String? subtitle;
  final List<Widget> notes;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    // The same box as the Color Blocks header (26 px high and 8 px below it), so a page keeps its place
    // when the theme changes between the two.
    return SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 26,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Text(title, style: t.ui(16, weight: 600)),
                if (subtitle != null) ...[
                  const SizedBox(width: 10),
                  Text(subtitle!.toUpperCase(), style: t.num(12, weight: 500, color: t.muted)),
                ],
                const Spacer(),
                for (var i = 0; i < notes.length; i++) ...[if (i > 0) const SizedBox(width: 16), notes[i]],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small mono note for a header ("10:42", "MAC" with a green dot).
class PaperNote extends StatelessWidget {
  const PaperNote(this.text, {super.key, this.dot});

  final String text;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot != null) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(text.toUpperCase(), style: t.num(12, weight: 500, color: t.muted)),
      ],
    );
  }
}

/// A thin progress bar in the Paper colours.
class PaperBar extends StatelessWidget {
  const PaperBar({super.key, required this.value, this.height = 4, this.fill});

  final double value;
  final double height;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return ProgressLine(value: value, fill: fill ?? t.ink, track: t.border, height: height);
  }
}
