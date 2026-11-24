import 'package:flutter/material.dart';

/// How pages are switched. A property of the theme, never both at once.
enum NavStyle { swipeDots, sidebar }

/// The four themes. Edge and Color Blocks have tokens; Edge isn't selectable until its
/// shell and screens are built. The others fall back to Color Blocks (phase 2).
enum ThemeId {
  edge('Edge', [
    Color(0xFF07090D),
    Color(0xFFE07A4F),
    Color(0xFFF2D16B),
    Color(0xFF4FD1C5),
    Color(0xFFA58BFF),
    Color(0xFF5ED3A4),
  ], NavStyle.swipeDots),
  colorBlocks('Color Blocks', [
    Color(0xFF0F0F10),
    Color(0xFFF3EEE6),
    Color(0xFFE07A4F),
    Color(0xFF2A2440),
    Color(0xFFBFE3CC),
    Color(0xFFF2D16B),
  ], NavStyle.sidebar),
  paper('Paper', [
    Color(0xFFECE9E2),
    Color(0xFFFBFAF7),
    Color(0xFF1B1B1A),
    Color(0xFFFBFAF7),
    Color(0xFFFBFAF7),
    Color(0xFFE8572A),
  ], NavStyle.sidebar),
  paperBlocks('Paper Blocks', [
    Color(0xFFECE9E2),
    Color(0xFFFBFAF7),
    Color(0xFFE07A4F),
    Color(0xFF2A2440),
    Color(0xFFBFE3CC),
    Color(0xFFF2D16B),
  ], NavStyle.sidebar);

  const ThemeId(this.label, this.preview, this.navigation);
  final String label;

  /// Edge swipes between tabs with page dots; the others keep the sidebar.
  final NavStyle navigation;

  /// The theme used on a fresh install. Edge becomes the default (flip this) once its
  /// shell and screens ship; until then it stays Color Blocks.
  static const defaultTheme = colorBlocks;

  /// Settings migration: a saved Graphite theme (removed) becomes Edge; unknown or missing
  /// names give [defaultTheme]. The caller still checks [available].
  static ThemeId fromSaved(String? name) {
    if (name == 'graphite') return edge;
    return values.asNameMap()[name] ?? defaultTheme;
  }

  /// Settings thumbnail colours: background, then five blocks (from the design's Settings board).
  final List<Color> preview;

  /// Edge is selectable as a preview: its shell works, its screens are still being built.
  bool get available => this == ThemeId.colorBlocks || this == ThemeId.edge || this == ThemeId.paper;
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
    required this.textSoft,
    required this.hairline,
    required this.ringTrack,
    required this.amber,
    required this.teal,
    required this.blue,
    required this.accentViolet,
    required this.glowTeal,
    required this.glowViolet,
    required this.glowClay,
    required this.glowPurple,
    required this.glowMint,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.onInk,
    required this.inkMuted,
    required this.railActive,
    required this.railActiveInk,
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
  // Edge: soft text, hairline dividers, ring tracks, accents and the background glows.
  // Color Blocks fills these from its own palette; its pages don't read them.
  final Color textSoft, hairline, ringTrack;
  final Color amber, teal, blue, accentViolet;
  // Background glow colours (opaque; each page picks its own strength and position, see EdgeGlow).
  final Color glowTeal, glowViolet, glowClay, glowPurple, glowMint;
  // Paper: the thin border of a card, and the dark "ink" cards (Claude, Timer, Home clock band) with their text.
  final Color border, ink, ink2, onInk, inkMuted;
  // The sidebar's page in use: its fill and its icon and text.
  final Color railActive, railActiveInk;

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
    textSoft: Color(0xFFA5A39E),
    hairline: Color(0xFF2E2E33),
    ringTrack: Color(0xFF3A3A40),
    amber: Color(0xFFF2D16B),
    teal: Color(0xFFBFE3CC),
    blue: Color(0xFFC9BFF2),
    accentViolet: Color(0xFFC9BFF2),
    glowTeal: Color(0xFF2C8C96),
    glowViolet: Color(0xFF7850C8),
    glowClay: Color(0xFFE07A4F),
    glowPurple: Color(0xFF7A4DD8),
    glowMint: Color(0xFF5ED3A4),
    border: Color(0x00000000),
    ink: Color(0xFF141414),
    ink2: Color(0xFF26262A),
    onInk: Color(0xFFF3EEE6),
    inkMuted: Color(0xFFA5A39E),
    railActive: Color(0xFFF3EEE6),
    railActiveInk: Color(0xFF141414),
  );

  /// Paper: warm paper, off-white cards with a thin border, a dark ink card, Geist and Geist Mono.
  static const paper = DeskmateTokens(
    bg: Color(0xFFECE9E2),
    panel: Color(0xFFFBFAF7),
    panel2: Color(0xFFECE9E2),
    divider: Color(0xFFDDD8CE),
    track: Color(0xFFDDD8CE),
    text: Color(0xFF1B1B1A),
    muted: Color(0xFF5F5C56),
    cream: Color(0xFFFBFAF7),
    cream2: Color(0xFF1B1B1A),
    creamInk: Color(0xFFFBFAF7),
    creamMuted: Color(0xFF5F5C56),
    clay: Color(0xFFE8572A),
    clayInk: Color(0xFFFBFAF7),
    violet: Color(0xFF2A2440),
    violet2: Color(0xFF3C3460),
    lilac: Color(0xFFC9BFF2),
    mint: Color(0xFFBFE3CC),
    mintInk: Color(0xFF10261A),
    butter: Color(0xFFF2D16B),
    butterInk: Color(0xFF2A2108),
    ok: Color(0xFF2F8A57),
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
    uiFont: 'Geist',
    numFont: 'Geist Mono',
    radiusTileLarge: 14,
    radiusTile: 14,
    radiusButton: 16,
    radiusRail: 22,
    radiusDigit: 10,
    textSoft: Color(0xFF5F5C56),
    hairline: Color(0xFFDDD8CE),
    ringTrack: Color(0xFFDDD8CE),
    amber: Color(0xFF1B1B1A),
    teal: Color(0xFFE8572A),
    blue: Color(0xFFE8572A),
    accentViolet: Color(0xFF1B1B1A),
    glowTeal: Color(0xFF2C8C96),
    glowViolet: Color(0xFF7850C8),
    glowClay: Color(0xFFE07A4F),
    glowPurple: Color(0xFF7A4DD8),
    glowMint: Color(0xFF5ED3A4),
    border: Color(0xFFDDD8CE),
    ink: Color(0xFF1B1B1A),
    ink2: Color(0xFF2C2B29),
    onInk: Color(0xFFFBFAF7),
    inkMuted: Color(0xFFB9B5AC),
    railActive: Color(0xFF1B1B1A),
    railActiveInk: Color(0xFFFBFAF7),
  );

  /// Edge: borderless, dark, with soft glows. Panels and radii are reused from Color Blocks
  /// until the Edge boards need their own.
  static const edge = DeskmateTokens(
    bg: Color(0xFF07090D),
    panel: Color(0xFF1A1A1D),
    panel2: Color(0xFF26262A),
    divider: Color(0x14FFFFFF),
    track: Color(0x17FFFFFF),
    text: Color(0xFFEAF0F7),
    muted: Color(0xFF7E8A9C),
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
    ok: Color(0xFF5ED3A4),
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
    uiFont: 'Inter',
    numFont: 'Outfit',
    radiusTileLarge: 24,
    radiusTile: 20,
    radiusButton: 16,
    radiusRail: 22,
    radiusDigit: 14,
    textSoft: Color(0xFF9AA6B8),
    hairline: Color(0x14FFFFFF),
    ringTrack: Color(0x17FFFFFF),
    amber: Color(0xFFF2D16B),
    teal: Color(0xFF4FD1C5),
    blue: Color(0xFF7FB2FF),
    accentViolet: Color(0xFFA58BFF),
    glowTeal: Color(0xFF2C8C96),
    glowViolet: Color(0xFF7850C8),
    glowClay: Color(0xFFE07A4F),
    glowPurple: Color(0xFF7A4DD8),
    glowMint: Color(0xFF5ED3A4),
    border: Color(0x00000000),
    ink: Color(0xFF141414),
    ink2: Color(0xFF26262A),
    onInk: Color(0xFFF3EEE6),
    inkMuted: Color(0xFFA5A39E),
    railActive: Color(0xFFF3EEE6),
    railActiveInk: Color(0xFF141414),
  );

  static DeskmateTokens forTheme(ThemeId id) => switch (id) {
    ThemeId.edge => edge,
    ThemeId.paper => paper,
    _ => colorBlocks,
  };

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
