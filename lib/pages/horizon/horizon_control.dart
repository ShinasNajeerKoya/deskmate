import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/icons.dart';
import '../control_page.dart' show btIcons;

/// Horizon · Control Center: the Mac's Bluetooth (a large frosted card for the connected device, then My devices
/// and Nearby) and the Mac's Wi-Fi. It never turns the Mac's Bluetooth off.
class HorizonControl extends StatelessWidget {
  const HorizonControl({super.key});

  static String _kind(BtKind k) => switch (k) {
    BtKind.headphones => 'Headphones',
    BtKind.speaker => 'Speaker',
    BtKind.keyboard => 'Keyboard',
    BtKind.mouse => 'Mouse',
    BtKind.other => 'Bluetooth device',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 16, 34, 68),
      child: LayoutBuilder(
        builder:
            (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: max(box.maxWidth, 847),
                height: max(box.maxHeight, 300),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: _Left()), SizedBox(width: 32), SizedBox(width: 336, child: _Devices())],
                ),
              ),
            ),
      ),
    );
  }
}

Widget _caps(DeskmateTokens t, String s, {Color? color, double size = 11}) => Text(
  s.toUpperCase(),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: t.ui(size, weight: 600, color: color ?? t.muted).copyWith(letterSpacing: 2.4),
);

const _line = Color(0x14EAF0FF); // hairline
const _chipFill = Color(0x0DFFFFFF);
const _chipBorder = Color(0x1AFFFFFF);

class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.glow = false});

  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: glow ? [BoxShadow(color: color, blurRadius: 8)] : null,
    ),
  );
}

class _Left extends StatelessWidget {
  const _Left();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final bt = link.board.bluetooth;
    final wifi = link.board.wifi;
    final active = bt?.active;
    final wifiOn = wifi?.on ?? false;

    // The headphones or speaker to switch to (a paired one that isn't connected).
    BtDevice? target;
    for (final d in bt?.paired ?? const <BtDevice>[]) {
      if (!d.connected && d.id != active?.id && (d.kind == BtKind.headphones || d.kind == BtKind.speaker)) {
        target = d;
        break;
      }
    }

    Widget pill(String label, VoidCallback? onTap, {bool filled = false, double pad = 24}) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: pad),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? t.text : null,
              borderRadius: BorderRadius.circular(24),
              border: filled ? null : Border.all(color: const Color(0x2EFFFFFF)),
            ),
            child: Text(label, style: t.ui(14, weight: filled ? 600 : 500, color: filled ? t.bg : t.text)),
          ),
        ),
      ),
    );

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment(-0.5, -1),
          end: Alignment(0.5, 1),
          stops: [0, 0.65],
          colors: [Color(0x298EA2FF), Color(0x08FFFFFF)],
        ),
        border: Border.all(color: _chipBorder),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Dot(active == null ? t.muted : t.clay, glow: active != null),
              const SizedBox(width: 8),
              _caps(t, bt == null ? 'Waiting for your Mac…' : (active == null ? 'Not connected' : 'Connected')),
            ],
          ),
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x2EFFFFFF))),
                child: Center(
                  child: DIconView(
                    active == null ? DIcon.bluetooth : btIcons[active.kind]!,
                    size: 30,
                    color: t.text,
                    strokeWidth: 1.6,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      active?.name ?? 'No device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.num(44, weight: 200, height: 1, letterSpacing: -1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      active == null ? 'Nothing connected to your Mac' : HorizonControl._kind(active.kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.ui(14, color: t.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (active != null) ...[
                pill('Disconnect', () => link.sendCommand('bt.disconnect:${active.id}'), filled: true, pad: 26),
                const SizedBox(width: 10),
              ],
              pill(
                active == null ? 'Connect' : 'Switch device',
                target == null ? null : () => link.sendCommand('bt.connect:${target!.id}'),
                filled: active == null,
              ),
            ],
          ),
        ],
      ),
    );

    final wifiRow = Container(
      height: 76,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
      child: Row(
        children: [
          DIconView(DIcon.wifi, size: 22, color: wifiOn ? t.text : t.muted, strokeWidth: 1.7),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _caps(t, 'Mac Wi-Fi'),
                const SizedBox(height: 2),
                Text(
                  wifi == null ? '—' : (wifiOn ? (wifi.ssid ?? 'Connected') : 'Off'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(20),
                ),
              ],
            ),
          ),
          Semantics(
            toggled: wifiOn,
            label: 'Mac Wi-Fi',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: wifi == null ? null : () => link.sendCommand('wifi.power:${wifiOn ? 'off' : 'on'}'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 32,
                padding: const EdgeInsets.all(4),
                alignment: wifiOn ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: wifiOn ? t.clay : t.text.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: wifiOn ? t.bg : t.text, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // The card takes the spare height, so a taller page makes it taller.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: card), const SizedBox(height: 10), wifiRow],
    );
  }
}

class _Devices extends StatelessWidget {
  const _Devices();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final bt = link.board.bluetooth;
    final mine = bt?.paired ?? const <BtDevice>[];
    final nearby = bt?.nearby ?? const <BtDevice>[];

    Widget action(String label, VoidCallback onTap, {bool filled = false}) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? t.text : null,
            borderRadius: BorderRadius.circular(18),
            border: filled ? null : Border.all(color: const Color(0x29FFFFFF)),
          ),
          child: Text(label, style: t.ui(12, weight: 600, color: filled ? t.bg : t.text)),
        ),
      ),
    );

    Widget row(BtDevice d, Widget trailing) => Container(
      height: 54,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x14EAF0FF)))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _chipFill, border: Border.all(color: _chipBorder)),
            child: Center(child: DIconView(btIcons[d.kind]!, size: 18, color: t.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(14, weight: 500)),
                Text(
                  !d.paired ? 'Not paired' : (d.connected ? 'Connected' : 'Not connected'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(11, color: t.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _caps(t, 'My devices'),
        const SizedBox(height: 6),
        if (bt == null) Text('Waiting for your Mac…', style: t.ui(12, color: t.muted)),
        for (final d in mine)
          row(
            d,
            d.connected
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dot(t.clay),
                    const SizedBox(width: 6),
                    Text('On', style: t.ui(12, weight: 500, color: t.muted)),
                  ],
                )
                : action('Connect', () => link.sendCommand('bt.connect:${d.id}'), filled: true),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _caps(t, 'Nearby'),
              // Scanning briefly disturbs Bluetooth audio (earphones), so it only runs when asked.
              if (bt?.scanning ?? false)
                Text('Searching…', style: t.ui(11, weight: 600, color: t.clay).copyWith(letterSpacing: 1))
              else
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => link.sendCommand('bt.scan'),
                  child: Text('Search', style: t.ui(11, weight: 600, color: t.clay).copyWith(letterSpacing: 1)),
                ),
            ],
          ),
        ),
        for (final d in nearby) row(d, action('Pair', () => link.sendCommand('bt.pair:${d.id}'))),
      ],
    );
  }
}
