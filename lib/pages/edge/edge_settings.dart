import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/edge_widgets.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../battery_dialog.dart';
import '../pair_page.dart';

/// Edge · Settings (the last tab): the theme, and below it the settings: Wi-Fi link, tab order,
/// battery warnings and time format. (Home layouts are only for the sidebar themes, so they aren't here.)
class EdgeSettings extends StatelessWidget {
  const EdgeSettings({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                DIconView(DIcon.settings, size: 16, color: t.textSoft, strokeWidth: 2),
                const SizedBox(width: 8),
                Text('Settings', style: t.num(18, weight: 500)),
                const Spacer(),
                EdgeLabel(clockText(now, use24h), size: 11),
              ],
            ),
          ),
          Expanded(
            // Laid out at the design's size; shorter or narrower screens scale it down.
            child: LayoutBuilder(
              builder:
                  (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: max(box.maxWidth, 859),
                      height: max(box.maxHeight, 300),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [_Themes(), SizedBox(height: 16), _Preferences()],
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

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.note);

  final String title, note;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [EdgeLabel(title, size: 11, spacing: 2), Text(note, style: t.ui(12, color: t.muted))],
      ),
    );
  }
}

class _Themes extends StatelessWidget {
  const _Themes();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final settings = AppScope.of(context).settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Theme', 'Edge swipes between tabs · the others show a sidebar'),
        Row(
          children: [
            for (final id in ThemeId.values) ...[
              if (id != ThemeId.values.first) const SizedBox(width: 16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Swatch(colors: id.preview, selected: settings.theme == id),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                id.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.ui(
                                  13,
                                  weight: settings.theme == id ? 600 : 500,
                                  color: settings.theme == id ? t.text : t.textSoft,
                                ),
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
            ],
          ],
        ),
      ],
    );
  }
}

/// A small preview of a theme: its background and five blocks. A light ring marks the one in use.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors, required this.selected});

  final List<Color> colors; // [bg, c1 … c5]
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    Widget block(Color c) =>
        Expanded(child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))));
    return Container(
      height: 60,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors[0],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: selected ? t.text : t.text.withValues(alpha: 0.08), spreadRadius: selected ? 2 : 1),
        ],
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

/// The settings, in two columns under the theme.
class _Preferences extends StatelessWidget {
  const _Preferences();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final settings = scope.settings, link = scope.link;

    final wifi =
        link.wifiActive
            ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Connected', style: t.ui(13, color: t.ok)),
              ],
            )
            : Text(link.wifiPaired ? 'Paired' : 'Pair', style: t.ui(13, color: t.muted));

    final rows = [
      EdgeSettingRow(
        label: 'Wi-Fi link',
        sub: 'Pairing with your computer',
        trailing: wifi,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PairPage(link: link))),
      ),
      EdgeSettingRow(
        label: 'Tab order',
        sub: 'The order of the swipe tabs (Settings stays last)',
        trailing: Text('Later', style: t.ui(13, color: t.muted)),
        onTap: () => _toast(context, 'Changing the order comes in a later version.'),
      ),
      EdgeSettingRow(
        label: 'Battery warnings',
        sub: 'Plug in below ${settings.batteryLow}% · unplug above ${settings.batteryHigh}%',
        trailing: Text('${settings.batteryLow}% · ${settings.batteryHigh}%', style: t.ui(13, color: t.textSoft)),
        onTap: () => editBatteryWarnings(context, settings),
      ),
      EdgeSettingRow(
        label: 'Time format',
        sub: 'How the clock is shown on every tab',
        chevron: false,
        trailing: EdgeSegmented(
          options: const ['12-hour', '24-hour'],
          selected: settings.use24h ? 1 : 0,
          onSelect: (i) => settings.setUse24h(i == 1),
        ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.hairline))),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i += 2)
            Row(children: [Expanded(child: rows[i]), const SizedBox(width: 32), Expanded(child: rows[i + 1])]),
        ],
      ),
    );
  }
}
