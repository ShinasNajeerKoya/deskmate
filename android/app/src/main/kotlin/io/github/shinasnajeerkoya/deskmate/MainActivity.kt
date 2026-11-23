package io.github.shinasnajeerkoya.deskmate

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "deskmate/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "isEmulator" -> result.success(isEmulator())
                // Android drops multicast packets unless an app holds this lock; needed to
                // find the Mac via Bonjour (mDNS) on the Wi-Fi network.
                "multicastLock" -> {
                    val on = call.arguments as Boolean
                    if (on && multicastLock == null) {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        multicastLock = wifi.createMulticastLock("deskmate-mdns").apply {
                            setReferenceCounted(false)
                            acquire()
                        }
                    } else if (!on) {
                        multicastLock?.release()
                        multicastLock = null
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Crypto for the encrypted Wi-Fi link (Android's built-in javax.crypto; no extra libraries).
        MethodChannel(messenger, "deskmate/crypto").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pbkdf2" -> {
                        val password = call.argument<String>("password")!!
                        val salt = call.argument<ByteArray>("salt")!!
                        val iterations = call.argument<Int>("iterations")!!
                        val spec = PBEKeySpec(password.toCharArray(), salt, iterations, 256)
                        result.success(SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded)
                    }
                    "hmac" -> {
                        val mac = Mac.getInstance("HmacSHA256")
                        mac.init(SecretKeySpec(call.argument<ByteArray>("key")!!, "HmacSHA256"))
                        result.success(mac.doFinal(call.argument<ByteArray>("data")!!))
                    }
                    // Output/input format matches CryptoKit's AES.GCM "combined": nonce(12) || ciphertext || tag(16).
                    "seal" -> {
                        val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(call.argument<ByteArray>("key")!!, "AES"), GCMParameterSpec(128, nonce))
                        result.success(nonce + cipher.doFinal(call.argument<ByteArray>("data")!!))
                    }
                    "open" -> {
                        val box = call.argument<ByteArray>("data")!!
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(call.argument<ByteArray>("key")!!, "AES"), GCMParameterSpec(128, box, 0, 12))
                        result.success(cipher.doFinal(box, 12, box.size - 12))
                    }
                    "random" -> result.success(ByteArray(call.arguments as Int).also { SecureRandom().nextBytes(it) })
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("crypto", e.message, null)
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
