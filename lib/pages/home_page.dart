import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/settings.dart';
import '../pages/control_page.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/chrome.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';

/// Home: bento tiles, rotating between the selected layouts every 10 minutes.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.now});

  final DateTime now;

  static const rotateEvery = Duration(minutes: 10);

  /// The layout to show at [now]: deterministic from the wall clock, so it
  /// survives rebuilds and app restarts.
  static HomeLayout layoutAt(DateTime now, Set<HomeLayout> selected) {
    final list = HomeLayout.values.where(selected.contains).toList();
    final slot = now.millisecondsSinceEpoch ~/ rotateEvery.inMilliseconds;
    return list[slot % list.length];
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final layout = layoutAt(now, scope.settings.homeLayouts);
    final tiles = _HomeTiles(context, now);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: KeyedSubtree(
        key: ValueKey(layout),
        child: switch (layout) {
          HomeLayout.b => _layoutB(tiles),
          _ => _layoutA(tiles),
        },
      ),
    );
  }

  Widget _layoutA(_HomeTiles x) => BentoGrid(
    columns: 6,
    rows: 4,
    cells: [
      BentoCell(0, 0, x.clock(), colSpan: 3, rowSpan: 2),
      BentoCell(3, 0, x.claudeLarge(), colSpan: 3, rowSpan: 2),
      BentoCell(0, 2, x.musicMedium(), colSpan: 2, rowSpan: 2),
      BentoCell(2, 2, x.bluetooth(), colSpan: 2),
      BentoCell(2, 3, x.systemPair(), colSpan: 2),
      BentoCell(4, 2, x.focusTimer(), colSpan: 2, rowSpan: 2),
    ],
  );

  Widget _layoutB(_HomeTiles x) => BentoGrid(
    columns: 6,
    rows: 4,
    cells: [
      BentoCell(0, 0, x.musicLarge(), colSpan: 3, rowSpan: 4),
      BentoCell(3, 0, x.clock(), colSpan: 3, rowSpan: 2),
      BentoCell(3, 2, x.claudeSmall(), colSpan: 2),
      BentoCell(3, 3, x.bluetooth(), colSpan: 2),
      BentoCell(5, 2, x.slackSmall()),
      BentoCell(5, 3, x.cpuSmall()),
    ],
  );
}

/// Builders for each Home tile. Each tile shows only its one basic item and
/// opens its page on tap.
class _HomeTiles {
  _HomeTiles(this.context, this.now) : t = DeskmateTokens.of(context), scope = AppScope.of(context);

  final BuildContext context;
  final DateTime now;
  final DeskmateTokens t;
  final AppScope scope;

  /// Before the first connection, data tiles are skeletons.
  bool get _waiting => !scope.link.everConnected;

  Widget clock() {
    final (h, m) = clockDigits(now, scope.settings.use24h);
    return Tile(
      color: t.cream,
      radius: t.radiusTileLarge,
      label: 'Clock',
      onTap: () => scope.open(PageId.timer),
      child: Center(child: FlipClock(left: h, right: m)),
    );
  }

  Widget claudeLarge() {
    if (_waiting) return SkeletonTile(radius: t.radiusTileLarge);
    final c = scope.link.board.claude;
    return Tile(
      color: t.clay,
      radius: t.radiusTileLarge,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      label: 'Claude usage',
      onTap: () => scope.open(PageId.claude),
      child: ShrinkToFit(
        minHeight: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                DIconView(DIcon.claude, size: 18, color: t.clayInk),
                const SizedBox(width: 8),
                Expanded(child: Text('Claude', style: t.ui(14, weight: 600, color: t.clayInk))),
                Pill(
                  color: t.clayInk.withValues(alpha: 0.12),
                  child: Text('5-hour limit', style: t.ui(12, weight: 500, color: t.clayInk)),
                ),
              ],
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(pct(c?.fiveHourPct), style: t.num(76, height: 0.95, letterSpacing: -2, color: t.clayInk)),
              ),
            ),
            _usageBar(c?.fiveHourPct, height: 10, gap: 4),
          ],
        ),
      ),
    );
  }

  Widget claudeSmall() {
    if (_waiting) return const SkeletonTile();
    final c = scope.link.board.claude;
    return Tile(
      color: t.clay,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      label: 'Claude usage',
      onTap: () => scope.open(PageId.claude),
      child: ShrinkToFit(
        minHeight: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Claude · 5-hour',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.ui(12, weight: 600, color: t.clayInk),
                  ),
                ),
                Text(pct(c?.fiveHourPct), style: t.num(22, height: 1, color: t.clayInk)),
              ],
            ),
            _usageBar(c?.fiveHourPct, height: 8, gap: 3),
          ],
        ),
      ),
    );
  }

  Widget _usageBar(double? p, {required double height, required double gap}) => SegmentBar(
    count: 10,
    filled: ((p ?? 0) / 10).round(),
    on: t.clayInk,
    off: t.clayInk.withValues(alpha: 0.2),
    height: height,
    gap: gap,
  );

  Widget _art(double size, double iconSize) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: t.violet2, borderRadius: BorderRadius.circular(14)),
    child: Center(child: DIconView(DIcon.music, size: iconSize, color: t.lilac, strokeWidth: 1.8)),
  );

  Widget _musicButtons({required double playWidth}) {
    final m = scope.link.board.music;
    final link = scope.link;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBlockButton(
          icon: DIcon.previous,
          label: 'Previous',
          background: t.violet2,
          foreground: t.text,
          onTap: () => link.sendCommand('music.previous'),
        ),
        SizedBox(width: playWidth == 56 ? 6 : 0),
        IconBlockButton(
          icon: (m?.playing ?? false) ? DIcon.pause : DIcon.play,
          label: (m?.playing ?? false) ? 'Pause' : 'Play',
          background: t.cream,
          foreground: t.violet,
          width: playWidth,
          height: 48,
          radius: t.radiusButton,
          iconSize: 20,
          onTap: () => link.sendCommand('music.toggle'),
        ),
        SizedBox(width: playWidth == 56 ? 6 : 0),
        IconBlockButton(
          icon: DIcon.next,
          label: 'Next',
          background: t.violet2,
          foreground: t.text,
          onTap: () => link.sendCommand('music.next'),
        ),
      ],
    );
  }

  Widget musicMedium() {
    if (_waiting) return SkeletonTile(radius: t.radiusTileLarge);
    final m = scope.link.board.music;
    return Tile(
      color: t.violet,
      radius: t.radiusTileLarge,
      label: 'Now playing',
      onTap: () => scope.open(PageId.music),
      child: ShrinkToFit(
        minHeight: 122,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _art(62, 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m?.title ?? 'Nothing playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(15, weight: 600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m?.artist ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(12, color: t.lilac),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconBlockButton(
                  icon: DIcon.previous,
                  label: 'Previous',
                  background: t.violet2,
                  foreground: t.text,
                  onTap: () => scope.link.sendCommand('music.previous'),
                ),
                IconBlockButton(
                  icon: (m?.playing ?? false) ? DIcon.pause : DIcon.play,
                  label: (m?.playing ?? false) ? 'Pause' : 'Play',
                  background: t.cream,
                  foreground: t.violet,
                  width: 64,
                  height: 48,
                  radius: t.radiusButton,
                  iconSize: 20,
                  onTap: () => scope.link.sendCommand('music.toggle'),
                ),
                IconBlockButton(
                  icon: DIcon.next,
                  label: 'Next',
                  background: t.violet2,
                  foreground: t.text,
                  onTap: () => scope.link.sendCommand('music.next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget musicLarge() {
    if (_waiting) return SkeletonTile(radius: 26);
    final m = scope.link.board.music;
    return Tile(
      color: t.violet,
      radius: 26,
      padding: const EdgeInsets.all(18),
      label: 'Now playing',
      onTap: () => scope.open(PageId.music),
      child: ShrinkToFit(
        minHeight: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: t.violet2, borderRadius: BorderRadius.circular(18)),
                child: Center(child: DIconView(DIcon.music, size: 54, color: t.lilac, strokeWidth: 1.4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m?.title ?? 'Nothing playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.num(20, height: 1.15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m?.artist ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(13, color: t.lilac),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _musicButtons(playWidth: 56),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget systemPair() {
    if (_waiting) return const SkeletonTile();
    final s = scope.link.board.system;
    Widget stat(String label, double? v) => Expanded(
      child: LabelValue(
        columnMinHeight: 40,
        label: Text(label, style: t.ui(12, color: t.muted)),
        value: Text(pct(v), style: t.num(22, height: 1.1)),
      ),
    );
    return Tile(
      color: t.panel,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      label: 'System',
      onTap: () => scope.open(PageId.system),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          stat('CPU', s?.cpu),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(width: 1, height: 34, color: t.divider),
          ),
          stat('RAM', s?.memPct),
        ],
      ),
    );
  }

  Widget slackSmall() {
    if (_waiting) return const SkeletonTile();
    final n = scope.link.board.slackUnread;
    return Tile(
      color: t.butter,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      label: 'Slack unread',
      onTap: () => scope.open(PageId.slack),
      child: LabelValue(
        label: Text('Slack', style: t.ui(12, weight: 600, color: t.butterInk)),
        value: Text(n?.toString() ?? '—', style: t.num(28, height: 1, color: t.butterInk)),
      ),
    );
  }

  Widget cpuSmall() {
    if (_waiting) return const SkeletonTile();
    final s = scope.link.board.system;
    return Tile(
      color: t.panel,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      label: 'CPU',
      onTap: () => scope.open(PageId.system),
      child: LabelValue(
        label: Text('CPU', style: t.ui(12, color: t.muted)),
        value: Text(pct(s?.cpu), style: t.num(28, height: 1)),
      ),
    );
  }

  /// Mac Bluetooth: the connected device (e.g. earphones). Opens Control Center.
  /// Replaces the old calendar "Next up" tile; there's no calendar tile on Home.
  Widget bluetooth() {
    if (_waiting) return const SkeletonTile();
    final bt = scope.link.board.bluetooth;
    final active = bt?.active;
    final status = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Dot(color: t.mintInk),
        const SizedBox(width: 5),
        Text(active == null ? 'Off' : 'Connected', style: t.ui(12, weight: 600, color: t.mintInk)),
      ],
    );
    final device = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DIconView(active == null ? DIcon.bluetooth : btIcons[active.kind]!, size: 20, color: t.mintInk),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            active?.name ?? 'No device',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.num(20, height: 1, color: t.mintInk),
          ),
        ),
      ],
    );
    return Tile(
      color: t.mint,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      label: 'Bluetooth',
      onTap: () => scope.open(PageId.control),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxHeight < 56) {
            // Short tile: one row.
            return Row(children: [Expanded(child: device), const SizedBox(width: 8), status]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  DIconView(DIcon.bluetooth, size: 14, color: t.mintInk, strokeWidth: 2.2),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Bluetooth', style: t.ui(12, weight: 600, color: t.mintInk))),
                  status,
                ],
              ),
              device,
            ],
          );
        },
      ),
    );
  }

  /// Focus timer (2 × 2 in Layout A). It runs on the phone, so it works even
  /// before the Mac is found. Replaces the old quick buttons and Slack tile.
  Widget focusTimer() {
    final timer = scope.timer;
    final secs = (timer.remaining.inMilliseconds / 1000).ceil();
    return Tile(
      color: t.panel,
      radius: t.radiusTileLarge,
      label: '${timer.preset.name} timer',
      onTap: () => scope.open(PageId.timer),
      fitHeight: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              DIconView(DIcon.timer, size: 20, color: t.text),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  timer.preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(13, weight: 600, color: t.muted),
                ),
              ),
              Text('${timer.preset.minutes} min', style: t.ui(12, color: t.muted)),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${two(secs ~/ 60)}:${two(secs % 60)}', style: t.num(52, height: 1, letterSpacing: -1.5)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProgressLine(value: timer.progress, fill: t.clay, track: t.panel2),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: t.clay,
                      borderRadius: BorderRadius.circular(t.radiusButton),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: timer.toggle,
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DIconView(timer.running ? DIcon.pause : DIcon.play, size: 14, color: t.clayInk),
                              const SizedBox(width: 6),
                              Text(
                                timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
                                style: t.ui(14, weight: 700, color: t.clayInk),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconBlockButton(
                    icon: DIcon.reset,
                    label: 'Reset',
                    background: t.panel2,
                    foreground: t.text,
                    width: 44,
                    height: 44,
                    radius: t.radiusButton,
                    onTap: timer.reset,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
