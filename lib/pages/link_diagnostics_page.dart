import 'package:flutter/material.dart';

import '../ble/mac_link.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/chrome.dart';

/// Link diagnostics: live CPU % plus reliability counters for the MIUI soak test.
/// Opened by long-pressing the "Mac" chip in the header.
class LinkDiagnosticsPage extends StatelessWidget {
  const LinkDiagnosticsPage({super.key, required this.link});

  final MacLink link;

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: link,
          builder:
              (context, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _cpuTile(context, t)),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _statsTile(t)),
                ],
              ),
        ),
      ),
    );
  }

  Widget _cpuTile(BuildContext context, DeskmateTokens t) {
    final (label, color) = switch (link.state) {
      LinkState.connected => ('Connected', linkColor(t, link.state)),
      LinkState.connecting => ('Connecting…', linkColor(t, link.state)),
      LinkState.scanning => ('Looking for your Mac…', linkColor(t, link.state)),
      LinkState.reconnecting => ('Reconnecting…', linkColor(t, link.state)),
      LinkState.bluetoothOff => ('Bluetooth is off', linkColor(t, link.state)),
    };
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(t.radiusTileLarge)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.arrow_back, color: t.text),
                tooltip: 'Back',
              ),
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: t.muted, fontSize: 16)),
            ],
          ),
          const Spacer(),
          Text('CPU', style: TextStyle(color: t.muted, fontSize: 20)),
          FittedBox(
            child: Text(
              link.board.system?.cpu == null ? '--' : '${link.board.system!.cpu!.toStringAsFixed(0)}%',
              style: TextStyle(color: t.clay, fontSize: 140, fontWeight: FontWeight.w700, height: 1),
            ),
          ),
          const Spacer(),
          if (link.state == LinkState.scanning)
            Text(
              'No luck? On Android 10/11, Location must be switched on for Bluetooth scanning.',
              style: TextStyle(color: t.muted, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _statsTile(DeskmateTokens t) {
    final up = DateTime.now().difference(link.startedAt);
    String dur(Duration d) =>
        d.inHours > 0 ? '${d.inHours}h ${d.inMinutes % 60}m' : '${d.inMinutes}m ${d.inSeconds % 60}s';
    final rows = {
      'App running': dur(up),
      'Packets': '${link.packets}',
      'Missed (seq gaps)': '${link.missed}',
      'Connects / drops': '${link.connects} / ${link.drops}',
      'Longest silence': '${link.longestSilence.inSeconds}s',
    };
    final label = TextStyle(color: t.muted, fontSize: 13);
    final value = TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(t.radiusTileLarge)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [Expanded(child: Text(e.key, style: label)), Text(e.value, style: value)]),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.panel2, borderRadius: BorderRadius.circular(t.radiusButton)),
              child: ListView(
                children: [
                  for (final e in link.events)
                    Text(e, style: TextStyle(color: t.muted, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
