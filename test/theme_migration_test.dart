import 'package:deskmate/app/settings.dart';
import 'package:deskmate/theme/deskmate_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Graphite is gone and saved Graphite maps to Edge', () {
    expect(ThemeId.values.map((t) => t.name), ['edge', 'colorBlocks', 'paper', 'horizon']);
    expect(ThemeId.fromSaved('graphite'), ThemeId.edge);
  });

  test('missing or unknown saved theme gives the default', () {
    expect(ThemeId.fromSaved(null), ThemeId.defaultTheme);
    expect(ThemeId.fromSaved('nonsense'), ThemeId.defaultTheme);
    expect(ThemeId.fromSaved('paper'), ThemeId.paper);
  });

  test('navigation style comes from the theme: only Edge swipes', () {
    expect(ThemeId.edge.navigation, NavStyle.swipeDots);
    for (final t in [ThemeId.colorBlocks, ThemeId.paper]) {
      expect(t.navigation, NavStyle.sidebar);
    }
  });

  test('Edge tokens match the design', () {
    final e = DeskmateTokens.forTheme(ThemeId.edge);
    expect(e.bg.toARGB32(), 0xFF07090D);
    expect(e.text.toARGB32(), 0xFFEAF0F7);
    expect(e.uiFont, 'Inter');
    expect(e.numFont, 'Outfit');
    expect(DeskmateTokens.forTheme(ThemeId.colorBlocks).uiFont, 'DM Sans');
  });

  test('settings migration: old Graphite is saved as Edge, schema bumps, app stays usable', () async {
    SharedPreferences.setMockInitialValues({'theme': 'graphite'});
    final s = SettingsController();
    await s.load();
    final p = await SharedPreferences.getInstance();
    expect(p.getString('theme'), 'edge');
    expect(p.getInt('schema'), SettingsController.schemaVersion);
    // Edge isn't selectable until its shell is built, so the running theme is the default.
    expect(s.theme.available, isTrue);
  });

  test('fresh install gets the default theme', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsController();
    await s.load();
    expect(s.theme, ThemeId.defaultTheme);
  });
}
