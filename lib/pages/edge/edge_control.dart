import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../pages/control_page.dart' show btIcons;
import '../../theme/deskmate_tokens.dart';
import '../../ui/edge_widgets.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';

/// Edge · Control Center: the Mac's Bluetooth (the connected device, "My devices", "Nearby" to pair)
/// and the Mac's Wi-Fi. All of it runs on the Mac. It never turns the Mac's Bluetooth off.
class EdgeControl extends StatelessWidget {
  const EdgeControl({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EdgePageHeader(
            icon: DIcon.bluetooth,
            color: t.ok,
            title: 'Control Center',
            note: 'Mac connection · ${clockText(now, use24h)}',
          ),
          Expanded(
            // Laid out at the design's size; shorter or narrower screens scale it down.
            child: LayoutBuilder(
              builder:
                  (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: max(box.maxWidth, 859),
                      height: max(box.maxHeight, 300),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [Expanded(child: _Connected()), SizedBox(width: 40), _Devices()],
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

String _kindLabel(BtKind k) => switch (k) {
  BtKind.headphones => 'Headphones',
  BtKind.speaker => 'Speaker',
  BtKind.keyboard => 'Keyboard',
  BtKind.mouse => 'Mouse',
  BtKind.other => 'Bluetooth device',
};

/// The device in use, its Disconnect and Switch buttons, and the Wi-Fi switch.
class _Connected extends StatelessWidget {
  const _Connected();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final bt = link.board.bluetooth;
    final wifi = link.board.wifi;
    final active = bt?.active;
    final wifiOn = wifi?.on ?? false;

    BtDevice? switchTarget() {
      for (final d in bt?.paired ?? const <BtDevice>[]) {
        if (!d.connected && d.id != active?.id && (d.kind == BtKind.headphones || d.kind == BtKind.speaker)) return d;
      }
      return null;
    }

    final target = switchTarget();

    Widget pill(String label, {required bool filled, VoidCallback? onTap}) => Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? t.text : null,
              borderRadius: BorderRadius.circular(23),
              border: filled ? null : Border.all(color: t.text.withValues(alpha: 0.22)),
            ),
            child: Text(label, style: t.ui(14, weight: filled ? 600 : 500, color: filled ? t.bg : t.text)),
          ),
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: active == null ? t.muted : t.ok, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              bt == null ? 'Waiting for your Mac…' : (active == null ? 'Not connected' : 'Connected'),
              style: t.ui(12, color: active == null ? t.muted : t.ok),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.text.withValues(alpha: 0.16)),
              ),
              child: Center(
                child: DIconView(
                  active == null ? DIcon.bluetooth : btIcons[active.kind]!,
                  size: 34,
                  color: active == null ? t.muted : t.ok,
                  strokeWidth: 1.7,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active?.name ?? 'No device',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.num(42, weight: 300, height: 1.05),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active == null ? 'Nothing connected to your Mac' : _kindLabel(active.kind),
                    style: t.ui(14, color: t.textSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            if (active != null) ...[
              pill('Disconnect', filled: true, onTap: () => link.sendCommand('bt.disconnect:${active.id}')),
              const SizedBox(width: 10),
            ],
            pill(
              active == null ? 'Connect' : 'Switch device',
              filled: active == null,
              onTap: target == null ? null : () => link.sendCommand('bt.connect:${target.id}'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.hairline))),
          child: Row(
            children: [
              DIconView(DIcon.wifi, size: 22, color: wifiOn ? t.textSoft : t.muted, strokeWidth: 2),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EdgeLabel('Mac Wi-Fi', size: 11),
                    Text(
                      wifi == null ? '—' : (wifiOn ? (wifi.ssid ?? 'Connected') : 'Off'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.num(17, weight: 500),
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
                    width: 52,
                    height: 30,
                    padding: const EdgeInsets.all(3),
                    alignment: wifiOn ? Alignment.centerRight : Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: wifiOn ? t.clay : t.ringTrack,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: t.text, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "My devices" (Connect) and "Nearby" (Pair), scrolling when there are many.
class _Devices extends StatelessWidget {
  const _Devices();

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final bt = link.board.bluetooth;
    final mine = bt?.paired ?? const <BtDevice>[];
    final nearby = bt?.nearby ?? const <BtDevice>[];

    Widget row(BtDevice d, Widget trailing) => SizedBox(
      height: 46,
      child: Row(
        children: [
          DIconView(btIcons[d.kind]!, size: 20, color: t.textSoft, strokeWidth: 2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(14, weight: 500)),
                Text(
                  !d.paired ? 'Not paired' : (d.connected ? 'Connected' : 'Not connected'),
                  style: t.ui(11, color: t.muted),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );

    Widget textAction(String label, Color color, VoidCallback? onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Text(label, style: t.ui(12, color: color)),
      ),
    );

    return Container(
      width: 340,
      padding: const EdgeInsets.only(left: 30),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: t.hairline))),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          const EdgeLabel('My devices', size: 11, spacing: 2),
          const SizedBox(height: 6),
          if (bt == null) Text('Waiting for your Mac…', style: t.ui(12, color: t.muted)),
          for (final d in mine)
            row(
              d,
              d.connected
                  ? Text('On', style: t.ui(12, color: t.ok))
                  : textAction('Connect', t.text, () => link.sendCommand('bt.connect:${d.id}')),
            ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.hairline))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const EdgeLabel('Nearby', size: 11, spacing: 2),
                // Scanning briefly disturbs Bluetooth audio (earphones), so it only runs when asked.
                if (bt?.scanning ?? false)
                  Text('Searching…', style: t.ui(12, color: t.clay))
                else
                  textAction('Search', t.clay, () => link.sendCommand('bt.scan')),
              ],
            ),
          ),
          for (final d in nearby)
            row(
              d,
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => link.sendCommand('bt.pair:${d.id}'),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.clay, borderRadius: BorderRadius.circular(16)),
                  child: Text('Pair', style: t.ui(12, weight: 600, color: t.bg)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
