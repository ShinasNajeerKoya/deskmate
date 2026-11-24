import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/listening_tracker.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../../ui/paper_widgets.dart';
import '../../ui/swipe_art.dart';
import '../../ui/widgets.dart';

/// Paper · Music: the song with its controls (swipe the art to skip), and the queue with one previous and
/// three up next. The time you've been listening sits at the bottom of the queue.
class PaperMusic extends StatelessWidget {
  const PaperMusic({super.key, required this.use24h, required this.now, required this.listening});

  final bool use24h;
  final DateTime now;
  final ListeningTracker listening;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final m = link.board.music;
    final playing = m?.playing ?? false;
    final progress = (m == null || m.durationS == 0) ? 0.0 : m.positionS / m.durationS;
    final byline = [m?.artist, m?.album].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

    ArtImage art(String? id) => ArtImage(bytes: link.board.art[id], radius: 10, iconSize: 56, fit: BoxFit.fitWidth);

    final player = PaperCard(
      label: 'Now playing',
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: SwipeArt(
              onTap: () => link.sendCommand('music.toggle'),
              onNext: () => link.sendCommand('music.next'),
              onPrevious: () => link.sendCommand('music.previous'),
              songId: '${m?.title}|${m?.art}',
              current: art(m?.art),
              previous: art(m == null || m.previous.isEmpty ? null : m.previous.last.art),
              next: art(m == null || m.next.isEmpty ? null : m.next.first.art),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            // The same sizes and places as the Color Blocks Music page: three groups spread over the height
            // (status and song, the time bar, the controls); shorter screens scale it down a little.
            child: ShrinkToFit(
              minHeight: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: playing ? t.clay : t.muted, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(playing ? 'Now playing' : 'Paused', style: t.ui(12, color: t.muted)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        m?.title ?? 'Nothing playing',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(28, weight: 600, height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      Text(byline, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(15, color: t.muted)),
                    ],
                  ),
                  Column(
                    children: [
                      PaperBar(value: progress),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(mmss(m?.positionS ?? 0), style: t.num(12, weight: 500, color: t.muted)),
                          Text(mmss(m?.durationS ?? 0), style: t.num(12, weight: 500, color: t.muted)),
                        ],
                      ),
                    ],
                  ),
                  // Previous, play and next share one row; shuffle and like sit below it.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            PaperRoundButton(
                              icon: DIcon.previous,
                              label: 'Previous',
                              size: 62,
                              iconSize: 26,
                              onTap: () => link.sendCommand('music.previous'),
                            ),
                            const SizedBox(width: 14),
                            PaperRoundButton(
                              icon: playing ? DIcon.pause : DIcon.play,
                              label: playing ? 'Pause' : 'Play',
                              size: 80,
                              iconSize: 32,
                              filled: true,
                              onTap: () => link.sendCommand('music.toggle'),
                            ),
                            const SizedBox(width: 14),
                            PaperRoundButton(
                              icon: DIcon.next,
                              label: 'Next',
                              size: 62,
                              iconSize: 26,
                              onTap: () => link.sendCommand('music.next'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            PaperRoundButton(
                              icon: DIcon.shuffle,
                              label: 'Shuffle',
                              size: 56,
                              iconSize: 26,
                              color: (m?.shuffle ?? false) ? t.text : t.muted,
                              onTap: () => link.sendCommand('music.shuffle'),
                            ),
                            const SizedBox(width: 40),
                            PaperRoundButton(
                              icon: (m?.liked ?? false) ? DIcon.heart : DIcon.heartOutline,
                              label: 'Like',
                              size: 56,
                              iconSize: 26,
                              color: t.clay,
                              onTap: () => link.sendCommand('music.like'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final previous = (m?.previous ?? const <QueueItem>[]).reversed.take(1).toList();
    final next = (m?.next ?? const <QueueItem>[]).take(3).toList();
    Widget song(QueueItem q, {double opacity = 1}) => Opacity(
      opacity: opacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: q.index == null ? null : () => link.sendCommand('music.play:${q.index}'),
        child: Row(
          children: [
            SizedBox(width: 30, height: 30, child: ArtImage(bytes: link.board.art[q.art], radius: 5, iconSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(12, weight: 500)),
                  Text(q.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(10, color: t.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final current = listening.current, last = listening.last;
    final queue = PaperCard(
      label: 'Queue',
      fitHeight: 250,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PaperLabel('Previous', size: 10),
          const SizedBox(height: 8),
          if (previous.isEmpty)
            Text('—', style: t.ui(12, color: t.muted))
          else
            ...previous.map((q) => song(q, opacity: 0.55)),
          const SizedBox(height: 12),
          const PaperLabel('Up next', size: 10),
          const SizedBox(height: 8),
          if (next.isEmpty) Text('Nothing queued', style: t.ui(12, color: t.muted)),
          for (var i = 0; i < next.length; i++) ...[if (i > 0) const SizedBox(height: 8), song(next[i])],
          const Spacer(),
          if (current != null || last != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (last != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Earlier · ${last.inMinutes < 1 ? '<1m' : hm(last)}',
                        style: t.ui(10, color: t.muted),
                      ),
                    ),
                  if (current != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: playing ? t.clay : t.muted, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(stopwatch(current), style: t.num(13, weight: 600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return Column(
      children: [
        PaperHeader(title: 'Music', notes: [const PaperNote('YouTube Music'), PaperNote(clockText(now, use24h))]),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: player), const SizedBox(width: 8), SizedBox(width: 190, child: queue)],
          ),
        ),
      ],
    );
  }
}
