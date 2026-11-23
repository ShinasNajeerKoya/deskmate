import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../data/models.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';

const btIcons = {
  BtKind.headphones: DIcon.headphones,
  BtKind.keyboard: DIcon.keyboard,
  BtKind.mouse: DIcon.mouse,
  BtKind.speaker: DIcon.speaker,
  BtKind.other: DIcon.bluetooth,
};

/// Control Center: the Mac's Bluetooth (connected device, paired devices,
/// nearby devices to pair) and Wi-Fi. It never turns the Mac's Bluetooth off,
/// since that would cut the phone's own link.
class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    final link = AppScope.of(context).link;
    final bt = link.board.bluetooth;
    final wifi = link.board.wifi;
    final active = bt?.active;

    BtDevice? switchTarget() {
      for (final d in bt?.paired ?? const <BtDevice>[]) {
        if (!d.connected && d.id != active?.id && (d.kind == BtKind.headphones || d.kind == BtKind.speaker)) return d;
      }
      return null;
    }

    Widget button(String label, Color bg, Color fg, VoidCallback? onTap, {int weight = 700}) => Material(
      color: bg,
      borderRadius: BorderRadius.circular(t.radiusButton),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Text(label, maxLines: 1, style: t.ui(15, weight: weight, color: fg)),
        ),
      ),
    );

    final connected = Tile(
      color: t.mint,
      radius: t.radiusTileLarge,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      label: 'Connected Bluetooth device',
      fitHeight: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              DIconView(DIcon.bluetooth, size: 18, color: t.mintInk, strokeWidth: 2.2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mac Bluetooth',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.ui(14, weight: 600, color: t.mintInk),
                ),
              ),
              Pill(
                color: t.mintInk.withValues(alpha: 0.12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Dot(color: t.mintInk),
                    const SizedBox(width: 6),
                    Text(
                      active == null ? 'Not connected' : 'Connected',
                      style: t.ui(12, weight: 600, color: t.mintInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: t.mintInk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: DIconView(
                    active == null ? DIcon.bluetooth : btIcons[active.kind]!,
                    size: 36,
                    color: t.mintInk,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active?.name ?? 'No device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.num(32, height: 1.05, color: t.mintInk),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      active == null ? 'Connect one from the list' : 'Connected to your Mac',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.ui(13, weight: 500, color: t.mintInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (active != null)
                button('Disconnect', t.mintInk, t.mint, () => link.sendCommand('bt.disconnect:${active.id}')),
              if (active != null && switchTarget() != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: button(
                    'Switch device',
                    t.mintInk.withValues(alpha: 0.12),
                    t.mintInk,
                    () => link.sendCommand('bt.connect:${switchTarget()!.id}'),
                    weight: 600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    final wifiOn = wifi?.on ?? false;
    final wifiCard = Tile(
      color: t.panel,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      label: 'Mac Wi-Fi',
      fitHeight: 48,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.panel2, borderRadius: BorderRadius.circular(14)),
            child: Center(child: DIconView(DIcon.wifi, size: 22, color: wifiOn ? t.text : t.muted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Mac Wi-Fi', style: t.ui(12, color: t.muted)),
                Text(
                  !wifiOn ? 'Off' : (wifi?.ssid ?? 'On'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.num(20, height: 1.2),
                ),
              ],
            ),
          ),
          Semantics(
            toggled: wifiOn,
            label: 'Mac Wi-Fi',
            child: GestureDetector(
              onTap: wifi == null ? null : () => link.sendCommand('wifi.power:${wifiOn ? 'off' : 'on'}'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 30,
                padding: const EdgeInsets.all(3),
                alignment: wifiOn ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(color: wifiOn ? t.clay : t.track, borderRadius: BorderRadius.circular(15)),
                child: Dot(color: t.cream, size: 24),
              ),
            ),
          ),
        ],
      ),
    );

    Widget smallButton(String label, Color bg, Color fg, VoidCallback onTap) => Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(label, style: t.ui(12, weight: 600, color: fg)),
        ),
      ),
    );

    Widget deviceRow(BtDevice d, Widget trailing) => SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: t.panel2, borderRadius: BorderRadius.circular(10)),
            child: Center(child: DIconView(btIcons[d.kind]!, size: 18, color: t.text)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.ui(13, weight: 500)),
                Text(
                  !d.paired ? 'Not paired' : (d.connected ? 'Connected' : 'Not connected'),
                  maxLines: 1,
                  style: t.ui(11, color: t.muted),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );

    Widget sectionHeader(String title, Widget note) => Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(children: [Expanded(child: Text(title, style: t.ui(13, weight: 600))), note]),
    );

    final mine = bt?.paired ?? const <BtDevice>[];
    final nearby = bt?.nearby ?? const <BtDevice>[];
    final list = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(22)),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          sectionHeader('My devices', Text('Paired with your Mac', style: t.ui(13, color: t.muted))),
          for (final d in mine)
            deviceRow(
              d,
              d.connected
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Dot(color: t.ok), const SizedBox(width: 5), Text('On', style: t.ui(12, color: t.muted))],
                  )
                  : smallButton('Connect', t.cream, t.creamInk, () => link.sendCommand('bt.connect:${d.id}')),
            ),
          if (bt == null) Text('Waiting for your Mac…', style: t.ui(12, color: t.muted)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Container(height: 1, color: t.divider)),
          sectionHeader(
            'Nearby',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Dot(color: (bt?.scanning ?? false) ? t.clay : t.muted),
                const SizedBox(width: 6),
                Text((bt?.scanning ?? false) ? 'Searching…' : 'Not searching', style: t.ui(13, color: t.muted)),
              ],
            ),
          ),
          for (final d in nearby)
            deviceRow(d, smallButton('Pair', t.clay, t.clayInk, () => link.sendCommand('bt.pair:${d.id}'))),
        ],
      ),
    );

    return BentoGrid(
      columns: 4,
      rows: 3,
      cells: [
        BentoCell(0, 0, connected, colSpan: 2, rowSpan: 2),
        BentoCell(0, 2, wifiCard, colSpan: 2),
        BentoCell(2, 0, list, colSpan: 2, rowSpan: 3),
      ],
    );
  }
}
