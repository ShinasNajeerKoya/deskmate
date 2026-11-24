import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/feature_registry.dart';
import '../theme/deskmate_tokens.dart';
import 'icons.dart';

const pageIcons = {
  PageId.home: DIcon.home,
  PageId.claude: DIcon.claude,
  PageId.music: DIcon.music,
  PageId.system: DIcon.system,
  PageId.control: DIcon.bluetooth,
  PageId.timer: DIcon.timer,
  PageId.calendar: DIcon.calendar,
  PageId.weather: DIcon.weather,
  PageId.shortcuts: DIcon.shortcuts,
  PageId.github: DIcon.github,
  PageId.settings: DIcon.settings,
};

/// Floating sidebar: scrolling icon rail with labels, Settings pinned at the bottom.
class Rail extends StatelessWidget {
  const Rail({super.key, required this.active, required this.onSelect});

  final PageId active;
  final ValueChanged<PageId> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final pages = sidebarPages();
    return Container(
      width: 66,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(t.radiusRail)),
      // Drawn over the panel so it takes no room (the same layout in every sidebar theme).
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusRail),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: pages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) => Center(child: _item(t, pages[i])),
            ),
          ),
          const SizedBox(height: 6),
          _item(t, PageId.settings, idle: t.panel2),
        ],
      ),
    );
  }

  Widget _item(DeskmateTokens t, PageId page, {Color? idle}) {
    final on = page == active;
    final fg = on ? t.railActiveInk : t.muted;
    return Semantics(
      selected: on,
      button: true,
      label: page.label,
      child: Material(
        color: on ? t.railActive : (idle ?? Colors.transparent),
        borderRadius: BorderRadius.circular(t.radiusButton),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(page),
          child: SizedBox(
            width: 54,
            height: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DIconView(pageIcons[page]!, size: 19, color: fg),
                const SizedBox(height: 3),
                Text(
                  page.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: t.ui(page.label.length > 8 ? 9.5 : 11, weight: on ? 600 : 500, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
