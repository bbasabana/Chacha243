package cd.chacha243.chacha243

import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
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

    // 60 images par seconde suffisent au jeu : sur un écran à 90 ou 120 Hz, le téléphone travaillerait
    // deux fois plus, chaufferait, et certains systèmes gèlent alors l'app (« trop de processeur »).
    private fun cap60() {
        val d = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else @Suppress("DEPRECATION") windowManager.defaultDisplay
        d ?: return
        val cur = d.mode
        val best = d.supportedModes
            .filter { it.physicalWidth == cur.physicalWidth && it.physicalHeight == cur.physicalHeight }
            .minByOrNull { Math.abs(it.refreshRate - 60f) } ?: return
        val lp = window.attributes
        if (lp.preferredDisplayModeId != best.modeId) {
            lp.preferredDisplayModeId = best.modeId
            lp.preferredRefreshRate = best.refreshRate
            window.attributes = lp
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cap60()
    }

    override fun onResume() {
        super.onResume()
        lockLandscape()
        cap60()
    }

    // L'écran verrouillé est en portrait : au déverrouillage, certains téléphones rendent le jeu
    // à l'ancienne taille, écrasé dans un coin. On redemande la taille de la vue quand l'app revient
    // au premier plan, puis encore un instant après, quand la rotation est finie.
    private val main = Handler(Looper.getMainLooper())

    private fun refit() {
        val v = findViewById<View>(FLUTTER_VIEW_ID) ?: window.decorView
        v.requestLayout()
        v.invalidate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) return
        lockLandscape()
        refit()
        main.postDelayed({ refit() }, 350)
        main.postDelayed({ refit() }, 900)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) main.postDelayed({ refit() }, 200)
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
