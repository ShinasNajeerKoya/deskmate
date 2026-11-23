import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../ble/mac_link.dart';
import '../theme/deskmate_tokens.dart';
import 'format.dart';
import 'widgets.dart';

Color linkColor(DeskmateTokens t, LinkState s) => switch (s) {
  LinkState.connected => t.ok,
  LinkState.notPaired || LinkState.scanning || LinkState.connecting => t.bannerConnecting,
  LinkState.reconnecting => t.bannerReconnecting,
};

/// Top row: title on the left, Mac + battery/time chips on the right.
/// Long-press the Mac chip to open link diagnostics.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.trailing,
    required this.onMacLongPress,
    this.titleSize = 16,
  });

  final String title, trailing;
  final double titleSize;
  final VoidCallback onMacLongPress;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final chipText = t.ui(12, color: t.muted);
    return SizedBox(
      height: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(titleSize, weight: 600)),
            ),
            GestureDetector(
              onLongPress: onMacLongPress,
              child: Pill(
                color: t.panel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Dot(color: linkColor(t, link.state)),
                    const SizedBox(width: 5),
                    Text('Mac', style: chipText),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Pill(color: t.panel, child: Text(trailing, style: chipText)),
          ],
        ),
      ),
    );
  }
}

/// Slim coloured banner (connection state on Home, battery warnings everywhere).
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, required this.color, required this.ink, this.onTap, this.onClose});

  final String text;
  final Color color, ink;
  final VoidCallback? onTap;

  /// Shows an × that closes the banner.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Dot(color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 600, color: ink)),
            ),
            if (onTap != null) Text('›', style: t.ui(16, weight: 600, color: ink)),
            if (onClose != null)
              Semantics(
                button: true,
                label: 'Close',
                child: GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  // A bigger touch area than the × itself.
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
                    child: Text('×', style: t.ui(20, weight: 600, color: ink, height: 1)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Connection banner for Home, or null when connected. [onPair] opens Settings.
Widget? connectionBanner(DeskmateTokens t, LinkState s, {VoidCallback? onPair}) => switch (s) {
  LinkState.connected => null,
  LinkState.notPaired => InfoBanner(
    text: 'Pair with your computer: Settings → Wi-Fi link',
    color: t.bannerConnecting,
    ink: t.bannerConnectingInk,
    onTap: onPair,
  ),
  LinkState.scanning || LinkState.connecting => InfoBanner(
    text: 'Looking for your computer on Wi-Fi…',
    color: t.bannerConnecting,
    ink: t.bannerConnectingInk,
  ),
  LinkState.reconnecting => InfoBanner(
    text: 'Reconnecting to your computer…',
    color: t.bannerReconnecting,
    ink: t.bannerReconnectingInk,
  ),
};

/// Closing the unplug banner at [level] hides it until the next 10% step:
/// 74 → back at 80, 83 → back at 90, 95 → back at 100 (which can't be closed).
int unplugSnoozeUntil(int level) => ((level ~/ 10) + 1) * 10;

/// Battery warning for every page, or null.
/// The "unplug" banner can be closed (until the next 10% step, see [unplugSnoozeUntil])
/// except at 100%, where it stays until the charger is unplugged.
Widget? batteryBanner(
  DeskmateTokens t,
  int? level,
  bool charging,
  int low,
  int high, {
  int? snoozedUntil,
  VoidCallback? onClose,
}) {
  if (level == null) return null;
  if (charging && level >= high) {
    if (level < 100 && snoozedUntil != null && level < snoozedUntil) return null;
    return InfoBanner(
      text: 'Battery at $level%. Unplug the charger.',
      color: t.butter,
      ink: t.butterInk,
      onClose: level < 100 ? onClose : null,
    );
  }
  if (!charging && level <= low) {
    return InfoBanner(text: 'Battery at $level%. Plug in the charger.', color: t.butter, ink: t.butterInk);
  }
  return null;
}

/// One split card of the flip clock. Flips when the digit changes.
class FlipDigit extends StatelessWidget {
  const FlipDigit({
    super.key,
    required this.digit,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.card,
    required this.ink,
    required this.seam,
    required this.radius,
  });

  final String digit;
  final double width, height, fontSize, radius;
  final Color card, ink, seam;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder:
                (child, anim) => AnimatedBuilder(
                  animation: anim,
                  child: child,
                  builder:
                      (context, child) => Transform(
                        alignment: Alignment.center,
                        transform:
                            Matrix4.identity()
                              ..setEntry(3, 2, 0.003)
                              ..rotateX((1 - anim.value) * pi / 2),
                        child: child,
                      ),
                ),
            child: Text(digit, key: ValueKey(digit), style: t.num(fontSize, height: 1, color: ink)),
          ),
          Positioned(left: 0, right: 0, top: height / 2 - 1, child: Container(height: 2, color: seam)),
        ],
      ),
    );
  }
}

/// "10:42" as split flip cards on a cream tile (Home clock, Timer).
class FlipClock extends StatelessWidget {
  const FlipClock({
    super.key,
    required this.left,
    required this.right,
    this.digitWidth = 74,
    this.digitHeight = 108,
    this.fontSize = 84,
    this.dotColor,
    this.dotSize = 9,
  });

  final String left, right; // two characters each
  final double digitWidth, digitHeight, fontSize, dotSize;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    Widget digit(String d) => FlipDigit(
      digit: d,
      width: digitWidth,
      height: digitHeight,
      fontSize: fontSize,
      card: t.cream2,
      ink: t.creamInk,
      seam: t.cream,
      radius: t.radiusDigit,
    );
    Widget pair(String s) =>
        Row(mainAxisSize: MainAxisSize.min, children: [digit(s[0]), const SizedBox(width: 6), digit(s[1])]);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pair(left),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Dot(color: dotColor ?? t.creamInk, size: dotSize),
              SizedBox(height: dotSize * 1.8),
              Dot(color: dotColor ?? t.creamInk, size: dotSize),
            ],
          ),
          const SizedBox(width: 12),
          pair(right),
        ],
      ),
    );
  }
}

/// Clock digits for "now" in the user's format.
(String, String) clockDigits(DateTime now, bool use24h) => (two(displayHour(now, use24h)), two(now.minute));
