import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/focus_timer.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/chrome.dart';
import '../../ui/edge_widgets.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../../ui/widgets.dart';

/// Edge · Home: a big thin clock, the music block and a row of five ring gauges.
/// Every element opens its tab: clock and Timer ring → Timer, music → Music,
/// Claude and Weekly → Claude, CPU and Memory → System.
class EdgeHome extends StatelessWidget {
  const EdgeHome({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final link = scope.link;
    final battery = scope.battery.level;

    return Padding(
      // 28 px at the sides, 14 at the top; the bottom 30 px belong to the page dots.
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Dot(color: link.everConnected ? t.ok : t.muted, size: 6),
                    const SizedBox(width: 6),
                    EdgeLabel(link.wifiHubName ?? 'Computer', size: 11),
                  ],
                ),
                EdgeLabel('${dayMonthShort(now)} · ${battery == null ? '—' : '$battery%'}', size: 11),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _Clock(now: now)),
                const SizedBox(width: 40),
                // Scales down on short screens (a banner above leaves less height) instead of overflowing.
                const SizedBox(
                  width: 380,
                  child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: 380, child: _MusicBlock())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const _Rings(),
        ],
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final (h, m) = clockDigits(now, scope.settings.use24h);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => scope.open(PageId.timer),
      child: Semantics(
        button: true,
        label: 'Open timer',
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$h:$m', style: t.num(124, weight: 200, height: 0.95, letterSpacing: -4)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(two(now.second), style: t.num(22, weight: 300, height: 1, color: t.muted)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(longDate(now), style: t.ui(15, color: t.textSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicBlock extends StatelessWidget {
  const _MusicBlock();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final link = scope.link;
    final m = link.board.music;
    final playing = m?.playing ?? false;
    final progress = (m == null || m.durationS == 0) ? 0.0 : m.positionS / m.durationS;
    final byline = [m?.artist, m?.album].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

    Widget button(DIcon icon, String label, String command, {bool main = false}) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => link.sendCommand(command),
        child: Container(
          width: main ? 52 : 44,
          height: main ? 52 : 44,
          decoration: main ? BoxDecoration(color: t.text, shape: BoxShape.circle) : null,
          alignment: Alignment.center,
          child: DIconView(icon, size: 22, color: main ? t.bg : t.text),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => scope.open(PageId.music),
      child: Semantics(
        label: 'Open music',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: ArtImage(bytes: link.board.art[m?.art], radius: 14, iconSize: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EdgeLabel('YouTube Music', color: t.clay, size: 10, spacing: 2),
                      const SizedBox(height: 4),
                      Text(
                        m?.title ?? 'Nothing playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.num(20, weight: 500, height: 1.2),
                      ),
                      if (byline.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            byline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.ui(13, color: t.muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(mmss(m?.positionS ?? 0), style: t.ui(11, color: t.muted)),
                const SizedBox(width: 12),
                Expanded(child: EdgeProgress(value: progress)),
                const SizedBox(width: 12),
                Text(mmss(m?.durationS ?? 0), style: t.ui(11, color: t.muted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                button(DIcon.previous, 'Previous', 'music.previous'),
                const SizedBox(width: 26),
                button(playing ? DIcon.pause : DIcon.play, playing ? 'Pause' : 'Play', 'music.toggle', main: true),
                const SizedBox(width: 26),
                button(DIcon.next, 'Next', 'music.next'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Rings extends StatelessWidget {
  const _Rings();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final scope = AppScope.of(context);
    final board = scope.link.board;
    final c = board.claude;
    final s = board.system;
    final timer = scope.timer;
    final minutes = (timer.remaining.inSeconds / 60).ceil();

    String num(double? v) => v == null ? '—' : v.round().toString();
    final rings = [
      _RingSpec(
        'Claude',
        num(c?.fiveHourPct),
        '%',
        '5-hour limit',
        t.clay,
        (c?.fiveHourPct ?? 0) / 100,
        PageId.claude,
        'Open Claude page',
      ),
      _RingSpec(
        'Weekly',
        num(c?.weeklyPct),
        '%',
        c?.weeklyReset == null ? 'Weekly limit' : 'Resets ${c!.weeklyReset}',
        t.amber,
        (c?.weeklyPct ?? 0) / 100,
        PageId.claude,
        'Open Claude page',
      ),
      _RingSpec(
        'CPU',
        num(s?.cpu),
        '%',
        s?.cores == null ? 'Processor' : '${s!.cores} cores',
        t.teal,
        (s?.cpu ?? 0) / 100,
        PageId.system,
        'Open System page',
      ),
      _RingSpec(
        'Memory',
        num(s?.memPct),
        '%',
        s?.memUsedGb == null || s?.memTotalGb == null
            ? 'RAM'
            : '${s!.memUsedGb!.toStringAsFixed(1)} of ${s.memTotalGb!.round()} GB',
        t.accentViolet,
        (s?.memPct ?? 0) / 100,
        PageId.system,
        'Open System page',
      ),
      _RingSpec(
        'Timer',
        '$minutes',
        'm',
        timer.preset.isFocus
            ? '${timer.preset.name} · ${timer.session} of ${FocusTimer.sessionsPerRound}'
            : timer.preset.name,
        t.blue,
        1 - timer.progress,
        PageId.timer,
        'Open Timer page',
      ),
    ];

    return Container(
      height: 120,
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.hairline))),
      child: Row(
        children: [
          for (var i = 0; i < rings.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _RingTile(spec: rings[i])),
          ],
        ],
      ),
    );
  }
}

class _RingSpec {
  const _RingSpec(this.label, this.value, this.unit, this.sub, this.color, this.fill, this.page, this.aria);

  final String label, value, unit, sub, aria;
  final Color color;
  final double fill;
  final PageId page;
}

class _RingTile extends StatelessWidget {
  const _RingTile({required this.spec});

  final _RingSpec spec;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => AppScope.of(context).open(spec.page),
      child: Semantics(
        button: true,
        label: spec.aria,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EdgeRing(
              size: 68,
              value: spec.fill,
              color: spec.color,
              // Fits inside the ring: smaller digits, and they shrink further if needed.
              child: SizedBox(
                width: 44,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(spec.value, style: t.num(17, weight: 500, height: 1)),
                      Text(spec.unit, style: t.ui(10, color: t.muted)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            EdgeLabel(spec.label, color: spec.color),
            const SizedBox(height: 4),
            Text(spec.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(11, color: t.muted)),
          ],
        ),
      ),
    );
  }
}
