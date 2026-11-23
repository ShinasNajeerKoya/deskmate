import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons from the design canvas (24×24 line icons), drawn with the exact paths.
enum DIcon {
  home('<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>'),
  claude('<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>'),
  music('<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>'),
  system('<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>'),
  timer('<path d="M12 21a8 8 0 1 1 0-16 8 8 0 0 1 0 16zM12 9v4l2 2M10 2h4"/>'),
  calendar('<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>'),
  slack('<path d="M4 9h16M4 15h16M10 3 8 21M16 3l-2 18"/>'),
  weather(
    '<path d="M12 2v2M4.93 4.93l1.41 1.41M20 12h2M19.07 4.93l-1.41 1.41M15.95 12.65a4 4 0 0 0-5.93-4.13"/>'
    '<path d="M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6z"/>',
  ),
  shortcuts('<path d="M15 6v12a3 3 0 1 0 3-3H6a3 3 0 1 0 3 3V6a3 3 0 1 0-3 3h12a3 3 0 1 0-3-3"/>'),
  github(
    '<path d="M6 3v12"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M18 9a9 9 0 0 1-9 9"/>',
  ),
  settings(
    '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12"/>'
    '<circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
  ),
  bluetooth('<path d="m7 7 10 10-5 5V2l5 5L7 17"/>'),
  headphones(
    '<path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"/>',
  ),
  keyboard(
    '<path d="M4 6h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2zM6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8"/>',
  ),
  mouse('<path d="M12 2a7 7 0 0 1 7 7v6a7 7 0 0 1-14 0V9a7 7 0 0 1 7-7zM12 6v4"/>'),
  speaker(
    '<path d="M6 2h12a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zM12 6h.01M12 18a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"/>',
  ),
  wifi('<path d="M12 20h.01M2 8.82a15 15 0 0 1 20 0M5 12.86a10 10 0 0 1 14 0M8.5 16.43a5 5 0 0 1 7 0"/>'),
  code('<path d="m16 18 6-6-6-6M8 6l-6 6 6 6"/>'),
  terminal('<path d="m4 17 6-6-6-6M12 19h8"/>'),
  lock('<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>'),
  camera(
    '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3z"/>'
    '<circle cx="12" cy="13" r="3"/>',
  ),
  shuffle('<path d="M16 3h5v5M4 20 21 3M21 16v5h-5M15 15l6 6M4 4l5 5"/>'),
  volume('<path d="M11 5 6 9H2v6h4l5 4zM15.5 8.5a5 5 0 0 1 0 7"/>'),
  reset('<path d="M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5"/>'),
  // Filled glyphs
  previous('<path d="M19 20 9 12l10-8z" fill="currentColor"/><path d="M5 19V5"/>', filled: true),
  next('<path d="m5 4 10 8-10 8z" fill="currentColor"/><path d="M19 5v14"/>', filled: true),
  pause(
    '<rect x="6" y="5" width="4" height="14" rx="1" fill="currentColor" stroke="none"/>'
    '<rect x="14" y="5" width="4" height="14" rx="1" fill="currentColor" stroke="none"/>',
    filled: true,
  ),
  play('<path d="M7 4.5v15l12.5-7.5z" fill="currentColor"/>', filled: true),
  heart(
    '<path d="M12 21s-7.5-4.6-9.5-9.2C1.2 8.6 3.3 5 6.8 5c2 0 3.4 1.1 4.2 2.3h2C13.8 6.1 15.2 5 17.2 5c3.5 0 5.6 3.6 4.3 6.8C19.5 16.4 12 21 12 21z" fill="currentColor" stroke="none"/>',
    filled: true,
  ),
  heartOutline(
    '<path d="M12 21s-7.5-4.6-9.5-9.2C1.2 8.6 3.3 5 6.8 5c2 0 3.4 1.1 4.2 2.3h2C13.8 6.1 15.2 5 17.2 5c3.5 0 5.6 3.6 4.3 6.8C19.5 16.4 12 21 12 21z"/>',
  );

  const DIcon(this.body, {this.filled = false});
  final String body;
  final bool filled;
}

class DIconView extends StatelessWidget {
  const DIconView(this.icon, {super.key, this.size = 20, required this.color, this.strokeWidth});

  final DIcon icon;
  final double size;
  final Color color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final sw = strokeWidth ?? (icon.filled ? 1.6 : 2);
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="currentColor" stroke-width="$sw" stroke-linecap="round" stroke-linejoin="round">'
        '${icon.body}</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
      excludeFromSemantics: true,
    );
  }
}
