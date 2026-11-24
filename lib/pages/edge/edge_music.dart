import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/listening_tracker.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/edge_widgets.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../../ui/swipe_art.dart';
import '../../ui/widgets.dart';

/// Edge · Music: big art, the song and its controls in the middle, and the queue on the right
/// (1 previous track, dimmed, and 3 up next; tap one to play it).
class EdgeMusic extends StatelessWidget {
  const EdgeMusic({super.key, required this.now, required this.use24h, required this.listening});

  final DateTime now;
  final bool use24h;
  final ListeningTracker listening;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EdgePageHeader(
            icon: DIcon.music,
            color: t.accentViolet,
            title: 'Music',
            note: 'YouTube Music · ${clockText(now, use24h)}',
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const _Art(),
                          const SizedBox(width: 32),
                          Expanded(child: _Player(listening: listening)),
                          const SizedBox(width: 32),
                          _Queue(listening: listening),
                        ],
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

class _Art extends StatelessWidget {
  const _Art();

  @override
  Widget build(BuildContext context) {
    final link = AppScope.of(context).link;
    final m = link.board.music;
    ArtImage art(String? id) => ArtImage(bytes: link.board.art[id], radius: 22, iconSize: 60, fit: BoxFit.fitWidth);
    return SizedBox(
      width: 280,
      height: 280,
      // Swipe the cover to skip: left for next, right for previous.
      child: SwipeArt(
        onTap: () => link.sendCommand('music.toggle'),
        onNext: () => link.sendCommand('music.next'),
        onPrevious: () => link.sendCommand('music.previous'),
        songId: '${m?.title}|${m?.art}',
        current: art(m?.art),
        previous: art(m == null || m.previous.isEmpty ? null : m.previous.last.art),
        next: art(m == null || m.next.isEmpty ? null : m.next.first.art),
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({required this.listening});

  final ListeningTracker listening;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final m = link.board.music;
    final playing = m?.playing ?? false;
    final progress = (m == null || m.durationS == 0) ? 0.0 : m.positionS / m.durationS;
    final byline = [m?.artist, m?.album].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    Widget button(DIcon icon, String label, String command, {double size = 52, double glyph = 26, Color? color}) =>
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => link.sendCommand(command),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: DIconView(icon, size: glyph, color: color ?? t.text)),
            ),
          ),
        );

    return SizedBox(
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [EdgeLabel(playing ? 'Now playing' : 'Paused', color: t.clay, size: 11, spacing: 2)]),
              const SizedBox(height: 8),
              Text(
                m?.title ?? 'Nothing playing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.num(40, weight: 300, height: 1.1),
              ),
              if (byline.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(byline, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(15, color: t.textSoft)),
                ),
            ],
          ),
          Column(
            children: [
              EdgeProgress(value: progress, height: 4, knob: 14),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(mmss(m?.positionS ?? 0), style: t.ui(11, color: t.muted)),
                  Text(mmss(m?.durationS ?? 0), style: t.ui(11, color: t.muted)),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              button(
                DIcon.shuffle,
                'Shuffle',
                'music.shuffle',
                size: 44,
                glyph: 20,
                color: (m?.shuffle ?? false) ? t.text : t.muted,
              ),
              button(DIcon.previous, 'Previous', 'music.previous'),
              Semantics(
                button: true,
                label: playing ? 'Pause' : 'Play',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => link.sendCommand('music.toggle'),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(color: t.text, shape: BoxShape.circle),
                    child: Center(child: DIconView(playing ? DIcon.pause : DIcon.play, size: 28, color: t.bg)),
                  ),
                ),
              ),
              button(DIcon.next, 'Next', 'music.next'),
              button(
                (m?.liked ?? false) ? DIcon.heart : DIcon.heartOutline,
                'Like',
                'music.like',
                size: 44,
                glyph: 22,
                color: t.clay,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.listening});

  final ListeningTracker listening;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final m = link.board.music;
    final previous = (m?.previous ?? const <QueueItem>[]).reversed.take(1).toList();
    final next = (m?.next ?? const <QueueItem>[]).take(3).toList();

    Widget song(QueueItem q, {double opacity = 1}) => Opacity(
      opacity: opacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: q.index == null ? null : () => link.sendCommand('music.play:${q.index}'),
        child: Row(
          children: [
            SizedBox(width: 36, height: 36, child: ArtImage(bytes: link.board.art[q.art], radius: 8, iconSize: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 500)),
                  Text(q.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(11, color: t.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      width: 190,
      height: 280,
      padding: const EdgeInsets.only(left: 22),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: t.hairline))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EdgeLabel('Previous', size: 11, spacing: 2),
          const SizedBox(height: 10),
          if (previous.isEmpty)
            Text('—', style: t.ui(12, color: t.muted))
          else
            for (final q in previous) song(q, opacity: 0.6),
          const SizedBox(height: 12),
          const EdgeLabel('Up next', size: 11, spacing: 2),
          const SizedBox(height: 10),
          if (next.isEmpty) Text('Nothing queued', style: t.ui(12, color: t.muted)),
          for (var i = 0; i < next.length; i++) ...[if (i > 0) const SizedBox(height: 10), song(next[i])],
          const Spacer(),
          _Listening(listening: listening, playing: m?.playing ?? false),
        ],
      ),
    );
  }
}

/// How long you've been listening, bottom right: the running time in one go (a pause over
/// 5 minutes starts a new one) and, small above it, how long the last stretch was.
class _Listening extends StatelessWidget {
  const _Listening({required this.listening, required this.playing});

  final ListeningTracker listening;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final current = listening.current, last = listening.last;
    if (current == null && last == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text('Earlier · ${last.inMinutes < 1 ? '<1m' : hm(last)}', style: t.ui(11, color: t.muted)),
            ),
          if (current != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: t.ringTrack, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Dot(color: playing ? t.clay : t.muted, size: 6),
                  const SizedBox(width: 8),
                  Text(stopwatch(current), style: t.ui(13, weight: 600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
