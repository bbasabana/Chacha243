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
import com.google.android.gms.games.PlayGames
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import com.google.android.gms.games.PlayGamesSdk
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
        // Play Games connecte le joueur tout seul au lancement, s'il a un compte Google Play Jeux.
        PlayGamesSdk.initialize(this)
        cap60()
    }

    override fun onResume() {
        super.onResume()
        lockLandscape()
        cap60()
        // Une mise à jour commencée puis quittée reprend là où elle était.
        updates.appUpdateInfo.addOnSuccessListener { info ->
            if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) startUpdate(info)
        }
    }

    // La mise à jour depuis le Play Store, sans quitter le jeu : Google la télécharge, l'installe et relance l'app.
    private val updates by lazy { AppUpdateManagerFactory.create(this) }

    private fun startUpdate(info: AppUpdateInfo) =
        updates.startUpdateFlowForResult(info, this, AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE), 243)

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
        // Play Games : « player » dit qui est connecté (ou null), « signIn » le demande au joueur, d'un clic ;
        // « unlock » donne un succès, « submit » envoie un score à un classement, « achievements » et
        // « leaderboards » ouvrent les écrans de Google Play Jeux.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chacha243/games").setMethodCallHandler { call, result ->
            val auth = PlayGames.getGamesSignInClient(this)
            when (call.method) {
                "unlock" -> {
                    PlayGames.getAchievementsClient(this).unlock(call.argument<String>("id") ?: "")
                    return@setMethodCallHandler result.success(null)
                }
                "submit" -> {
                    val score = call.argument<Number>("score")?.toLong() ?: 0L
                    PlayGames.getLeaderboardsClient(this).submitScore(call.argument<String>("id") ?: "", score)
                    return@setMethodCallHandler result.success(null)
                }
                "achievements", "leaderboards" -> {
                    val screen = if (call.method == "achievements") PlayGames.getAchievementsClient(this).achievementsIntent
                    else PlayGames.getLeaderboardsClient(this).allLeaderboardsIntent
                    screen.addOnSuccessListener { startActivityForResult(it, 9001) }
                    return@setMethodCallHandler result.success(true)
                }
            }
            val task = when (call.method) {
                "player" -> auth.isAuthenticated
                "signIn" -> auth.signIn()
                else -> return@setMethodCallHandler result.notImplemented()
            }
            task.addOnCompleteListener { done ->
                if (!done.isSuccessful || done.result?.isAuthenticated != true) return@addOnCompleteListener result.success(null)
                PlayGames.getPlayersClient(this).currentPlayer.addOnCompleteListener { me ->
                    result.success(if (me.isSuccessful) me.result?.displayName else null)
                }
            }
        }
        // La mise à jour : « check » dit si une nouvelle version attend sur le Play Store, « start » la lance.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chacha243/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> updates.appUpdateInfo
                    .addOnSuccessListener { info ->
                        result.success(
                            info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                                info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                        )
                    }
                    .addOnFailureListener { result.success(false) }
                "start" -> updates.appUpdateInfo
                    .addOnSuccessListener { info ->
                        result.success(info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE && startUpdate(info))
                    }
                    .addOnFailureListener { result.success(false) }
                else -> result.notImplemented()
            }
        }
    }
}
