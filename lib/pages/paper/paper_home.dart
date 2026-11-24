import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/focus_timer.dart';
import '../../app/settings.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/chrome.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../../ui/paper_widgets.dart';
import '../../ui/widgets.dart';
import '../control_page.dart' show btIcons;
import '../home_page.dart';

/// Paper · Home: three layouts (A, B, C) that rotate every 10 minutes, built from off-white cards with a
/// thin border, a dark Claude card, a flip clock on ink cards and mono numbers.
class PaperHome extends StatelessWidget {
  const PaperHome({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final layout = HomePage.layoutAt(now, scope.settings.activeLayouts);
    final x = _Tiles(context, now);
    final level = scope.battery.level;
    return Column(
      children: [
        PaperHeader(
          title: 'Home',
          subtitle: '${weekdayShort(now)} ${two(now.day)}.${two(now.month)}',
          notes: [
            PaperNote(
              'Mac',
              dot: scope.link.everConnected ? DeskmateTokens.of(context).ok : DeskmateTokens.of(context).muted,
            ),
            PaperNote('Bat ${level == null ? '—' : '$level%'}'),
          ],
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: KeyedSubtree(
              key: ValueKey(layout),
              child: switch (layout) {
                HomeLayout.b => _layoutB(x),
                HomeLayout.c => _layoutC(x),
                _ => _layoutA(x),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _layoutA(_Tiles x) => BentoGrid(
    columns: 6,
    rows: 4,
    cells: [
      BentoCell(0, 0, x.clock(72, 106, 72, 8), colSpan: 3, rowSpan: 2),
      BentoCell(3, 0, x.claudeInk(), colSpan: 3, rowSpan: 2),
      BentoCell(0, 2, x.music(), colSpan: 2, rowSpan: 2),
      BentoCell(2, 2, x.bluetooth(), colSpan: 2),
      BentoCell(2, 3, x.system(), colSpan: 2),
      BentoCell(4, 2, x.timerWide(), colSpan: 2, rowSpan: 2),
    ],
  );

  Widget _layoutB(_Tiles x) => BentoGrid(
    columns: 6,
    rows: 4,
    cells: [
      BentoCell(0, 0, x.musicLarge(), colSpan: 3, rowSpan: 4),
      BentoCell(3, 0, x.clock(64, 96, 64, 8), colSpan: 3, rowSpan: 2),
      BentoCell(3, 2, x.claudeInk(small: true), colSpan: 2),
      BentoCell(3, 3, x.bluetooth(), colSpan: 2),
      BentoCell(5, 2, x.stat('RAM', x.memory)),
      BentoCell(5, 3, x.stat('CPU', x.cpu)),
    ],
  );

  Widget _layoutC(_Tiles x) => BentoGrid(
    columns: 6,
    rows: 4,
    cells: [
      BentoCell(0, 0, x.clockBand(), colSpan: 6, rowSpan: 2),
      BentoCell(0, 2, x.claudeLight(), colSpan: 2, rowSpan: 2),
      BentoCell(2, 2, x.music(), colSpan: 2, rowSpan: 2),
      BentoCell(4, 2, x.bluetooth(), colSpan: 2),
      BentoCell(4, 3, x.timerSmall()),
      BentoCell(5, 3, x.stat('CPU', x.cpu)),
    ],
  );
}

class _Tiles {
  _Tiles(this.context, this.now) : t = DeskmateTokens.of(context), scope = AppScope.of(context);

  final BuildContext context;
  final DateTime now;
  final DeskmateTokens t;
  final AppScope scope;

  BoardData get board => scope.link.board;

  void open(PageId p) => scope.open(p);

  String get cpu => pct(board.system?.cpu);
  String get memory => pct(board.system?.memPct);

  String get _claudePct => board.claude?.fiveHourPct == null ? '—' : board.claude!.fiveHourPct!.round().toString();
  int get _claudeLit => (((board.claude?.fiveHourPct ?? 0) / 100) * 30).round();

  // --- clock

  Widget _digits(double w, double h, double font, Color card, Color seam, double dot, double gap) {
    final (hh, mm) = clockDigits(now, scope.settings.use24h);
    Widget digit(String d) => FlipDigit(
      digit: d,
      width: w,
      height: h,
      fontSize: font,
      card: card,
      ink: t.onInk,
      seam: seam,
      radius: t.radiusDigit,
    );
    Widget pair(String s) =>
        Row(mainAxisSize: MainAxisSize.min, children: [digit(s[0]), const SizedBox(width: 5), digit(s[1])]);
    Widget square() => Container(width: dot, height: dot, color: t.clay);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pair(hh),
        SizedBox(width: gap),
        Column(mainAxisSize: MainAxisSize.min, children: [square(), const SizedBox(height: 16), square()]),
        SizedBox(width: gap),
        pair(mm),
      ],
    );
  }

  Widget clock(double w, double h, double font, double dot) => PaperCard(
    label: 'Clock',
    onTap: () => open(PageId.timer),
    padding: EdgeInsets.zero,
    child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _digits(w, h, font, t.ink, t.onInk, dot, 12))),
  );

  Widget clockBand() {
    final month = dayMonthShort(now).split(' ').last.toUpperCase();
    return PaperCard(
      ink: true,
      label: 'Clock',
      onTap: () => open(PageId.timer),
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: _digits(78, 116, 80, t.ink2, t.ink, 9, 12)),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(weekdayShort(now).toUpperCase(), style: t.num(34, weight: 600, height: 1, color: t.onInk)),
              const SizedBox(height: 8),
              Text('${now.day} $month ${now.year}', style: t.num(14, weight: 500, color: t.inkMuted, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Claude

  Widget claudeInk({bool small = false}) {
    if (small) {
      return PaperCard(
        ink: true,
        label: 'Claude usage',
        fitHeight: 40,
        onTap: () => open(PageId.claude),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(child: PaperLabel('Claude · 5h', color: t.inkMuted)),
                Text('$_claudePct%', style: t.num(22, weight: 600, height: 1, color: t.onInk)),
              ],
            ),
            PaperTicks(count: 30, lit: _claudeLit, height: 12, offColor: t.onInk.withValues(alpha: 0.18)),
          ],
        ),
      );
    }
    return PaperCard(
      ink: true,
      label: 'Claude usage',
      fitHeight: 130,
      onTap: () => open(PageId.claude),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [PaperLabel('Claude', color: t.inkMuted), PaperLabel('5h limit', color: t.inkMuted)],
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_claudePct, style: t.num(66, weight: 600, height: 1, letterSpacing: -2, color: t.onInk)),
                  Text('%', style: t.num(30, weight: 600, color: t.inkMuted)),
                ],
              ),
            ),
          ),
          PaperTicks(count: 30, lit: _claudeLit, offColor: t.onInk.withValues(alpha: 0.18)),
        ],
      ),
    );
  }

  Widget claudeLight() => PaperCard(
    label: 'Claude usage',
    fitHeight: 100,
    onTap: () => open(PageId.claude),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [PaperLabel('Claude'), PaperLabel('5h')],
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_claudePct, style: t.num(52, weight: 600, height: 1, letterSpacing: -2)),
                Text('%', style: t.num(24, weight: 600, color: t.muted)),
              ],
            ),
          ),
        ),
        PaperTicks(count: 20, lit: (_claudeLit * 20 / 30).round(), height: 18),
      ],
    ),
  );

  // --- music

  NowPlaying? get _m => board.music;

  Widget _art(double radius, double icon) =>
      ArtImage(bytes: board.art[_m?.art], radius: radius, iconSize: icon, fit: BoxFit.cover);

  Widget _controls() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      PaperRoundButton(icon: DIcon.previous, label: 'Previous', onTap: () => scope.link.sendCommand('music.previous')),
      const SizedBox(width: 12),
      PaperRoundButton(
        icon: (_m?.playing ?? false) ? DIcon.pause : DIcon.play,
        label: (_m?.playing ?? false) ? 'Pause' : 'Play',
        size: 52,
        iconSize: 20,
        filled: true,
        onTap: () => scope.link.sendCommand('music.toggle'),
      ),
      const SizedBox(width: 12),
      PaperRoundButton(icon: DIcon.next, label: 'Next', onTap: () => scope.link.sendCommand('music.next')),
    ],
  );

  Widget music() => PaperCard(
    label: 'Now playing',
    fitHeight: 124,
    onTap: () => open(PageId.music),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(width: 60, height: 60, child: _art(8, 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _m?.title ?? 'Nothing playing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.ui(15, weight: 600),
                  ),
                  const SizedBox(height: 3),
                  Text(_m?.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(12, color: t.muted)),
                ],
              ),
            ),
          ],
        ),
        FittedBox(fit: BoxFit.scaleDown, child: _controls()),
      ],
    ),
  );

  Widget musicLarge() {
    final progress = (_m == null || _m!.durationS == 0) ? 0.0 : _m!.positionS / _m!.durationS;
    return PaperCard(
      label: 'Now playing',
      fitHeight: 215,
      onTap: () => open(PageId.music),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _art(10, 48)),
          const SizedBox(height: 12),
          Text(
            _m?.title ?? 'Nothing playing',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.ui(20, weight: 600),
          ),
          const SizedBox(height: 3),
          Text(_m?.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, color: t.muted)),
          const SizedBox(height: 12),
          PaperBar(value: progress),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, child: _controls()),
        ],
      ),
    );
  }

  // --- computer

  Widget bluetooth() {
    final d = board.bluetooth?.active;
    return PaperCard(
      label: 'Bluetooth',
      fitHeight: 56,
      onTap: () => open(PageId.control),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: PaperLabel('Bluetooth')),
              if (d != null) ...[
                Container(width: 6, height: 6, decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('ON', style: t.num(11, weight: 500, color: t.ok)),
              ],
            ],
          ),
          Row(
            children: [
              DIconView(d == null ? DIcon.bluetooth : btIcons[d.kind]!, size: 20, color: t.text),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  d?.name ?? 'No device',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(16, weight: 600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget system() => PaperCard(
    label: 'System',
    fitHeight: 50,
    onTap: () => open(PageId.system),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PaperLabel('System'),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CPU ', style: t.num(11, weight: 500, color: t.muted)),
              Text(cpu, style: t.num(20, weight: 600)),
              const SizedBox(width: 18),
              Text('RAM ', style: t.num(11, weight: 500, color: t.muted)),
              Text(memory, style: t.num(20, weight: 600)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget stat(String label, String value) => PaperCard(
    label: label,
    fitHeight: 54,
    onTap: () => open(PageId.system),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaperLabel(label),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: t.num(26, weight: 600, height: 1)),
        ),
      ],
    ),
  );

  // --- timer

  FocusTimer get _timer => scope.timer;

  String get _time {
    final s = (_timer.remaining.inMilliseconds / 1000).ceil();
    return '${two(s ~/ 60)}:${two(s % 60)}';
  }

  Widget timerWide() {
    final timer = _timer;
    return PaperCard(
      label: '${timer.preset.name} timer',
      fitHeight: 135,
      onTap: () => open(PageId.timer),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: PaperLabel('Timer')),
              PaperLabel(
                timer.preset.isFocus
                    ? '${timer.preset.name} · ${timer.session} of ${FocusTimer.sessionsPerRound}'
                    : timer.preset.name,
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_time, style: t.num(46, weight: 600, height: 1, letterSpacing: -1)),
          ),
          PaperBar(value: timer.progress, fill: t.clay),
          Row(
            children: [
              Expanded(
                child: PaperPillButton(
                  label: timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
                  onTap: timer.toggle,
                ),
              ),
              const SizedBox(width: 8),
              PaperPillButton(label: 'Reset', filled: false, onTap: timer.reset),
            ],
          ),
        ],
      ),
    );
  }

  Widget timerSmall() => PaperCard(
    label: 'Timer',
    fitHeight: 50,
    onTap: () => open(PageId.timer),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: PaperLabel('Timer')),
            Container(width: 7, height: 7, decoration: BoxDecoration(color: t.clay, shape: BoxShape.circle)),
          ],
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_time, style: t.num(24, weight: 600, height: 1)),
        ),
      ],
    ),
  );
}
