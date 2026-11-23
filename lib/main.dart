import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/demo_tour.dart';
import 'app/device_info.dart';
import 'app/focus_timer.dart';
import 'app/phone_battery.dart';
import 'app/settings.dart';
import 'app/shell.dart';
import 'ble/fake_mac_link.dart';
import 'ble/mac_link.dart';
import 'theme/deskmate_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable(); // always-on display

  final settings = SettingsController();
  await settings.load();

  // Simulators and emulators can't reach the Mac's Bluetooth, so they get a
  // simulated Mac plus a demo tour through every state and page (10 s each).
  // Real phones always use real Bluetooth.
  // --dart-define=FAKE_MAC=true|false overrides the detection.
  const override = String.fromEnvironment('FAKE_MAC');
  final demo = override.isEmpty ? await isEmulator() : override == 'true';
  final MacLink link = (demo ? FakeMacLink() : MacLink())..start();
  final battery = PhoneBattery(simulate: demo)..start();
  final tour = demo ? (DemoTour(link: link as FakeMacLink, battery: battery)..start()) : null;

  runApp(DeskmateApp(link: link, settings: settings, battery: battery, timer: FocusTimer(), tour: tour));
}

class DeskmateApp extends StatelessWidget {
  const DeskmateApp({
    super.key,
    required this.link,
    required this.settings,
    required this.battery,
    required this.timer,
    this.tour,
  });

  final MacLink link;
  final SettingsController settings;
  final PhoneBattery battery;
  final FocusTimer timer;
  final DemoTour? tour;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder:
          (context, _) => MaterialApp(
            title: 'Deskmate',
            debugShowCheckedModeBanner: false,
            theme: DeskmateTokens.forTheme(settings.theme).toThemeData(),
            home: Shell(
              link: link,
              settings: settings,
              battery: battery,
              timer: timer,
              tour: tour,
              nightAfter: tour?.nightAfter ?? const Duration(seconds: 30),
            ),
          ),
    );
  }
}
