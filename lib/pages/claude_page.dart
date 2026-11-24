import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/format.dart';
import '../ui/widgets.dart';

class ClaudePage extends StatefulWidget {
  const ClaudePage({super.key, required this.now, this.use24h = false});

  final DateTime now;
  final bool use24h;

  @override
  State<ClaudePage> createState() => _ClaudePageState();
}

class _ClaudePageState extends State<ClaudePage> {
  /// Day picked in the tokens chart (0 = 6 days ago … 6 = today); null = today.
  int? _day;

  DateTime get now => widget.now;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final c = AppScope.of(context).link.board.claude;
    final reset = c?.fiveHourResetMin;

    final fiveHour = Tile(
      color: t.clay,
      radius: t.radiusTileLarge,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      label: '5-hour limit',
      fitHeight: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '5-hour limit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(14, weight: 600, color: t.clayInk),
                ),
              ),
              if (reset != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Pill(
                      color: t.clayInk.withValues(alpha: 0.12),
                      child: Text(
                        'Resets in ${hm(Duration(minutes: reset))}',
                        maxLines: 1,
                        style: t.ui(12, weight: 600, color: t.clayInk),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'at ${clockWithSuffix(now.add(Duration(minutes: reset)), widget.use24h)}',
                      maxLines: 1,
                      style: t.ui(12, color: t.clayInk.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
            ],
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(pct(c?.fiveHourPct), style: t.num(92, height: 0.95, letterSpacing: -3, color: t.clayInk)),
            ),
          ),
          SegmentBar(
            count: 10,
            filled: ((c?.fiveHourPct ?? 0) / 10).round(),
            on: t.clayInk,
            off: t.clayInk.withValues(alpha: 0.2),
            height: 12,
          ),
        ],
      ),
    );

    final weekly = Tile(
      color: t.cream,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      label: 'Weekly limit',
      fitHeight: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(child: Text('Weekly limit', style: t.ui(13, weight: 600, color: t.creamInk))),
              if (c?.weeklyReset != null) Text('Resets ${c!.weeklyReset}', style: t.ui(12, color: t.creamMuted)),
            ],
          ),
          Row(
            children: [
              Text(pct(c?.weeklyPct), style: t.num(34, height: 1, color: t.creamInk)),
              const SizedBox(width: 14),
              Expanded(
                child: ProgressLine(value: (c?.weeklyPct ?? 0) / 100, fill: t.creamInk, track: t.cream2, height: 10),
              ),
            ],
          ),
        ],
      ),
    );

    final waiting = c?.waiting ?? 0;
    final sessions = Tile(
      color: t.butter,
      radius: 22,
      label: 'Sessions',
      fitHeight: 74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Sessions', style: t.ui(13, weight: 600, color: t.butterInk)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c?.sessions?.toString() ?? '—', style: t.num(34, height: 1, color: t.butterInk)),
              const SizedBox(height: 4),
              Text(
                waiting > 0 ? '$waiting waiting for you' : 'None waiting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.ui(12, weight: 600, color: t.butterInk),
              ),
            ],
          ),
        ],
      ),
    );

    final byModel = Tile(
      color: t.mint,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      label: 'Usage by model',
      fitHeight: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By model', style: t.ui(13, weight: 600, color: t.mintInk)),
          const SizedBox(height: 6),
          for (final (i, m) in (c?.models ?? const []).take(3).indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(12, weight: 500, color: t.mintInk),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ProgressLine(value: m.share, fill: t.mintInk, track: t.mintInk.withValues(alpha: 0.15)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final days = c?.tokens7d ?? const <int>[];
    final today = days.isEmpty ? 0 : days.length - 1;
    final picked = (_day != null && _day! < days.length) ? _day! : today;
    DateTime dayDate(int i) => now.subtract(Duration(days: today - i));
    final maxDay = days.isEmpty ? 1 : max(1, days.reduce(max));
    final tokens = Tile(
      color: t.panel,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      label: 'Tokens this week',
      fitHeight: 60,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                picked == today ? 'Tokens today' : 'Tokens · ${weekdayShort(dayDate(picked))}',
                style: t.ui(12, color: t.muted),
              ),
              Text(compact(days.isEmpty ? null : days[picked]), style: t.num(34, height: 1.1)),
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
                    // Tap a day to see its tokens; tap it again for today.
                    child: Semantics(
                      button: true,
                      selected: i == picked,
                      label: '${weekdayShort(dayDate(i))}: ${compact(days[i])} tokens',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _day = (i == picked || i == today) ? null : i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: max(0.06, days[i] / maxDay),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: i == picked ? t.clay : t.violet2,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              weekdayLetter(dayDate(i)),
                              style: t.ui(11, weight: i == picked ? 700 : 400, color: i == picked ? t.text : t.muted),
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

    return BentoGrid(
      columns: 4,
      rows: 3,
      cells: [
        BentoCell(0, 0, fiveHour, colSpan: 2, rowSpan: 2),
        BentoCell(2, 0, weekly, colSpan: 2),
        BentoCell(2, 1, sessions),
        BentoCell(3, 1, byModel),
        BentoCell(0, 2, tokens, colSpan: 4),
      ],
    );
  }
}
