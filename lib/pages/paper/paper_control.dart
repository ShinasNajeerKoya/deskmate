import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../theme/deskmate_tokens.dart';
import '../../ui/format.dart';
import '../../ui/icons.dart';
import '../../ui/paper_widgets.dart';
import '../control_page.dart' show btIcons;

/// Paper · Control Center: the Mac's Bluetooth (the connected device on a dark card, My devices, Nearby)
/// and the Mac's Wi-Fi. It never turns the Mac's Bluetooth off.
class PaperControl extends StatelessWidget {
  const PaperControl({super.key, required this.now, required this.use24h});

  final DateTime now;
  final bool use24h;

  static String _kind(BtKind k) => switch (k) {
    BtKind.headphones => 'Headphones',
    BtKind.speaker => 'Speaker',
    BtKind.keyboard => 'Keyboard',
    BtKind.mouse => 'Mouse',
    BtKind.other => 'Bluetooth device',
  };

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final bt = link.board.bluetooth;
    final wifi = link.board.wifi;
    final active = bt?.active;
    final wifiOn = wifi?.on ?? false;

    BtDevice? target;
    for (final d in bt?.paired ?? const <BtDevice>[]) {
      if (!d.connected && d.id != active?.id && (d.kind == BtKind.headphones || d.kind == BtKind.speaker)) {
        target = d;
        break;
      }
    }

    final connected = PaperCard(
      ink: true,
      label: 'Connected device',
      fitHeight: 190,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: active == null ? t.inkMuted : t.ok, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              PaperLabel(
                bt == null ? 'Waiting for your Mac…' : (active == null ? 'Not connected' : 'Connected'),
                color: t.inkMuted,
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.onInk.withValues(alpha: 0.25)),
                ),
                child: Center(
                  child: DIconView(
                    active == null ? DIcon.bluetooth : btIcons[active.kind]!,
                    size: 28,
                    color: t.onInk,
                    strokeWidth: 1.7,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      active?.name ?? 'No device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.ui(30, weight: 600, color: t.onInk),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active == null ? 'Nothing connected to your Mac' : _kind(active.kind),
                      style: t.ui(13, color: t.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (active != null) ...[
                PaperPillButton(
                  label: 'Disconnect',
                  dark: true,
                  onTap: () => link.sendCommand('bt.disconnect:${active.id}'),
                ),
                const SizedBox(width: 10),
              ],
              PaperPillButton(
                label: active == null ? 'Connect' : 'Switch device',
                dark: true,
                filled: active == null,
                onTap: target == null ? null : () => link.sendCommand('bt.connect:${target!.id}'),
              ),
            ],
          ),
        ],
      ),
    );

    final wifiCard = PaperCard(
      label: 'Mac Wi-Fi',
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          DIconView(DIcon.wifi, size: 22, color: wifiOn ? t.text : t.muted, strokeWidth: 2),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PaperLabel('Mac Wi-Fi'),
                const SizedBox(height: 2),
                Text(
                  wifi == null ? '—' : (wifiOn ? (wifi.ssid ?? 'Connected') : 'Off'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(16, weight: 600),
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
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: wifiOn ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(color: wifiOn ? t.clay : t.border, borderRadius: BorderRadius.circular(14)),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: t.panel, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final mine = bt?.paired ?? const <BtDevice>[];
    final nearby = bt?.nearby ?? const <BtDevice>[];
    Widget row(BtDevice d, Widget trailing) => SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(10)),
            child: Center(child: DIconView(btIcons[d.kind]!, size: 18, color: t.text)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 500)),
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
    Widget small(String label, Color bg, Color fg, VoidCallback onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: t.ui(11, weight: 600, color: fg)),
      ),
    );

    final devices = PaperCard(
      label: 'Devices',
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PaperLabel('My devices'),
          const SizedBox(height: 4),
          if (bt == null) Text('Waiting for your Mac…', style: t.ui(12, color: t.muted)),
          for (final d in mine)
            row(
              d,
              d.connected
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('On', style: t.ui(12, color: t.muted)),
                    ],
                  )
                  : small('Connect', t.ink, t.onInk, () => link.sendCommand('bt.connect:${d.id}')),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const PaperLabel('Nearby'),
                // Scanning briefly disturbs Bluetooth audio (earphones), so it only runs when asked.
                if (bt?.scanning ?? false)
                  Text('SEARCHING…', style: t.num(11, weight: 500, color: t.clay, letterSpacing: 1))
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => link.sendCommand('bt.scan'),
                    child: Text('SEARCH', style: t.num(11, weight: 600, color: t.clay, letterSpacing: 1)),
                  ),
              ],
            ),
          ),
          for (final d in nearby) row(d, small('Pair', t.clay, t.onInk, () => link.sendCommand('bt.pair:${d.id}'))),
        ],
      ),
    );

    return Column(
      children: [
        PaperHeader(
          title: 'Control Center',
          notes: [const PaperNote('Mac connection'), PaperNote(clockText(now, use24h))],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: connected),
                    const SizedBox(height: 8),
                    SizedBox(height: 76, child: wifiCard),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 330, child: devices),
            ],
          ),
        ),
      ],
    );
  }
}
