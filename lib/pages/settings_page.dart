import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/settings.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final settings = AppScope.of(context).settings;

    Widget card({required String title, required String note, required Widget child, EdgeInsets? padding}) => Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 600))),
              const SizedBox(width: 8),
              Flexible(
                child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, color: t.muted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );

    Widget selectable({
      required bool selected,
      required VoidCallback onTap,
      required Widget child,
      double radius = 16,
    }) => Material(
      color: t.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: selected ? t.cream : Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(8), child: child)),
    );

    final themes = card(
      title: 'Theme',
      note: 'Applies to every page',
      child: Row(
        children: [
          for (final id in ThemeId.values) ...[
            if (id != ThemeId.graphite) const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                selected: settings.theme == id,
                label: '${id.label} theme',
                child: selectable(
                  selected: settings.theme == id,
                  onTap:
                      () =>
                          id.available
                              ? settings.setTheme(id)
                              : _toast(context, '${id.label} comes in a later version.'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _ThemeSwatch(colors: id.preview)),
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
                            style: t.ui(11, color: settings.theme == id ? t.clay : t.muted),
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
    );

    final layouts = card(
      title: 'Home layouts',
      note: 'Rotate every 10 min',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                for (final l in HomeLayout.values) ...[
                  if (l != HomeLayout.a) const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      selected: settings.homeLayouts.contains(l),
                      label: l.label,
                      child: selectable(
                        radius: 14,
                        selected: settings.homeLayouts.contains(l),
                        onTap: () {
                          if (!l.available) return _toast(context, 'Layout C isn\'t designed for this theme yet.');
                          if (settings.homeLayouts.length == 1 && settings.homeLayouts.contains(l)) {
                            return _toast(context, 'Keep at least one layout.');
                          }
                          settings.toggleLayout(l);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _LayoutThumb(layout: l)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.ui(12, weight: 600),
                                  ),
                                ),
                                Text(
                                  !l.available ? 'Later' : (settings.homeLayouts.contains(l) ? '✓' : 'Off'),
                                  style: t.ui(
                                    12,
                                    weight: 600,
                                    color: settings.homeLayouts.contains(l) ? t.ok : t.muted,
                                  ),
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
          ),
          const SizedBox(height: 8),
          Text(
            settings.homeLayouts.length == 1
                ? 'Locked to one layout. Pick more to rotate.'
                : 'Pick 1 to lock it, or 2–3 to rotate.',
            style: t.ui(11, color: t.muted),
          ),
        ],
      ),
    );

    Widget row(String label, Widget trailing, {bool last = false, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.divider))),
        child: Row(children: [Expanded(child: Text(label, style: t.ui(13))), trailing]),
      ),
    );
    Widget value(String v) => Text('$v ›', style: t.ui(13, color: t.muted));
    Widget toggle(String label, bool on, ValueChanged<bool> onChanged) => Semantics(
      toggled: on,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: on ? t.clay : t.track, borderRadius: BorderRadius.circular(13)),
          child: Dot(color: t.cream, size: 20),
        ),
      ),
    );

    final prefs = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          row(
            'Sidebar order',
            value('Later'),
            onTap: () => _toast(context, 'Editing the sidebar comes in a later version.'),
          ),
          row(
            'Battery warnings',
            value('${settings.batteryLow}% · ${settings.batteryHigh}%'),
            onTap: () => _editBattery(context, settings),
          ),
          row(
            'Slack privacy',
            toggle(
              'Slack privacy',
              true,
              (_) => _toast(context, 'Privacy mode is always on: counts only, never messages.'),
            ),
            onTap: () => _toast(context, 'Privacy mode is always on: counts only, never messages.'),
          ),
          row(
            'Night clock when Mac sleeps',
            toggle('Night clock when Mac sleeps', settings.nightClock, settings.setNightClock),
          ),
          row(
            'Time format',
            value(settings.use24h ? '24-hour' : '12-hour'),
            last: true,
            onTap: () => settings.setUse24h(!settings.use24h),
          ),
        ],
      ),
    );

    // Scrolls when the screen is too short to show everything.
    const naturalHeight = 400.0;
    final page = Column(
      children: [
        SizedBox(height: 142, child: themes),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: layouts), const SizedBox(width: 8), Expanded(child: prefs)],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder:
          (context, box) =>
              box.maxHeight >= naturalHeight
                  ? page
                  : SingleChildScrollView(child: SizedBox(height: naturalHeight, child: page)),
    );
  }

  Future<void> _editBattery(BuildContext context, SettingsController settings) async {
    final t = DeskmateTokens.of(context);
    var range = RangeValues(settings.batteryLow.toDouble(), settings.batteryHigh.toDouble());
    final result = await showDialog<RangeValues>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: t.panel,
                  title: Text('Battery warnings', style: t.ui(16, weight: 600)),
                  content: SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plug in below ${range.start.round()}% · unplug above ${range.end.round()}%',
                          style: t.ui(13, color: t.muted),
                        ),
                        RangeSlider(
                          values: range,
                          min: 10,
                          max: 95,
                          divisions: 17,
                          activeColor: t.clay,
                          inactiveColor: t.track,
                          labels: RangeLabels('${range.start.round()}%', '${range.end.round()}%'),
                          onChanged: (v) => setState(() => range = v),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: t.ui(14, color: t.muted)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, range),
                      child: Text('Save', style: t.ui(14, weight: 600, color: t.clay)),
                    ),
                  ],
                ),
          ),
    );
    if (result != null) settings.setBatteryLimits(result.start.round(), result.end.round());
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.colors});
  final List<Color> colors; // [bg, c1..c5]

  @override
  Widget build(BuildContext context) {
    Widget b(Color c) => Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(10)),
      child: BentoGrid(
        columns: 3,
        rows: 2,
        gap: 3,
        cells: [
          BentoCell(0, 0, b(colors[1]), rowSpan: 2),
          BentoCell(1, 0, b(colors[2])),
          BentoCell(2, 0, b(colors[3])),
          BentoCell(1, 1, b(colors[4])),
          BentoCell(2, 1, b(colors[5])),
        ],
      ),
    );
  }
}

class _LayoutThumb extends StatelessWidget {
  const _LayoutThumb({required this.layout});
  final HomeLayout layout;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    Widget b() => Container(decoration: BoxDecoration(color: t.track, borderRadius: BorderRadius.circular(3)));
    final firstSpan = switch (layout) {
      HomeLayout.a => 1,
      HomeLayout.b => 2,
      HomeLayout.c => 3,
    };
    return BentoGrid(
      columns: 3,
      rows: 2,
      gap: 2,
      cells: [
        BentoCell(0, 0, b(), colSpan: firstSpan),
        if (firstSpan < 3) BentoCell(firstSpan, 0, b(), colSpan: 3 - firstSpan),
        BentoCell(0, 1, b()),
        BentoCell(1, 1, b()),
        BentoCell(2, 1, b()),
      ],
    );
  }
}
