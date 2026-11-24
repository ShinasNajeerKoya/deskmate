import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Album art: tap to play/pause, swipe left for next, right for previous.
/// The neighbouring songs' art slides in under the finger, so the next image is
/// already there. The command is sent on release without waiting for the computer.
class SwipeArt extends StatefulWidget {
  const SwipeArt({
    super.key,
    required this.songId,
    required this.current,
    required this.previous,
    required this.next,
    required this.onTap,
    required this.onNext,
    required this.onPrevious,
  });

  /// Changes when the song changes; the art then snaps back to the centre.
  final Object? songId;
  final Widget current, previous, next;
  final VoidCallback onTap, onNext, onPrevious;

  @override
  State<SwipeArt> createState() => SwipeArtState();
}

class SwipeArtState extends State<SwipeArt> {
  double _dx = 0;
  bool _animate = false;
  Timer? _fallback;

  @override
  void didUpdateWidget(SwipeArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId && _dx != 0) _reset(instant: true);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  void _reset({bool instant = false}) {
    _fallback?.cancel();
    setState(() {
      _animate = !instant;
      _dx = 0;
    });
  }

  void _end(DragEndDetails d, double w) {
    final v = d.primaryVelocity ?? 0;
    final go = _dx < -w * 0.2 || v < -500 ? 1 : (_dx > w * 0.2 || v > 500 ? -1 : 0);
    if (go == 0) return _reset();
    HapticFeedback.selectionClick();
    setState(() {
      _animate = true;
      _dx = -go * w;
    });
    go == 1 ? widget.onNext() : widget.onPrevious();
    // If the song doesn't change (end of queue, no computer), spring back.
    _fallback?.cancel();
    _fallback = Timer(const Duration(milliseconds: 1500), () => mounted ? _reset() : null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final dur = _animate ? const Duration(milliseconds: 180) : Duration.zero;
        Widget at(double x, Widget c) => AnimatedPositioned(
          duration: dur,
          curve: Curves.easeOutCubic,
          left: x,
          top: 0,
          width: w,
          height: box.maxHeight,
          child: c,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onHorizontalDragStart: (_) => _fallback?.cancel(),
          onHorizontalDragUpdate:
              (d) => setState(() {
                _animate = false;
                _dx = (_dx + d.delta.dx).clamp(-w, w);
              }),
          onHorizontalDragEnd: (d) => _end(d, w),
          onHorizontalDragCancel: _reset,
          child: ClipRect(
            child: Stack(
              children: [at(_dx - w - 8, widget.previous), at(_dx, widget.current), at(_dx + w + 8, widget.next)],
            ),
          ),
        );
      },
    );
  }
}
