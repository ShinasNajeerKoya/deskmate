import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/focus_timer.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/edge_widgets.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';

/// Edge · Timer: a tick dial on the left (60 ticks and a thin inner arc that count down), the four
/// presets, Start/Pause and Reset on the right, and how far you are in the four-session round.
/// The timer runs on the phone, so this works before the computer is found.
class EdgeTimer extends StatelessWidget {
  const EdgeTimer({super.key, required this.now, required this.use24h});

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
          EdgePageHeader(
            icon: DIcon.timer,
            color: t.blue,
            title: 'Timer',
            note: 'Runs on the phone · ${clockText(now, use24h)}',
          ),
          Expanded(
            // Laid out at the design's size; shorter or narrower screens scale it down.
            child: LayoutBuilder(
              builder:
                  (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: max(box.maxWidth, 859),
                      height: max(box.maxHeight, 290),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [_Dial(), SizedBox(width: 56), Expanded(child: _Controls())],
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

/// How many of the 60 outer ticks are lit: the seconds of the time shown, so the ring sweeps down
/// once every minute (07:42 → 42, 07:00 → 60 and then 06:59 → 59). Nothing left → 0.
int litTicks(Duration remaining) {
  final s = (remaining.inMilliseconds / 1000).ceil();
  if (s <= 0) return 0;
  return s % 60 == 0 ? 60 : s % 60;
}

/// How the 60 outer ticks show the seconds (index 0 is at the top, 1, 2, 3 … go down the right side and
/// 59, 58, 57 … go down the left side). [lit] is [litTicks]: 60 at the start of a minute down to 1.
///
/// - From 60 down to 20 the active ticks are 0 .. lit-1, all solid blue: ticks 59, 58, 57 … go dark one by one.
/// - Below 20 a second end starts moving. The lit part is always 20 ticks, ending at the head (lit-1) and
///   reaching back past the top: 15 solid ticks and, at the tail, a 5-tick fade from blue to grey. At 19 tick 59
///   appears (mostly blue), at 18 tick 58, then 57, 56, 55 (grey); from 14 on the solid part follows (59 turns
///   solid, then 58 …) and the fade moves on with it. Both ends keep moving until the minute is up.
/// - The head (the last [headTicks] ticks) is always thick and solid.
/// - After the first minute it never resets: with [snake] the 20 ticks (15 solid + the 5-tick fade) keep
///   going round, one tick a second, so the head is at `seconds % 60 - 1` all the time.
const arcLength = 20;
const coreLength = 15;
const headTicks = 3;

/// Blue amount of the fade ticks, counting away from the solid part: 85%, then less, down to grey.
const bandMix = [0.85, 0.68, 0.5, 0.28, 0.0];

/// How a tick is drawn: null when it is dark, else how blue it is (1 = solid) and whether it is the head.
({double mix, bool head})? tickState(int index, int lit, {bool snake = false}) {
  if (!snake && lit <= 0) return null;
  if (!snake && lit >= arcLength) {
    return index < lit ? (mix: 1.0, head: index >= lit - headTicks) : null;
  }
  final rel = (index - (lit - arcLength)) % 60; // 0 at the tail end, 19 at the head
  if (rel >= arcLength) return null;
  final bands = snake ? arcLength - coreLength : min(arcLength - coreLength, arcLength - lit); // fade ticks so far
  final head = rel >= arcLength - headTicks;
  if (rel >= bands) return (mix: 1.0, head: head);
  return (mix: bandMix[bands - rel - 1], head: head); // rel 0 is the farthest, greyest one
}

/// What the dial shows for the time left: the lit count and whether it's the continuous snake. The first
/// minute of a run starts with all 60 ticks (and so does a timer that hasn't started); after that the snake
/// keeps rotating through every following minute without resetting.
({int lit, bool snake}) dialTicks(Duration remaining, Duration total) {
  final secondsLeft = (remaining.inMilliseconds / 1000).ceil();
  if (secondsLeft <= 0) return (lit: 0, snake: false);
  final elapsed = total - remaining;
  if (elapsed < const Duration(seconds: 60)) return (lit: litTicks(remaining), snake: false);
  return (lit: secondsLeft % 60, snake: true);
}

String _clock(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  return '${two(s ~/ 60)}:${two(s % 60)}';
}

class _Dial extends StatelessWidget {
  const _Dial();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final timer = AppScope.of(context).timer;
    final left = (timer.remaining.inMilliseconds / timer.total.inMilliseconds).clamp(0.0, 1.0);
    final state = timer.running ? 'running' : (timer.started ? 'paused' : 'ready');
    return Semantics(
      label: '${timer.preset.name} timer, ${_clock(timer.remaining)} left',
      child: SizedBox(
        width: 250,
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(250),
              painter: _DialPainter(
                left,
                dialTicks(timer.remaining, timer.total),
                t.blue,
                t.text.withValues(alpha: 0.16),
                t.ringTrack,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_clock(timer.remaining), style: t.num(40, weight: 200, height: 1, letterSpacing: -1)),
                const SizedBox(height: 6),
                EdgeLabel('${timer.preset.name} · $state', color: t.blue, size: 9, spacing: 2),
                const SizedBox(height: 6),
                Text('of ${timer.preset.minutes} min', style: t.ui(10, color: t.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 60 ticks that count the seconds of the minute (the lit ones sweep down once a minute, every fifth is
/// longer) and a thin inner arc with a glowing dot for the time left in the whole timer.
class _DialPainter extends CustomPainter {
  _DialPainter(this.left, this.ticks, this.color, this.off, this.track);

  final double left;
  final ({int lit, bool snake}) ticks;
  final Color color, off, track;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100; // the design is drawn on a 100-unit dial
    final c = Offset(size.width / 2, size.height / 2);
    Paint stroke(Color col, double w) =>
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * k
          ..color = col;
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * pi;
      final major = i % 5 == 0;
      final r1 = (major ? 40.5 : 43) * k, r2 = 48 * k;
      final p1 = c + Offset(sin(a), -cos(a)) * r1;
      final p2 = c + Offset(sin(a), -cos(a)) * r2;
      final state = tickState(i, ticks.lit, snake: ticks.snake);
      final paint =
          state == null
              ? stroke(off, 0.9)
              : (state.head
                  ? stroke(color, 1.8)
                  : stroke(Color.lerp(off, color, state.mix)!, state.mix == 1.0 && major ? 1.5 : 0.9));
      canvas.drawLine(p1, p2, paint);
    }
    final r = 35 * k;
    canvas.drawCircle(c, r, stroke(track, 1));
    if (left > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * left, false, stroke(color, 1));
    }
    final ang = 2 * pi * left;
    final knob = c + Offset(sin(ang), -cos(ang)) * r;
    canvas.drawCircle(knob, 6 * k, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(knob, 3.2 * k, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.left != left || old.ticks != ticks || old.color != color;
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final timer = AppScope.of(context).timer;
    final done = timer.focusDoneToday % FocusTimer.sessionsPerRound;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EdgeLabel('Presets', size: 11, spacing: 2),
        const SizedBox(height: 4),
        for (var i = 0; i < FocusTimer.presets.length; i++)
          _PresetRow(preset: FocusTimer.presets[i], last: i == FocusTimer.presets.length - 1),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  label: timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: timer.toggle,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(color: t.text, shape: BoxShape.circle),
                      child: Center(child: DIconView(timer.running ? DIcon.pause : DIcon.play, size: 28, color: t.bg)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Semantics(
                  button: true,
                  label: 'Reset',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: timer.reset,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.text.withValues(alpha: 0.22)),
                      ),
                      child: Center(child: DIconView(DIcon.reset, size: 22, color: t.text, strokeWidth: 2)),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                EdgeLabel('Session ${done + 1} of ${FocusTimer.sessionsPerRound}', size: 11, spacing: 2),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < FocusTimer.sessionsPerRound; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              i < done
                                  ? t.blue
                                  : (i == done ? t.blue.withValues(alpha: 0.5) : t.text.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text('${hm(timer.focusedToday)} focused today', style: t.ui(12, color: t.muted)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.preset, required this.last});

  final TimerPreset preset;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final timer = AppScope.of(context).timer;
    final on = timer.preset == preset;
    return Semantics(
      button: true,
      selected: on,
      label: '${preset.name}, ${preset.minutes} minutes',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => timer.select(preset),
        child: Container(
          height: 40,
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.hairline))),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: on ? t.blue : Colors.transparent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(preset.name, style: t.ui(15, weight: on ? 500 : 400, color: on ? t.text : t.textSoft)),
              ),
              Text('${preset.minutes} min', style: t.ui(13, color: on ? t.blue : t.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
