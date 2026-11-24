import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';

/// Horizon · Claude: a large thin 5-hour figure with its hourly columns on the left; the weekly limit,
/// sessions, usage by model and the 7-day bars on the right. Tap a day's bar to see its tokens.
class HorizonClaude extends StatefulWidget {
  const HorizonClaude({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  @override
  State<HorizonClaude> createState() => _HorizonClaudeState();
}

class _HorizonClaudeState extends State<HorizonClaude> {
  /// Day picked in the chart (0 = 6 days ago … 6 = today); null = today.
  int? _day;

  /// 5-hour session picked in the columns (0 = oldest); null = the current one.
  int? _session;

  Widget _caps(DeskmateTokens t, String s, {Color? color}) => Text(
    s.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: t.ui(11, weight: 600, color: color ?? t.muted).copyWith(letterSpacing: 2.4),
  );

  Widget _bar(DeskmateTokens t, double v, Color c) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: Stack(
      children: [
        Container(height: 3, color: t.text.withValues(alpha: 0.12)),
        FractionallySizedBox(widthFactor: v.clamp(0.0, 1.0), child: Container(height: 3, color: c)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final c = AppScope.of(context).link.board.claude;
    return Padding(
      // Room at the bottom for the floating bar.
      padding: const EdgeInsets.fromLTRB(34, 16, 34, 78),
      child: LayoutBuilder(
        builder:
            (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: max(box.maxWidth, 840),
                height: max(box.maxHeight, 350),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 430, child: _fiveHour(t, c)),
                    const SizedBox(width: 32),
                    Expanded(child: _details(t, c)),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  String? _resetLine(ClaudeUsage? c) {
    final r = c?.fiveHourResetMin;
    if (r == null) return null;
    final est = c?.fiveHourEst == true ? '~' : '';
    final at = clockWithSuffix(widget.now.add(Duration(minutes: r)), widget.use24h);
    return 'Resets in $est${hm(Duration(minutes: r))} · $est$at';
  }

  /// "9 AM – 2 PM": the 5 hours a session covers.
  String _window(BlockSession b) {
    String at(DateTime d) => clockWithSuffix(DateTime(2000, 1, 1, d.hour), widget.use24h);
    return '${at(b.start)} – ${at(b.end)}';
  }

  /// A short start-time label under a column: "9a" or "09".
  String _short(BlockSession b) {
    final h = b.start.hour;
    return widget.use24h ? two(h) : '${h % 12 == 0 ? 12 : h % 12}${h < 12 ? 'a' : 'p'}';
  }

  Widget _fiveHour(DeskmateTokens t, ClaudeUsage? c) {
    // Six fixed 5-hour slots: four past ones, the current one in 5th place and the next one in 6th. Real sessions
    // are placed in their slot; slots without one stay empty. When no session is running the timings are guessed
    // from the latest session.
    var real = c?.blockSessions ?? const <BlockSession>[];
    if (real.isEmpty && c?.blockTokens != null && c?.blockStartHour != null) {
      // An older Hub sends only the current session.
      var start = DateTime(widget.now.year, widget.now.month, widget.now.day, c!.blockStartHour!);
      if (start.isAfter(widget.now)) start = start.subtract(const Duration(days: 1));
      real = [BlockSession(start, c.blockTokens!)];
    }
    const five = Duration(hours: 5);
    final now = widget.now;
    DateTime anchor; // the start of the current slot
    if (real.isNotEmpty && real.last.end.isAfter(now)) {
      anchor = real.last.start;
    } else if (real.isNotEmpty) {
      final k = now.difference(real.last.start).inMinutes ~/ 300;
      anchor = real.last.start.add(five * k);
    } else {
      anchor = DateTime(now.year, now.month, now.day, now.hour);
    }
    final first = anchor.subtract(five * 4);
    final slots = [for (var i = 0; i < 6; i++) BlockSession(first.add(five * i), 0)];
    final tokens = List<int>.filled(6, 0);
    for (final r in real) {
      // The nearest slot: a session's start can be a few minutes off the guessed grid.
      final i = (r.start.difference(first).inMinutes / 300).round();
      if (i < 0 || i > 4) continue;
      tokens[i] += r.tokens;
    }
    const current = 4;
    final picked = _session ?? current;
    final shown = slots[picked];
    final shownTokens = tokens[picked];
    final maxTokens = max(1, tokens.reduce(max));
    String dayWord(DateTime d) {
      final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
      return days == 0 ? 'Today' : (days == 1 ? 'Yesterday' : weekdayShort(d));
    }

    final reset = _resetLine(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _caps(t, 'Claude · 5-hour limit')),
            if (reset != null)
              Flexible(
                child: Text(
                  reset,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(12, weight: 500, color: t.muted.withValues(alpha: 0.8)),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                c?.fiveHourPct == null ? '—' : '${c!.fiveHourPct!.round()}',
                style: t.num(118, weight: 100, height: 1).copyWith(letterSpacing: -5),
              ),
              Text('%', style: t.ui(40, weight: 300, color: t.muted)),
              const SizedBox(width: 18),
              // The tokens of the picked 5-hour session and the hours it covers (tap a column to change it).
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      picked == 5
                          ? 'Not started yet'
                          : (shownTokens == 0 ? 'No usage' : '${compact(shownTokens)} tokens'),
                      maxLines: 1,
                      style: t.ui(15, weight: 600),
                    ),
                    ...[
                      const SizedBox(height: 2),
                      Text(
                        picked == current
                            ? 'This session · ${_window(shown)}'
                            : (picked == 5
                                ? 'Next · ${_window(shown)}'
                                : '${dayWord(shown.start)} · ${_window(shown)}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(12, weight: 500, color: t.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _caps(t, 'Tokens per 5-hour session'),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < slots.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == picked,
                    label: '${dayWord(slots[i].start)} ${_window(slots[i])}: ${compact(tokens[i])} tokens',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Tap a session to see its tokens and hours; tap it again (or the current one) to go back.
                      onTap: () => setState(() => _session = (i == picked || i == current) ? null : i),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: max(0.04, tokens[i] / maxTokens),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                      bottom: Radius.circular(2),
                                    ),
                                    color:
                                        i == picked ? t.clay : (tokens[i] == 0 ? t.text.withValues(alpha: 0.12) : null),
                                    gradient:
                                        (i == picked || tokens[i] == 0)
                                            ? null
                                            : LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [t.text.withValues(alpha: 0.85), t.text.withValues(alpha: 0.15)],
                                            ),
                                  ),
                                  child: const SizedBox(width: double.infinity),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _short(slots[i]),
                            style: t.ui(11, weight: 500, color: i == picked ? t.text : t.muted.withValues(alpha: 0.8)),
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
    );
  }

  String _weeklyReset(ClaudeUsage c) {
    final minutes = c.weeklyResetTime;
    if (minutes == null) return 'Resets ${c.weeklyReset}';
    final at = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    return 'Resets ${c.weeklyReset} · ${clockWithSuffix(at, widget.use24h)}';
  }

  /// A block of the right column: a hairline above, 8 px of padding above and below (the design's spacing).
  Widget _section(DeskmateTokens t, Widget child, {bool last = false}) => Container(
    padding: EdgeInsets.fromLTRB(0, 8, 0, last ? 0 : 8),
    decoration: BoxDecoration(border: Border(top: BorderSide(color: t.text.withValues(alpha: 0.10)))),
    child: child,
  );

  Widget _details(DeskmateTokens t, ClaudeUsage? c) {
    final days = c?.tokens7d ?? const <int>[];
    final today = days.isEmpty ? 0 : days.length - 1;
    final picked = (_day != null && _day! < days.length) ? _day! : today;
    DateTime dayDate(int i) => widget.now.subtract(Duration(days: today - i));
    final maxDay = days.isEmpty ? 1 : max(1, days.reduce(max));
    final waiting = c?.waiting ?? 0;
    final models = (c?.models ?? const <ModelShare>[]).take(3).toList();
    final colors = [t.clay, t.text, t.muted];

    final weekly = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _caps(t, 'Weekly limit')),
              if (c?.weeklyReset != null)
                Flexible(
                  child: Text(
                    _weeklyReset(c!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.ui(12, weight: 500, color: t.muted.withValues(alpha: 0.8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                c?.weeklyPct == null ? '—' : '${c!.weeklyPct!.round()}%',
                style: t.num(38, weight: 200, height: 1).copyWith(letterSpacing: -1.5),
              ),
              const SizedBox(width: 14),
              Expanded(child: _bar(t, (c?.weeklyPct ?? 0) / 100, t.text)),
            ],
          ),
        ],
      ),
    );

    final sessions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caps(t, 'Sessions'),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(c?.sessions?.toString() ?? '—', style: t.num(38, weight: 200, height: 1)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                waiting > 0 ? '$waiting waiting for you' : 'None waiting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.ui(13, weight: 500, color: waiting > 0 ? t.clay : t.muted),
              ),
            ),
          ],
        ),
      ],
    );

    final byModel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _caps(t, 'By model'),
        const SizedBox(height: 8),
        for (var i = 0; i < models.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 7),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text(models[i].name, maxLines: 1, style: t.ui(11, weight: 500))),
                const SizedBox(width: 10),
                Expanded(child: _bar(t, models[i].share, colors[i])),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(models[i].share * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: t.ui(11, weight: 500, color: t.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final tokens = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _caps(t, picked == today ? 'Tokens today' : 'Tokens · ${weekdayShort(dayDate(picked))}')),
            Text(compact(days.isEmpty ? null : days[picked]), style: t.ui(13, weight: 600)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == picked,
                    label: '${weekdayShort(dayDate(i))}: ${compact(days[i])} tokens',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _day = (i == picked || i == today) ? null : i),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: max(0.06, days[i] / maxDay),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: i == picked ? t.clay : t.text.withValues(alpha: 0.28),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                      bottom: Radius.circular(1),
                                    ),
                                  ),
                                  child: const SizedBox(width: double.infinity),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            weekdayLetter(dayDate(i)),
                            style: t.ui(10, weight: 500, color: i == picked ? t.text : t.muted),
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [weekly, _section(t, sessions), _section(t, byModel), _section(t, tokens, last: true)],
    );
  }
}
