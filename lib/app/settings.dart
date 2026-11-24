import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/deskmate_tokens.dart';

enum HomeLayout {
  a('Layout A'),
  b('Layout B'),
  c('Layout C');

  const HomeLayout(this.label);
  final String label;

  /// Layout C is designed for Paper only so far (Color Blocks gets it later).
  bool availableIn(ThemeId theme) => this != HomeLayout.c || theme == ThemeId.paper;
}

/// User settings, saved on the phone.
class SettingsController extends ChangeNotifier {
  /// Bump when saved data needs a migration. 2: Graphite theme removed (maps to Edge).
  static const schemaVersion = 2;

  ThemeId theme = ThemeId.defaultTheme;
  Set<HomeLayout> homeLayouts = {HomeLayout.a, HomeLayout.b};
  int batteryLow = 30;
  int batteryHigh = 70;
  bool nightClock = true;
  bool use24h = false;

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      final saved = ThemeId.fromSaved(p.getString('theme'));
      theme = saved.available ? saved : ThemeId.defaultTheme;
      if ((p.getInt('schema') ?? 1) < schemaVersion) {
        // Keep the migrated choice (Graphite → Edge) even while Edge isn't selectable yet.
        if (p.containsKey('theme')) await p.setString('theme', saved.name);
        await p.setInt('schema', schemaVersion);
      }
      final layouts = p.getStringList('homeLayouts');
      if (layouts != null) {
        final byName = HomeLayout.values.asNameMap();
        final usable = {
          for (final n in layouts)
            if (byName[n] != null) byName[n]!,
        };
        if (usable.isNotEmpty) homeLayouts = usable;
      }
      batteryLow = p.getInt('batteryLow') ?? batteryLow;
      batteryHigh = p.getInt('batteryHigh') ?? batteryHigh;
      nightClock = p.getBool('nightClock') ?? nightClock;
      use24h = p.getBool('use24h') ?? use24h;
    } catch (e) {
      debugPrint('Settings not loaded: $e');
    }
  }

  /// The layouts that rotate on the current theme (a saved Layout C is skipped where it isn't designed).
  Set<HomeLayout> get activeLayouts {
    final usable = {
      for (final l in homeLayouts)
        if (l.availableIn(theme)) l,
    };
    return usable.isEmpty ? {HomeLayout.a} : usable;
  }

  /// Toggles a Home layout. At least one must stay selected (one = locked).
  void toggleLayout(HomeLayout l) {
    if (!l.availableIn(theme)) return;
    final next = {...homeLayouts};
    if (!next.remove(l)) next.add(l);
    if (next.isEmpty) return;
    homeLayouts = next;
    _prefs?.setStringList('homeLayouts', [for (final l in homeLayouts) l.name]);
    notifyListeners();
  }

  void setTheme(ThemeId id) {
    if (!id.available) return;
    theme = id;
    _prefs?.setString('theme', id.name);
    notifyListeners();
  }

  void setBatteryLimits(int low, int high) {
    batteryLow = low;
    batteryHigh = high;
    _prefs?.setInt('batteryLow', low);
    _prefs?.setInt('batteryHigh', high);
    notifyListeners();
  }

  void setNightClock(bool on) {
    nightClock = on;
    _prefs?.setBool('nightClock', on);
    notifyListeners();
  }

  void setUse24h(bool on) {
    use24h = on;
    _prefs?.setBool('use24h', on);
    notifyListeners();
  }
}
