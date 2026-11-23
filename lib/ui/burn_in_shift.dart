import 'dart:async';

import 'package:flutter/widgets.dart';

/// OLED burn-in protection: slowly moves [child] around a small square, one step
/// every [interval], so static pixels (tiles, sidebar, clock) don't stay lit in
/// exactly the same place for hours. Does nothing harmful on LCD screens.
class BurnInShift extends StatefulWidget {
  const BurnInShift({super.key, required this.child, this.amplitude = 4, this.interval = const Duration(minutes: 3)});

  final Widget child;

  /// Largest shift in logical pixels, in each direction.
  final double amplitude;
  final Duration interval;

  /// The path: centre, then around the edges of the square.
  static const _path = [
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
    Offset(-1, 1),
    Offset(-1, 0),
    Offset(-1, -1),
    Offset(0, -1),
    Offset(1, -1),
  ];

  @override
  State<BurnInShift> createState() => _BurnInShiftState();
}

class _BurnInShiftState extends State<BurnInShift> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => setState(() => _step = (_step + 1) % BurnInShift._path.length));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = BurnInShift._path[_step] * widget.amplitude;
    return TweenAnimationBuilder<Offset>(
      tween: Tween(end: o),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Transform.translate(offset: value, child: child),
      child: widget.child,
    );
  }
}
