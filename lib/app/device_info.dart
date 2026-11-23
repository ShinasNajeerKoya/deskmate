import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the app runs on a simulator or emulator rather than a real phone.
/// Answered natively: MainActivity.kt (Android emulator) and AppDelegate.swift
/// (iOS Simulator, via targetEnvironment(simulator)).
/// On iOS, the Simulator's environment variables are a fallback in case the
/// native side isn't there (e.g. after a hot restart onto an older build).
/// Anything else counts as a real device, so a real phone never ends up in demo mode.
Future<bool> isEmulator() async {
  try {
    return await const MethodChannel('deskmate/device').invokeMethod<bool>('isEmulator') ?? false;
  } catch (e) {
    if (Platform.isIOS) {
      final env = Platform.environment;
      final simulator = env.containsKey('SIMULATOR_DEVICE_NAME') || env.containsKey('SIMULATOR_UDID');
      debugPrint('Emulator check: native channel unavailable ($e); iOS Simulator by environment: $simulator');
      return simulator;
    }
    debugPrint('Emulator check failed, assuming a real device: $e');
    return false;
  }
}
