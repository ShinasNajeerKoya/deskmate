import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';
import '../../ui/paper_widgets.dart';
import '../../ui/widgets.dart';

/// Paper · Claude: the 5-hour limit on a dark card, the weekly limit, sessions, usage by model and the
/// 7-day tokens (tap a day to see its tokens).
class PaperClaude extends StatefulWidget {
  const PaperClaude({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  @override
  State<PaperClaude> createState() => _PaperClaudeState();
}

class _PaperClaudeState extends State<PaperClaude> {
  int? _day; // 0 = 6 days ago … 6 = today; null = today

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final c = AppScope.of(context).link.board.claude;
    final now = widget.now;
    final reset = c?.fiveHourResetMin;
    final approx = c?.fiveHourEst == true ? '~' : '';
    final five = c?.fiveHourPct;

    final days = c?.tokens7d ?? const <int>[];
    final today = days.isEmpty ? 0 : days.length - 1;
    final picked = (_day != null && _day! < days.length) ? _day! : today;
    DateTime dayDate(int i) => now.subtract(Duration(days: today - i));
    final maxDay = days.isEmpty ? 1 : max(1, days.reduce(max));
    final waiting = c?.waiting ?? 0;
    final models = (c?.models ?? const <ModelShare>[]).take(3).toList();
    final modelColors = [t.clay, t.ink, t.muted];

    String weeklyReset() {
      final m = c?.weeklyResetTime;
      final day = c?.weeklyReset;
      if (day == null) return '';
      if (m == null) return 'Resets $day';
      return 'Resets $day · ${clockWithSuffix(DateTime(2000, 1, 1, m ~/ 60, m % 60), widget.use24h)}';
    }

    final fiveHour = PaperCard(
      ink: true,
      label: '5-hour limit',
      fitHeight: 165,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PaperLabel('Claude · 5h limit', color: t.inkMuted)),
              if (reset != null)
                Text(
                  'RESETS IN $approx${hm(Duration(minutes: reset))}\nAT $approx${clockWithSuffix(now.add(Duration(minutes: reset)), widget.use24h)}'
                      .toUpperCase(),
                  textAlign: TextAlign.right,
                  style: t.num(11, weight: 500, color: t.inkMuted, letterSpacing: 1, height: 1.5),
                ),
            ],
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
                  Text(
                    five == null ? '—' : '${five.round()}',
                    style: t.num(84, weight: 600, height: 1, letterSpacing: -3, color: t.onInk),
                  ),
                  Text('%', style: t.num(36, weight: 600, color: t.inkMuted)),
                ],
              ),
            ),
          ),
          PaperTicks(
            count: 30,
            lit: (((five ?? 0) / 100) * 30).round(),
            height: 24,
            offColor: t.onInk.withValues(alpha: 0.18),
          ),
        ],
      ),
    );

    final weekly = PaperCard(
      label: 'Weekly limit',
      fitHeight: 84,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [const Expanded(child: PaperLabel('Weekly limit')), PaperLabel(weeklyReset())]),
          Row(
            children: [
              Text(c?.weeklyPct == null ? '—' : '${c!.weeklyPct!.round()}%', style: t.num(34, weight: 600, height: 1)),
              const SizedBox(width: 14),
              Expanded(child: PaperBar(value: (c?.weeklyPct ?? 0) / 100, height: 8)),
            ],
          ),
        ],
      ),
    );

    final sessions = PaperCard(
      label: 'Sessions',
      fitHeight: 84,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PaperLabel('Sessions'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c?.sessions == null ? '—' : two(c!.sessions!), style: t.num(34, weight: 600, height: 1)),
              const SizedBox(height: 5),
              Text(
                waiting > 0 ? '$waiting waiting for you' : 'None waiting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.ui(12, weight: 500, color: waiting > 0 ? t.clay : t.muted),
              ),
            ],
          ),
        ],
      ),
    );

    final byModel = PaperCard(
      label: 'Usage by model',
      fitHeight: 80,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PaperLabel('By model'),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < models.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(models[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(12)),
                      ),
                      Expanded(child: PaperBar(value: models[i].share, height: 5, fill: modelColors[i])),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${(models[i].share * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: t.num(11, weight: 500, color: t.muted),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final tokens = PaperCard(
      label: 'Tokens this week',
      fitHeight: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaperLabel(picked == today ? 'Tokens today' : 'Tokens · ${weekdayShort(dayDate(picked))}'),
              const SizedBox(height: 4),
              Text(compact(days.isEmpty ? null : days[picked]), style: t.num(34, weight: 600, height: 1.1)),
            ],
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == picked,
                      label: '${weekdayShort(dayDate(i))}: ${compact(days[i])} tokens',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Tap a day to see its tokens; tap it again (or today) to go back to today.
                        onTap: () => setState(() => _day = (i == picked || i == today) ? null : i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: max(0.06, days[i] / maxDay),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: i == picked ? t.clay : t.border,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              weekdayLetter(dayDate(i)),
                              style: t.num(10, weight: i == picked ? 600 : 500, color: i == picked ? t.text : t.muted),
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
        ],
      ),
    );

    return Column(
      children: [
        PaperHeader(title: 'Claude', notes: [PaperNote('Mac', dot: t.ok), PaperNote(clockText(now, widget.use24h))]),
        Expanded(
          child: BentoGrid(
            columns: 4,
            rows: 3,
            cells: [
              BentoCell(0, 0, fiveHour, colSpan: 2, rowSpan: 2),
              BentoCell(2, 0, weekly, colSpan: 2),
              BentoCell(2, 1, sessions),
              BentoCell(3, 1, byModel),
              BentoCell(0, 2, tokens, colSpan: 4),
            ],
          ),
        ),
      ],
    );
  }
}
