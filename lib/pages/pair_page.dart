import 'package:flutter/material.dart';

import '../ble/mac_link.dart';
import '../theme/deskmate_tokens.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';

/// Full-screen Wi-Fi pairing with its own number pad, so the system keyboard
/// never covers what you type (it takes most of a landscape screen).
class PairPage extends StatefulWidget {
  const PairPage({super.key, required this.link});

  final MacLink link;

  @override
  State<PairPage> createState() => _PairPageState();
}

enum _Field { code, ip }

class _PairPageState extends State<PairPage> {
  String _code = '';
  late String _ip = widget.link.wifiManualHost ?? '';
  _Field _field = _Field.code;
  bool _busy = false;
  String? _error;

  void _press(String key) {
    setState(() {
      _error = null;
      if (key == '⌫') {
        if (_field == _Field.code && _code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
        if (_field == _Field.ip && _ip.isNotEmpty) _ip = _ip.substring(0, _ip.length - 1);
        return;
      }
      if (_field == _Field.code) {
        if (key == '.' || _code.length >= 6) return;
        _code += key;
      } else if (_ip.length < 15) {
        _ip += key;
      }
    });
  }

  Future<void> _pair() async {
    if (_code.length != 6) return setState(() => _error = 'Type all 6 digits of the code from the Deskmate Hub menu.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.link.pairWifi(_code, host: _ip.trim().isEmpty ? null : _ip.trim());
    if (!mounted) return;
    if (error == null) return Navigator.of(context).pop();
    setState(() {
      _busy = false;
      _error = error;
      _code = '';
      _field = _Field.code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = DeskmateTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListenableBuilder(
            listenable: widget.link,
            builder: (context, _) => widget.link.wifiPaired ? _paired(t) : _pairing(t),
          ),
        ),
      ),
    );
  }

  Widget _back(DeskmateTokens t) => IconBlockButton(
    icon: DIcon.previous,
    label: 'Back',
    background: t.panel,
    foreground: t.text,
    iconSize: 14,
    onTap: () => Navigator.of(context).pop(),
  );

  Widget _paired(DeskmateTokens t) {
    final link = widget.link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [_back(t), const SizedBox(width: 12), Text('Wi-Fi link', style: t.ui(18, weight: 600))]),
        const Spacer(),
        Row(
          children: [
            Dot(color: link.wifiActive ? t.ok : t.bannerConnecting, size: 12),
            const SizedBox(width: 10),
            Text(
              link.wifiActive
                  ? 'Connected to ${link.wifiHubName ?? 'your computer'} over Wi-Fi'
                  : 'Paired with ${link.wifiHubName ?? 'your computer'} · waiting for it on Wi-Fi',
              style: t.ui(18, weight: 600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Everything between the phone and the computer is encrypted.', style: t.ui(14, color: t.muted)),
        const Spacer(),
        Row(
          children: [
            _button(t, 'Forget this computer', t.panel2, t.bannerError, () async {
              await link.forgetWifi();
            }),
            const SizedBox(width: 12),
            _button(t, 'Done', t.clay, t.clayInk, () => Navigator.of(context).pop()),
          ],
        ),
      ],
    );
  }

  Widget _pairing(DeskmateTokens t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _back(t),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Pair with your computer', style: t.ui(18, weight: 600))),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _step(t, '1', 'On the computer, click the Deskmate Hub icon → "Pair a phone over Wi-Fi…".'),
                      _step(t, '2', 'Type the 6-digit code it shows (valid for 2 minutes).'),
                      _step(
                        t,
                        '3',
                        'Only if pairing can\'t find the computer: tap the IP box and type the IP from the same menu.',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: t.ui(14, weight: 600, color: t.bannerError)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // What you typed
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pairing code', style: t.ui(13, weight: 600, color: t.muted)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _field = _Field.code),
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i == 3) const SizedBox(width: 12),
                      if (i > 0 && i != 3) const SizedBox(width: 6),
                      Expanded(child: _digit(t, i)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Computer IP (optional)', style: t.ui(13, weight: 600, color: t.muted)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _field = _Field.ip),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: t.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _field == _Field.ip ? t.clay : Colors.transparent, width: 2),
                  ),
                  child: Text(
                    _ip.isEmpty ? 'e.g. 10.14.0.66' : _ip,
                    style: _ip.isEmpty ? t.ui(18, color: t.muted) : t.num(22),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Number pad
        SizedBox(width: 260, child: _keypad(t)),
      ],
    );
  }

  Widget _step(DeskmateTokens t, String n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.panel2, shape: BoxShape.circle),
          child: Text(n, style: t.ui(12, weight: 700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: t.ui(14, color: t.muted))),
      ],
    ),
  );

  Widget _digit(DeskmateTokens t, int i) {
    final filled = i < _code.length;
    final active = _field == _Field.code && i == _code.length;
    return AspectRatio(
      aspectRatio: 0.8,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? t.cream : t.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? t.clay : Colors.transparent, width: 2),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(filled ? _code[i] : '', style: t.num(34, color: t.creamInk)),
          ),
        ),
      ),
    );
  }

  Widget _keypad(DeskmateTokens t) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return Column(
      children: [
        Expanded(
          child: BentoGrid(
            columns: 3,
            rows: 4,
            gap: 6,
            cells: [
              for (var i = 0; i < keys.length; i++)
                BentoCell(i % 3, i ~/ 3, _key(t, keys[i], enabled: !(keys[i] == '.' && _field == _Field.code))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: _button(
            t,
            _busy ? 'Pairing…' : 'Pair',
            _code.length == 6 && !_busy ? t.clay : t.panel2,
            _code.length == 6 && !_busy ? t.clayInk : t.muted,
            _busy ? null : _pair,
          ),
        ),
      ],
    );
  }

  Widget _key(DeskmateTokens t, String key, {required bool enabled}) => Material(
    color: t.panel,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: enabled && !_busy ? () => _press(key) : null,
      child: Center(
        child: Text(key, style: key == '⌫' ? t.ui(20, color: t.text) : t.num(22, color: enabled ? t.text : t.track)),
      ),
    ),
  );

  Widget _button(DeskmateTokens t, String label, Color bg, Color fg, VoidCallback? onTap) => Material(
    color: bg,
    borderRadius: BorderRadius.circular(t.radiusButton),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        child: Text(label, style: t.ui(16, weight: 700, color: fg)),
      ),
    ),
  );
}
