import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/focus_timer.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';
import '../../ui/paper_widgets.dart';

/// Paper · Timer: the time left on a dark card with a tick bar, Pause and Reset, and the four presets with
/// the session bars. The timer runs on the phone, so this works before the computer is found.
class PaperTimer extends StatelessWidget {
  const PaperTimer({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final timer = AppScope.of(context).timer;
    final secs = (timer.remaining.inMilliseconds / 1000).ceil();
    final left = (timer.remaining.inMilliseconds / timer.total.inMilliseconds).clamp(0.0, 1.0);
    final state = timer.running ? 'running' : (timer.started ? 'paused' : 'ready');
    final done = timer.focusDoneToday % FocusTimer.sessionsPerRound;

    final dial = PaperCard(
      ink: true,
      label: '${timer.preset.name} timer, ${two(secs ~/ 60)}:${two(secs % 60)} left',
      fitHeight: 250,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PaperLabel('Timer', color: t.inkMuted),
              PaperLabel('${timer.preset.name} · $state', color: t.inkMuted),
            ],
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${two(secs ~/ 60)}:${two(secs % 60)}',
                    style: t.num(112, weight: 600, height: 1, letterSpacing: -4, color: t.onInk),
                  ),
                  const SizedBox(height: 8),
                  PaperLabel('of ${timer.preset.minutes} min', color: t.inkMuted),
                ],
              ),
            ),
          ),
          Column(
            children: [
              PaperTicks(count: 30, lit: (left * 30).round(), height: 22, offColor: t.onInk.withValues(alpha: 0.18)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PaperPillButton(
                      label: timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
                      dark: true,
                      onTap: timer.toggle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: PaperPillButton(label: 'Reset', dark: true, filled: false, onTap: timer.reset),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final presets = PaperCard(
      label: 'Presets',
      fitHeight: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PaperLabel('Presets'),
              const SizedBox(height: 6),
              for (var i = 0; i < FocusTimer.presets.length; i++)
                _PresetRow(preset: FocusTimer.presets[i], last: i == FocusTimer.presets.length - 1),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaperLabel('Session ${done + 1} of ${FocusTimer.sessionsPerRound}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < FocusTimer.sessionsPerRound; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < done ? t.ink : (i == done ? t.clay : t.border),
                          borderRadius: BorderRadius.circular(2),
                        ),
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
    );

    return Column(
      children: [
        PaperHeader(title: 'Timer', notes: [const PaperNote('Runs on the phone'), PaperNote(clockText(now, use24h))]),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: dial), const SizedBox(width: 8), SizedBox(width: 290, child: presets)],
          ),
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
          height: 48,
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.bg))),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? t.clay : Colors.transparent,
                  border: Border.all(color: on ? t.clay : t.divider),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(preset.name, style: t.ui(14, weight: on ? 500 : 400))),
              Text('${preset.minutes} MIN', style: t.num(12, weight: 500, color: t.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
