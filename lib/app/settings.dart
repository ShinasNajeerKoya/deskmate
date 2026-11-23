import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/deskmate_tokens.dart';

enum HomeLayout {
  a('Layout A'),
  b('Layout B'),
  c('Layout C');

  const HomeLayout(this.label);
  final String label;

  /// Layout C isn't designed for Color Blocks yet.
  bool get available => this != HomeLayout.c;
}

/// User settings, saved on the phone.
class SettingsController extends ChangeNotifier {
  ThemeId theme = ThemeId.colorBlocks;
  Set<HomeLayout> homeLayouts = {HomeLayout.a, HomeLayout.b};
  int batteryLow = 30;
  int batteryHigh = 70;
  bool nightClock = true;
  bool use24h = false;

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      theme = ThemeId.values.asNameMap()[p.getString('theme')] ?? theme;
      final layouts = p.getStringList('homeLayouts');
      if (layouts != null) {
        final byName = HomeLayout.values.asNameMap();
        final usable = {
          for (final n in layouts)
            if (byName[n]?.available ?? false) byName[n]!,
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

  /// Toggles a Home layout. At least one must stay selected (one = locked).
  void toggleLayout(HomeLayout l) {
    if (!l.available) return;
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
