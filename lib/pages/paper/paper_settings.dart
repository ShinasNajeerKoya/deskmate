import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/settings.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';
import '../../ui/paper_widgets.dart';
import '../battery_dialog.dart';
import '../pair_page.dart';
import '../sidebar_page.dart';

/// Paper · Settings: the theme, the Home layouts (A, B and C) and the settings. "Sidebar" opens the page
/// with the pages that aren't designed yet.
class PaperSettings extends StatelessWidget {
  const PaperSettings({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final settings = scope.settings, link = scope.link;

    final themes = PaperCard(
      label: 'Theme',
      fitHeight: 116,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text('Theme', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 600)),
              ),
              const SizedBox(width: 8),
              // The note sits at the end of the row.
              Expanded(
                child: Text(
                  'Applies to every page',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: t.ui(13, color: t.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                for (final id in ThemeId.values) ...[
                  if (id != ThemeId.values.first) const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: settings.theme == id,
                      label: '${id.label} theme',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap:
                            () =>
                                id.available
                                    ? settings.setTheme(id)
                                    : _toast(context, '${id.label} comes in a later version.'),
                        child: _Selectable(
                          selected: settings.theme == id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _Swatch(colors: id.preview)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      id.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.ui(12, weight: 600),
                                    ),
                                  ),
                                  Text(
                                    settings.theme == id ? 'In use' : (id.available ? '' : 'Later'),
                                    style: t.ui(11, weight: 500, color: settings.theme == id ? t.clay : t.muted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final layouts = PaperCard(
      label: 'Home layouts',
      fitHeight: 176,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text('Home layouts', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 600)),
              ),
              const SizedBox(width: 8),
              // The note sits at the end of the row.
              Expanded(
                child: Text(
                  'Rotate every 10 min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: t.ui(13, color: t.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                for (final l in HomeLayout.values) ...[
                  if (l != HomeLayout.a) const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: settings.homeLayouts.contains(l),
                      label: l.label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!l.availableIn(settings.theme)) {
                            return _toast(context, 'Layout C isn\'t designed for this theme yet.');
                          }
                          if (settings.homeLayouts.length == 1 && settings.homeLayouts.contains(l)) {
                            return _toast(context, 'Keep at least one layout.');
                          }
                          settings.toggleLayout(l);
                        },
                        child: _Selectable(
                          selected: settings.homeLayouts.contains(l),
                          child: _LayoutCard(
                            layout: l,
                            on: settings.homeLayouts.contains(l),
                            enabled: l.availableIn(settings.theme),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            settings.homeLayouts.length == 1
                ? 'Locked to one layout. Pick more to rotate.'
                : 'Pick 1 to lock it, or 2–3 to rotate.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.ui(11, color: t.muted),
          ),
        ],
      ),
    );

    Widget row(String label, String value, VoidCallback onTap, {bool last = false}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 47,
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.bg))),
        child: Row(
          children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13))),
            Text('$value ›', style: t.ui(13, color: t.muted)),
          ],
        ),
      ),
    );

    final prefs = PaperCard(
      label: 'Preferences',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          row(
            'Wi-Fi link',
            !link.wifiPaired ? 'Pair' : (link.wifiActive ? 'Connected' : 'Paired'),
            () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PairPage(link: link))),
          ),
          row(
            'Sidebar',
            '',
            () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SidebarPage())),
          ),
          row(
            'Battery warnings',
            '${settings.batteryLow}% · ${settings.batteryHigh}%',
            () => editBatteryWarnings(context, settings),
          ),
          row(
            'Time format',
            settings.use24h ? '24-hour' : '12-hour',
            () => settings.setUse24h(!settings.use24h),
            last: true,
          ),
        ],
      ),
    );

    return Column(
      children: [
        PaperHeader(title: 'Settings', notes: [PaperNote('Mac', dot: t.ok), PaperNote(clockText(now, use24h))]),
        // Scrolls when the screen is too short to show everything.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // The same sizes as the Color Blocks Settings: theme 142, a gap of 8, then 200.
              const natural = 142.0 + 8 + 200;
              final page = Column(
                children: [
                  SizedBox(height: 142, child: themes),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Expanded(child: layouts), const SizedBox(width: 8), Expanded(child: prefs)],
                    ),
                  ),
                ],
              );
              return box.maxHeight >= natural
                  ? page
                  : SingleChildScrollView(child: SizedBox(height: natural, child: page));
            },
          ),
        ),
      ],
    );
  }
}

/// A selectable tile: 8 px of padding and a 2 px ring when chosen, the same box as in the Color Blocks Settings.
class _Selectable extends StatelessWidget {
  const _Selectable({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? t.ink : Colors.transparent, width: 2),
      ),
      child: child,
    );
  }
}

/// A small preview of a theme: its background and five blocks.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors});

  final List<Color> colors; // [bg, c1 … c5]

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    Widget block(Color c) =>
        Expanded(child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))));
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors[0],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.divider),
      ),
      child: Row(
        children: [
          block(colors[1]),
          const SizedBox(width: 3),
          Expanded(child: Column(children: [block(colors[2]), const SizedBox(height: 3), block(colors[4])])),
          const SizedBox(width: 3),
          Expanded(child: Column(children: [block(colors[3]), const SizedBox(height: 3), block(colors[5])])),
        ],
      ),
    );
  }
}

/// A Home layout sketch with its name and ✓ / Off / Later.
class _LayoutCard extends StatelessWidget {
  const _LayoutCard({required this.layout, required this.on, required this.enabled});

  final HomeLayout layout;
  final bool on, enabled;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final first = switch (layout) {
      HomeLayout.a => 1,
      HomeLayout.b => 2,
      HomeLayout.c => 3,
    };
    Widget cell(Color c, {int flex = 1}) => Expanded(
      flex: flex,
      child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    );
    Widget row(List<Widget> cells) => Expanded(
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[if (i > 0) const SizedBox(width: 2), cells[i]],
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                row([cell(t.ink2, flex: first), for (var i = 0; i < 3 - first; i++) cell(t.border)]),
                const SizedBox(height: 2),
                row([for (var i = 0; i < first; i++) cell(t.border)]),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(layout.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(12, weight: 600)),
              ),
              Text(
                !enabled ? 'Later' : (on ? '✓' : 'Off'),
                style: t.ui(12, weight: 600, color: enabled && on ? t.ok : t.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
