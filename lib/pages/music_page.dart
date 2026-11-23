import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';

class MusicPage extends StatelessWidget {
  const MusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final m = link.board.music;
    final playing = m?.playing ?? false;

    final nowPlaying = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.violet, borderRadius: BorderRadius.circular(26)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(color: t.violet2, borderRadius: BorderRadius.circular(20)),
              child: Center(child: DIconView(DIcon.music, size: 60, color: t.lilac, strokeWidth: 1.3)),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: ShrinkToFit(
              minHeight: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Dot(color: playing ? t.clay : t.muted, size: 6),
                          const SizedBox(width: 6),
                          Text(playing ? 'Now playing' : 'Paused', style: t.ui(12, color: t.lilac)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        m?.title ?? 'Nothing playing',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.num(28, height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [m?.artist, m?.album].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.ui(15, color: t.lilac),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      ProgressLine(
                        value: (m == null || m.durationS == 0) ? 0 : m.positionS / m.durationS,
                        fill: t.cream,
                        track: t.violet2,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(mmss(m?.positionS ?? 0), style: t.ui(12, color: t.lilac)),
                          Text(mmss(m?.durationS ?? 0), style: t.ui(12, color: t.lilac)),
                        ],
                      ),
                    ],
                  ),
                  // The art takes most of the width, so the controls scale down to fit.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children:
                          [
                              IconBlockButton(
                                icon: DIcon.shuffle,
                                label: 'Shuffle',
                                background: (m?.shuffle ?? false) ? t.violet2 : Colors.transparent,
                                foreground: t.lilac,
                                iconSize: 20,
                                onTap: () => link.sendCommand('music.shuffle'),
                              ),
                              IconBlockButton(
                                icon: DIcon.previous,
                                label: 'Previous',
                                background: t.violet2,
                                foreground: t.cream,
                                width: 52,
                                height: 52,
                                iconSize: 20,
                                onTap: () => link.sendCommand('music.previous'),
                              ),
                              IconBlockButton(
                                icon: playing ? DIcon.pause : DIcon.play,
                                label: playing ? 'Pause' : 'Play',
                                background: t.cream,
                                foreground: t.violet,
                                width: 84,
                                height: 64,
                                radius: 22,
                                iconSize: 26,
                                onTap: () => link.sendCommand('music.toggle'),
                              ),
                              IconBlockButton(
                                icon: DIcon.next,
                                label: 'Next',
                                background: t.violet2,
                                foreground: t.cream,
                                width: 52,
                                height: 52,
                                iconSize: 20,
                                onTap: () => link.sendCommand('music.next'),
                              ),
                              IconBlockButton(
                                icon: (m?.liked ?? false) ? DIcon.heart : DIcon.heartOutline,
                                label: 'Like',
                                background: Colors.transparent,
                                foreground: t.clay,
                                iconSize: 20,
                                onTap: () => link.sendCommand('music.like'),
                              ),
                            ].expand((w) => [w, const SizedBox(width: 10)]).toList()
                            ..removeLast(),
                    ),
                  ),
                  Row(
                    children: [
                      DIconView(DIcon.volume, size: 18, color: t.lilac),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VolumeBar(
                          value: m?.volume ?? 0,
                          onChanged: (v) => link.sendCommand('music.volume:${v.toStringAsFixed(2)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final upNext = Container(
      width: 196,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Up next', style: t.ui(13, weight: 600)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: m?.queue.length ?? 0,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final q = m!.queue[i];
                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: t.panel2, borderRadius: BorderRadius.circular(10)),
                    ),
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
                );
              },
            ),
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: nowPlaying), const SizedBox(width: 8), upNext],
    );
  }
}

/// Volume line that can be dragged or tapped.
class _VolumeBar extends StatelessWidget {
  const _VolumeBar({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        void set(double dx) => onChanged((dx / box.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => set(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
          child: SizedBox(
            height: 24,
            child: Center(child: ProgressLine(value: value, fill: t.lilac, track: t.violet2)),
          ),
        );
      },
    );
  }
}
