import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/focus_timer.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';

/// Horizon · Timer: a huge thin time left with a glowing progress line, Pause and Reset, and on the right the four
/// presets with the session bars. The timer runs on the phone, so this works before the computer is found.
class HorizonTimer extends StatelessWidget {
  const HorizonTimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 16, 34, 68),
      child: LayoutBuilder(
        builder:
            (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: max(box.maxWidth, 847),
                height: max(box.maxHeight, 330),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: _Dial()), SizedBox(width: 32), SizedBox(width: 300, child: _Side())],
                ),
              ),
            ),
      ),
    );
  }
}

Widget _caps(DeskmateTokens t, String s, {Color? color}) => Text(
  s.toUpperCase(),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: t.ui(11, weight: 600, color: color ?? t.muted).copyWith(letterSpacing: 2.4),
);

class _Dial extends StatelessWidget {
  const _Dial();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final timer = AppScope.of(context).timer;
    final secs = (timer.remaining.inMilliseconds / 1000).ceil();
    final left = (timer.remaining.inMilliseconds / timer.total.inMilliseconds).clamp(0.0, 1.0);
    final state = timer.running ? 'running' : (timer.started ? 'paused' : 'ready');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _caps(t, 'Timer'),
            _caps(t, '${timer.preset.name} · $state', color: timer.running ? t.clay : t.muted),
          ],
        ),
        Semantics(
          label: '${timer.preset.name} timer, ${two(secs ~/ 60)}:${two(secs % 60)} left',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${two(secs ~/ 60)}:${two(secs % 60)}',
                  style: t.num(168, weight: 100, height: 0.95, letterSpacing: -8),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 9,
                child: LayoutBuilder(
                  builder:
                      (context, box) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 3,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: t.text.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 3,
                            child: Container(
                              width: box.maxWidth * left,
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(colors: [t.text.withValues(alpha: 0.2), t.text]),
                              ),
                            ),
                          ),
                          Positioned(
                            left: box.maxWidth * left - 4.5,
                            top: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: t.clay,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: t.clay, blurRadius: 12)],
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'of ${timer.preset.minutes} min',
                style: t.ui(12, weight: 500, color: t.muted.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Semantics(
              button: true,
              label: timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: timer.toggle,
                child: Container(
                  width: 150,
                  height: 64,
                  decoration: BoxDecoration(color: t.text, borderRadius: BorderRadius.circular(32)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DIconView(timer.running ? DIcon.pause : DIcon.play, size: 20, color: t.bg),
                      const SizedBox(width: 10),
                      Text(
                        timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
                        style: t.ui(16, weight: 600, color: t.bg),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Reset',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: timer.reset,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x2EFFFFFF))),
                  child: Center(child: DIconView(DIcon.reset, size: 22, color: t.text, strokeWidth: 1.8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final timer = AppScope.of(context).timer;
    final done = timer.focusDoneToday % FocusTimer.sessionsPerRound;

    Widget preset(TimerPreset p) {
      final on = timer.preset == p;
      return Semantics(
        button: true,
        selected: on,
        label: '${p.name}, ${p.minutes} minutes',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => timer.select(p),
          child: Container(
            height: 56,
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x14EAF0FF)))),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? t.clay : Colors.transparent,
                    border: Border.all(color: on ? t.clay : t.text.withValues(alpha: 0.25)),
                    boxShadow: on ? [BoxShadow(color: t.clay, blurRadius: 8)] : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.ui(17, weight: on ? 500 : 400, color: on ? t.text : t.muted),
                  ),
                ),
                Text('${p.minutes} min', style: t.ui(13, weight: 500, color: t.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_caps(t, 'Presets'), const SizedBox(height: 8), for (final p in FocusTimer.presets) preset(p)],
        ),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x1AEAF0FF)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _caps(t, 'Session ${done + 1} of ${FocusTimer.sessionsPerRound}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < FocusTimer.sessionsPerRound; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < done ? t.text : (i == done ? t.clay : t.text.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text('${hm(timer.focusedToday)} focused today', style: t.ui(12, weight: 500, color: t.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
