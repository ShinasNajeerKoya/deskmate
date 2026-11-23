import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/icons.dart';
import '../ui/rail.dart';

/// Stand-in for pages that aren't designed yet (Calendar, Slack, Weather,
/// Shortcuts, GitHub).
class NotDesignedPage extends StatelessWidget {
  const NotDesignedPage({super.key, required this.page});

  final PageId page;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Container(
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(t.radiusTileLarge)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DIconView(pageIcons[page]!, size: 40, color: t.muted, strokeWidth: 1.6),
            const SizedBox(height: 14),
            Text('${page.label} isn\'t designed yet', style: t.ui(16, weight: 600)),
            const SizedBox(height: 4),
            Text('It\'ll be built once its layout is on the design canvas.', style: t.ui(13, color: t.muted)),
          ],
        ),
      ),
    );
  }
}
