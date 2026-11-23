import 'package:flutter/widgets.dart';

import '../ble/mac_link.dart';
import 'focus_timer.dart';
import 'phone_battery.dart';
import 'settings.dart';

/// Sidebar pages, in default order. Settings is pinned at the bottom of the rail.
enum PageId {
  home('Home'),
  claude('Claude'),
  music('Music'),
  system('System'),
  control('Control'),
  timer('Timer'),
  calendar('Calendar'),
  weather('Weather'),
  shortcuts('Shortcuts'),
  github('GitHub'),
  settings('Settings');

  const PageId(this.label);
  final String label;
}

/// App-wide state handed down the tree. The shell rebuilds when any of it changes.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.link,
    required this.settings,
    required this.battery,
    required this.timer,
    required this.open,
    required super.child,
  });

  final MacLink link;
  final SettingsController settings;
  final PhoneBattery battery;
  final FocusTimer timer;
  final void Function(PageId page) open;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => true;
}
