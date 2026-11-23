package io.github.shinasnajeerkoya.deskmate

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deskmate/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEmulator" -> result.success(isEmulator())
                    else -> result.notImplemented()
                }
            }
    }

    /** True on the Android Studio emulator (and other common emulators), false on real phones. */
    private fun isEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.contains("emulator") ||
            Build.HARDWARE.contains("goldfish") ||
            Build.HARDWARE.contains("ranchu") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for") ||
            Build.MODEL.startsWith("sdk_") ||
            Build.PRODUCT.contains("sdk") ||
            Build.PRODUCT.contains("emulator") ||
            Build.MANUFACTURER.contains("Genymotion")
}
