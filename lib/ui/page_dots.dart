import 'package:flutter/material.dart';

import '../theme/deskmate_tokens.dart';

/// Edge's page dots: the active one is a 22 px pill, the others 6 px circles at 25% white.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.active});

  static const height = 30.0;

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return SizedBox(
      height: height,
      child: Semantics(
        label: 'Page ${active + 1} of $count',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == active ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == active ? t.text : t.text.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
