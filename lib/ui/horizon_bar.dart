import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/deskmate_tokens.dart';
import 'icons.dart';
import 'rail.dart';

/// Horizon's floating bottom bar: a frosted pill with one icon per tab; the open tab grows into a light
/// pill with its name. It floats over the page (a stack overlay) and fades the page out behind it.
class HorizonBar extends StatelessWidget {
  const HorizonBar({super.key, required this.tabs, required this.active, required this.onSelect});

  static const height = 64.0;

  final List<PageId> tabs;
  final PageId active;
  final ValueChanged<PageId> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return SizedBox(
      height: 84,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // The page fades into the background behind the bar.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.3, 1],
                    colors: [t.bg, t.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x17FFFFFF), Color(0x08FFFFFF)],
                    ),
                    border: Border.all(color: const Color(0x1CFFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _Item(page: tabs[i], on: tabs[i] == active, onTap: () => onSelect(tabs[i])),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.page, required this.on, required this.onTap});

  final PageId page;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final fg = on ? t.railActiveInk : t.muted;
    return Semantics(
      button: true,
      selected: on,
      label: page.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: on ? 20 : 12),
          decoration: BoxDecoration(
            color: on ? t.railActive : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DIconView(pageIcons[page]!, size: 19, color: fg),
              if (on) ...[const SizedBox(width: 9), Text(page.label, style: t.ui(14, weight: 600, color: fg))],
            ],
          ),
        ),
      ),
    );
  }
}
