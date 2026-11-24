import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/edge_widgets.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';

/// Edge · Claude: two big rings (5-hour and weekly limit) on the left; sessions, tokens,
/// usage by model and the 7-day chart on the right. Tap a day's bar to see its tokens.
class EdgeClaude extends StatefulWidget {
  const EdgeClaude({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  @override
  State<EdgeClaude> createState() => _EdgeClaudeState();
}

class _EdgeClaudeState extends State<EdgeClaude> {
  /// Day picked in the chart (0 = 6 days ago … 6 = today); null = today.
  int? _day;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final c = AppScope.of(context).link.board.claude;
    final now = widget.now;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EdgePageHeader(icon: DIcon.claude, color: t.clay, title: 'Claude', note: clockText(now, widget.use24h)),
          Expanded(
            // Scales down on short screens instead of overflowing.
            child: LayoutBuilder(
              builder:
                  (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      // Laid out at the design's 859 × 300 at least; narrower or shorter screens scale it down.
                      width: max(box.maxWidth, 859),
                      height: max(box.maxHeight, 300),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [_limits(t, c), const SizedBox(width: 34), Expanded(child: _details(t, c))],
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Resets Fri · 3:30 PM": the weekday and the clock time of the weekly reset (not the time left).
  String _weeklyReset(ClaudeUsage c) {
    final minutes = c.weeklyResetTime;
    if (minutes == null) return 'Resets ${c.weeklyReset}';
    final at = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    return 'Resets ${c.weeklyReset} · ${clockWithSuffix(at, widget.use24h)}';
  }

  /// How old Claude Code's last exact reading is, once it's more than a couple of minutes.
  String? _age(ClaudeUsage? c) {
    final a = c?.readAgeMin;
    if (a == null || c?.fiveHourPct == null || a < 2) return null;
    return 'Reading from ${hm(Duration(minutes: a))} ago';
  }

  Widget _limits(DeskmateTokens t, ClaudeUsage? c) {
    final reset = c?.fiveHourResetMin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BigRing(
          value: c?.fiveHourPct,
          color: t.clay,
          label: '5-hour limit',
          notes: [
            // From the logs (not Claude's own reading) the reset time is approximate: marked with "~".
            if (reset != null) 'Resets in ${c?.fiveHourEst == true ? '~' : ''}${hm(Duration(minutes: reset))}',
            if (reset != null)
              'at ${c?.fiveHourEst == true ? '~' : ''}${clockWithSuffix(widget.now.add(Duration(minutes: reset)), widget.use24h)}',
            if (_age(c) != null) _age(c)!,
          ],
        ),
        const SizedBox(width: 30),
        _BigRing(
          value: c?.weeklyPct,
          color: t.amber,
          label: 'Weekly limit',
          notes: [if (c?.weeklyReset != null) _weeklyReset(c!), if (_age(c) != null) _age(c)!],
        ),
      ],
    );
  }

  Widget _details(DeskmateTokens t, ClaudeUsage? c) {
    final days = c?.tokens7d ?? const <int>[];
    final today = days.isEmpty ? 0 : days.length - 1;
    final picked = (_day != null && _day! < days.length) ? _day! : today;
    DateTime dayDate(int i) => widget.now.subtract(Duration(days: today - i));
    final maxDay = days.isEmpty ? 1 : max(1, days.reduce(max));
    final waiting = c?.waiting ?? 0;
    final colors = [t.clay, t.accentViolet, t.teal];
    final models = (c?.models ?? const <ModelShare>[]).take(3).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.hairline))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EdgeLabel('Sessions', size: 11, spacing: 2),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(c?.sessions?.toString() ?? '—', style: t.num(38, weight: 300, height: 1.1)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            waiting > 0 ? '$waiting waiting for you' : 'None waiting',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.ui(14, color: waiting > 0 ? t.clay : t.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  EdgeLabel(
                    picked == today ? 'Tokens today' : 'Tokens · ${weekdayShort(dayDate(picked))}',
                    size: 11,
                    spacing: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(compact(days.isEmpty ? null : days[picked]), style: t.num(38, weight: 300, height: 1.1)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const EdgeLabel('By model', size: 11, spacing: 2),
        const SizedBox(height: 8),
        for (var i = 0; i < models.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(
              children: [
                SizedBox(width: 56, child: Text(models[i].name, maxLines: 1, style: t.ui(13))),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(height: 5, color: t.ringTrack),
                        FractionallySizedBox(
                          widthFactor: models[i].share.clamp(0.0, 1.0),
                          child: Container(height: 5, color: colors[i]),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(models[i].share * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: t.ui(13, color: t.muted),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: _hourly(t, c)),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EdgeLabel('Last 7 days', size: 10, spacing: 1.5),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 62,
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
                                            color: i == picked ? t.clay : t.text.withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      weekdayLetter(dayDate(i)),
                                      style: t.ui(
                                        10,
                                        weight: i == picked ? 700 : 400,
                                        color: i == picked ? t.text : t.muted,
                                      ),
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
            ),
          ],
        ),
      ],
    );
  }
}

extension on _EdgeClaudeState {
  /// Tokens per hour of the current 5-hour block, updating live as you prompt.
  Widget _hourly(DeskmateTokens t, ClaudeUsage? c) {
    final hours = c?.blockHours ?? const <int>[];
    final start = c?.blockStartHour;
    final maxHour = hours.isEmpty ? 1 : max(1, hours.reduce(max));
    // The newest bucket that has tokens is the hour you're in.
    final current = hours.lastIndexWhere((v) => v > 0);
    String hourLabel(int i) {
      final h = ((start ?? 0) + i) % 24;
      return widget.use24h ? '$h' : '${h % 12 == 0 ? 12 : h % 12}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EdgeLabel(
          c?.blockTokens == null ? '5-hour block' : '5-hour block · ${compact(c!.blockTokens)}',
          size: 10,
          spacing: 1.5,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < hours.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    label: '${hourLabel(i)} o\'clock: ${compact(hours[i])} tokens',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: max(0.06, hours[i] / maxHour),
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == current ? t.clay : t.text.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hourLabel(i),
                          style: t.ui(10, weight: i == current ? 700 : 400, color: i == current ? t.text : t.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A 190 px ring with the percentage in the middle and a label and notes underneath.
class _BigRing extends StatelessWidget {
  const _BigRing({required this.value, required this.color, required this.label, required this.notes});

  final double? value;
  final Color color;
  final String label;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EdgeRing(
          size: 190,
          stroke: 7,
          value: (value ?? 0) / 100,
          color: color,
          child: SizedBox(
            width: 120,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value == null ? '—' : '${value!.round()}', style: t.num(58, weight: 300, height: 1)),
                  Text('%', style: t.ui(24, color: t.muted)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        EdgeLabel(label, color: color, size: 11, spacing: 2),
        for (final n in notes) ...[const SizedBox(height: 3), Text(n, style: t.ui(12, color: t.muted))],
      ],
    );
  }
}
