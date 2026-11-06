package cd.chacha243.chacha243

import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Couché, toujours : on le redemande à chaque retour et si l'écran a tourné malgré tout.
    private fun lockLandscape() {
        if (requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        }
    }

    override fun onResume() {
        super.onResume()
        lockLandscape()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            lockLandscape()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Le téléphone du pilote : sa marque, son Android, son opérateur, et un identifiant qui reste
        // le même après une réinstallation (ANDROID_ID est propre à l'app et à ce téléphone).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chacha243/device").setMethodCallHandler { call, result ->
            if (call.method != "info") return@setMethodCallHandler result.notImplemented()
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            result.success(
                mapOf(
                    "id" to (Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""),
                    "brand" to Build.BRAND,
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL,
                    "os" to "Android ${Build.VERSION.RELEASE}",
                    "operator" to (tm?.networkOperatorName ?: ""),
                    "sim" to (tm?.simOperatorName ?: ""),
                    "simCountry" to (tm?.simCountryIso ?: ""),
                ),
            )
        }
    }
}
