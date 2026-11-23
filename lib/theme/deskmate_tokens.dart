import 'package:flutter/material.dart';

/// The four planned themes. Only Color Blocks has tokens so far; the others
/// fall back to it until they're designed into tokens (phase 2).
enum ThemeId {
  graphite('Graphite', [
    Color(0xFF0B0C0E),
    Color(0xFF232429),
    Color(0xFFFF9A4D),
    Color(0xFF16171A),
    Color(0xFF16171A),
    Color(0xFF232429),
  ]),
  colorBlocks('Color Blocks', [
    Color(0xFF0F0F10),
    Color(0xFFF3EEE6),
    Color(0xFFE07A4F),
    Color(0xFF2A2440),
    Color(0xFFBFE3CC),
    Color(0xFFF2D16B),
  ]),
  paper('Paper', [
    Color(0xFFECE9E2),
    Color(0xFFFBFAF7),
    Color(0xFF1B1B1A),
    Color(0xFFFBFAF7),
    Color(0xFFFBFAF7),
    Color(0xFFE8572A),
  ]),
  paperBlocks('Paper Blocks', [
    Color(0xFFECE9E2),
    Color(0xFFFBFAF7),
    Color(0xFFE07A4F),
    Color(0xFF2A2440),
    Color(0xFFBFE3CC),
    Color(0xFFF2D16B),
  ]);

  const ThemeId(this.label, this.preview);
  final String label;

  /// Settings thumbnail colours: background, then five blocks (from the design's Settings board).
  final List<Color> preview;

  bool get available => this == ThemeId.colorBlocks;
}

/// Theme tokens. Widgets read every colour, font and radius from here and
/// never hard-code them, so other themes are just a different token set.
@immutable
class DeskmateTokens extends ThemeExtension<DeskmateTokens> {
  const DeskmateTokens({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.divider,
    required this.track,
    required this.text,
    required this.muted,
    required this.cream,
    required this.cream2,
    required this.creamInk,
    required this.creamMuted,
    required this.clay,
    required this.clayInk,
    required this.violet,
    required this.violet2,
    required this.lilac,
    required this.mint,
    required this.mintInk,
    required this.butter,
    required this.butterInk,
    required this.ok,
    required this.nightBg,
    required this.nightHour,
    required this.nightMinute,
    required this.nightDots,
    required this.nightLabel,
    required this.bannerConnecting,
    required this.bannerConnectingInk,
    required this.bannerReconnecting,
    required this.bannerReconnectingInk,
    required this.bannerError,
    required this.bannerErrorInk,
    required this.uiFont,
    required this.numFont,
    required this.radiusTileLarge,
    required this.radiusTile,
    required this.radiusButton,
    required this.radiusRail,
    required this.radiusDigit,
  });

  // Surfaces and text
  final Color bg, panel, panel2, divider, track, text, muted;
  // Colour blocks: fill + ink pairs
  final Color cream, cream2, creamInk, creamMuted;
  final Color clay, clayInk;
  final Color violet, violet2, lilac;
  final Color mint, mintInk;
  final Color butter, butterInk;
  final Color ok;
  // Night clock
  final Color nightBg, nightHour, nightMinute, nightDots, nightLabel;
  // Connection / battery banners
  final Color bannerConnecting, bannerConnectingInk;
  final Color bannerReconnecting, bannerReconnectingInk;
  final Color bannerError, bannerErrorInk;
  // Type
  final String uiFont, numFont;
  // Radii
  final double radiusTileLarge, radiusTile, radiusButton, radiusRail, radiusDigit;

  static const colorBlocks = DeskmateTokens(
    bg: Color(0xFF0F0F10),
    panel: Color(0xFF1A1A1D),
    panel2: Color(0xFF26262A),
    divider: Color(0xFF2E2E33),
    track: Color(0xFF3A3A40),
    text: Color(0xFFF3EEE6),
    muted: Color(0xFFA5A39E),
    cream: Color(0xFFF3EEE6),
    cream2: Color(0xFFE4DCCF),
    creamInk: Color(0xFF141414),
    creamMuted: Color(0xFF5F5C56),
    clay: Color(0xFFE07A4F),
    clayInk: Color(0xFF1A0F0A),
    violet: Color(0xFF2A2440),
    violet2: Color(0xFF3C3460),
    lilac: Color(0xFFC9BFF2),
    mint: Color(0xFFBFE3CC),
    mintInk: Color(0xFF10261A),
    butter: Color(0xFFF2D16B),
    butterInk: Color(0xFF2A2108),
    ok: Color(0xFF8FD6A8),
    nightBg: Color(0xFF000000),
    nightHour: Color(0xFF8C6A4E),
    nightMinute: Color(0xFF6E685E),
    nightDots: Color(0xFF3A2A1E),
    nightLabel: Color(0xFF8A8378),
    // Banner colours aren't in the locked design yet: orange = clay, blue and
    // red are placeholders picked to sit with the palette.
    bannerConnecting: Color(0xFFE07A4F),
    bannerConnectingInk: Color(0xFF1A0F0A),
    bannerReconnecting: Color(0xFF9CC3F0),
    bannerReconnectingInk: Color(0xFF0E1F33),
    bannerError: Color(0xFFF08A80),
    bannerErrorInk: Color(0xFF2B0D0A),
    uiFont: 'DM Sans',
    numFont: 'Bricolage Grotesque',
    radiusTileLarge: 24,
    radiusTile: 20,
    radiusButton: 16,
    radiusRail: 22,
    radiusDigit: 14,
  );

  static DeskmateTokens forTheme(ThemeId id) => colorBlocks;

  static DeskmateTokens of(BuildContext context) => Theme.of(context).extension<DeskmateTokens>()!;

  /// UI text (DM Sans).
  TextStyle ui(double size, {int weight = 400, Color? color, double? height}) => TextStyle(
    fontFamily: uiFont,
    fontSize: size,
    fontWeight: _weight(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
    color: color ?? text,
    height: height,
  );

  /// Numbers and clock (Bricolage Grotesque).
  TextStyle num(double size, {int weight = 700, Color? color, double? height, double? letterSpacing}) => TextStyle(
    fontFamily: numFont,
    fontSize: size,
    fontWeight: _weight(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
    color: color ?? text,
    height: height,
    letterSpacing: letterSpacing,
  );

  static FontWeight _weight(int w) => FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)];

  ThemeData toThemeData() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    fontFamily: uiFont,
    colorScheme: ColorScheme.dark(surface: panel, primary: clay, onPrimary: clayInk),
    splashFactory: InkRipple.splashFactory,
    extensions: [this],
  );

  @override
  DeskmateTokens copyWith() => this;

  @override
  DeskmateTokens lerp(DeskmateTokens? other, double t) => t < 0.5 ? this : (other ?? this);
}
