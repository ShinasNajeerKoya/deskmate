import 'package:flutter/material.dart';

import '../ble/mac_link.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/chrome.dart';
import '../ui/format.dart';
import '../ui/widgets.dart';

/// Dim clock shown while the Mac sleeps or the link is down. Tap to peek.
class NightClock extends StatelessWidget {
  const NightClock({
    super.key,
    required this.now,
    required this.use24h,
    required this.status,
    required this.battery,
    required this.onTap,
  });

  final DateTime now;
  final bool use24h;
  final String status;
  final int? battery;
  final VoidCallback onTap;

  static String statusFor(MacLink link) {
    if (link.macAsleep) return 'Computer asleep';
    return 'Computer not connected';
  }

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final (h, m) = clockDigits(now, use24h);
    final digits = t.num(220, height: 0.85, letterSpacing: -8);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: t.nightBg,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(h, style: digits.copyWith(color: t.nightHour)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [_square(t), const SizedBox(height: 34), _square(t)],
                            ),
                          ),
                          Text(m, style: digits.copyWith(color: t.nightMinute)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(shortDateCaps(now), style: t.ui(14, color: t.nightLabel).copyWith(letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                bottom: 18,
                child: Row(
                  children: [
                    Dot(color: t.nightLabel, size: 6),
                    const SizedBox(width: 6),
                    Text(status, style: t.ui(12, color: t.nightLabel)),
                  ],
                ),
              ),
              if (battery != null)
                Positioned(right: 24, bottom: 18, child: Text('$battery%', style: t.ui(12, color: t.nightLabel))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _square(DeskmateTokens t) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(color: t.nightDots, borderRadius: BorderRadius.circular(5)),
  );
}
