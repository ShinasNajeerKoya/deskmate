import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/feature_registry.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/icons.dart';

/// Settings → Sidebar: the pages that exist but aren't designed yet, each in its own container with its
/// icon and name. They will move into the sidebar when they are designed. A round raised back button
/// sits at the top left.
class SidebarPage extends StatelessWidget {
  const SidebarPage({super.key});

  static const _icons = {
    PageId.calendar: DIcon.calendar,
    PageId.weather: DIcon.weather,
    PageId.shortcuts: DIcon.shortcuts,
    PageId.github: DIcon.github,
  };

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final pages = futurePages();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back to Settings',
                      child: Material(
                        color: t.panel,
                        elevation: 4,
                        shadowColor: Colors.black54,
                        shape: CircleBorder(side: BorderSide(color: t.border)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: Center(
                              child: DIconView(DIcon.chevronLeft, size: 18, color: t.text, strokeWidth: 2.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Sidebar', style: t.ui(16, weight: 600)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pages for later. They are not in the sidebar yet; each one will appear there when it is designed.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.ui(13, color: t.muted),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < pages.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _FutureCard(page: pages[i], icon: _icons[pages[i]] ?? DIcon.settings)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FutureCard extends StatelessWidget {
  const _FutureCard({required this.page, required this.icon});

  final PageId page;
  final DIcon icon;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Semantics(
      label: '${page.label}, not designed yet',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.circular(t.radiusTile),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: t.panel2, shape: BoxShape.circle),
              child: Center(child: DIconView(icon, size: 22, color: t.text)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(page.label, style: t.ui(16, weight: 600)),
                const SizedBox(height: 4),
                Text('NOT DESIGNED YET', style: t.ui(11, color: t.muted).copyWith(letterSpacing: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
