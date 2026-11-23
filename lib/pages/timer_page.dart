import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/focus_timer.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/chrome.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final timer = AppScope.of(context).timer;
    final secs = timer.remaining.inSeconds + (timer.remaining.inMilliseconds % 1000 > 0 ? 1 : 0);
    final filled = (timer.progress * 25).floor().clamp(0, 25);

    final main = Tile(
      color: t.cream,
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      label: '${timer.preset.name} timer',
      fitHeight: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(child: Text(timer.preset.name, style: t.ui(14, weight: 600, color: t.creamInk))),
              if (timer.preset.isFocus)
                Pill(
                  color: t.cream2,
                  child: Text(
                    'Session ${timer.session} of ${FocusTimer.sessionsPerRound}',
                    style: t.ui(12, weight: 600, color: t.creamInk),
                  ),
                ),
            ],
          ),
          Flexible(
            child: Center(
              child: FlipClock(
                left: two(secs ~/ 60),
                right: two(secs % 60),
                digitWidth: 88,
                digitHeight: 126,
                fontSize: 98,
                dotColor: t.clay,
                dotSize: 10,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: SegmentBar(count: 25, filled: filled, on: t.clay, off: t.cream2, gap: 3, radius: 2)),
              const SizedBox(width: 12),
              IconBlockButton(
                icon: DIcon.reset,
                label: 'Reset',
                background: t.cream2,
                foreground: t.creamInk,
                width: 48,
                height: 48,
                radius: t.radiusButton,
                iconSize: 20,
                onTap: timer.reset,
              ),
              const SizedBox(width: 12),
              Material(
                color: t.clay,
                borderRadius: BorderRadius.circular(t.radiusButton),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: timer.toggle,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DIconView(timer.running ? DIcon.pause : DIcon.play, size: 18, color: t.clayInk),
                        const SizedBox(width: 8),
                        Text(
                          timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
                          style: t.ui(15, weight: 700, color: t.clayInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final colours = [(t.butter, t.butterInk), (t.mint, t.mintInk), (t.clay, t.clayInk), (t.violet, t.text)];
    Widget preset(int i) {
      final p = FocusTimer.presets[i];
      final selected = timer.preset == p;
      return Material(
        color: colours[i].$1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusTile),
          side: selected ? BorderSide(color: t.cream, width: 3) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => timer.select(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: ShrinkToFit(
              minHeight: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.ui(12, weight: 600, color: colours[i].$2),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${p.minutes}', style: t.num(26, height: 1, color: colours[i].$2)),
                          TextSpan(text: ' min', style: t.ui(13, weight: 600, color: colours[i].$2)),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final focused = timer.focusedToday;
    final today = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(t.radiusTile)),
      child: ShrinkToFit(
        minHeight: 46,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Focused today', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(12, color: t.muted)),
                  Text(focused.inMinutes == 0 ? '0m' : hm(focused), style: t.num(24, height: 1.1)),
                ],
              ),
            ),
            for (var i = 0; i < FocusTimer.sessionsPerRound; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Dot(color: i < timer.focusDoneToday % FocusTimer.sessionsPerRound ? t.clay : t.panel2, size: 12),
            ],
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: main),
        const SizedBox(width: 8),
        SizedBox(
          width: 236,
          child: BentoGrid(
            columns: 2,
            rows: 3,
            cells: [
              BentoCell(0, 0, preset(0)),
              BentoCell(1, 0, preset(1)),
              BentoCell(0, 1, preset(2)),
              BentoCell(1, 1, preset(3)),
              BentoCell(0, 2, today, colSpan: 2),
            ],
          ),
        ),
      ],
    );
  }
}
