import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/deskmate_tokens.dart';

/// Edge's background: the dark base with two soft colour glows that differ per page
/// (positions and strengths from the "Edge" boards in the design canvas).
class EdgeGlow extends StatelessWidget {
  const EdgeGlow({super.key, required this.page, required this.child});

  final PageId page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final glows = _glows(t, page);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: t.bg),
        for (final g in glows)
          Positioned.fill(
            child: LayoutBuilder(
              builder:
                  (context, box) => CustomPaint(
                    painter: _GlowPainter(g.color.withValues(alpha: g.alpha), g.x, g.y, g.rx, g.ry),
                    size: box.biggest,
                  ),
            ),
          ),
        child,
      ],
    );
  }

  /// x and y are fractions of the screen; rx and ry are the glow's radii in dp.
  static List<_Glow> _glows(DeskmateTokens t, PageId page) => switch (page) {
    PageId.home => [_Glow(t.glowTeal, 0.22, 0.18, 0.08, 520, 260), _Glow(t.glowViolet, 0.20, 0.88, 0.92, 520, 280)],
    PageId.claude => [_Glow(t.glowClay, 0.16, 0.82, 0.06, 520, 260), _Glow(t.glowViolet, 0.18, 0.10, 0.96, 520, 280)],
    PageId.music => [_Glow(t.glowPurple, 0.28, 0.22, 0.40, 560, 280), _Glow(t.glowClay, 0.14, 0.92, 0.08, 480, 240)],
    PageId.system => [_Glow(t.glowTeal, 0.22, 0.14, 0.06, 520, 260), _Glow(t.glowViolet, 0.18, 0.90, 0.96, 520, 280)],
    PageId.control => [_Glow(t.glowMint, 0.18, 0.16, 0.12, 520, 260), _Glow(t.glowViolet, 0.16, 0.90, 0.94, 520, 280)],
    // Timer and Settings have no Edge board yet (or it wasn't read): the Home glow.
    _ => [_Glow(t.glowTeal, 0.22, 0.18, 0.08, 520, 260), _Glow(t.glowViolet, 0.20, 0.88, 0.92, 520, 280)],
  };
}

class _Glow {
  const _Glow(this.color, this.alpha, this.x, this.y, this.rx, this.ry);
  final Color color;
  final double alpha, x, y, rx, ry;
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.color, this.x, this.y, this.rx, this.ry);

  final Color color;
  final double x, y, rx, ry;

  @override
  void paint(Canvas canvas, Size size) {
    // An ellipse: draw a circular gradient scaled vertically.
    final centre = Offset(size.width * x, size.height * y);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(1, ry / rx);
    final shader = RadialGradient(
      colors: [color, color.withValues(alpha: 0)],
      stops: const [0, 0.7],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx));
    canvas.drawCircle(Offset.zero, rx, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.color != color || old.x != x || old.y != y;
}
