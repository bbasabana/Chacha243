import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A new version waiting on the Play Store: the game says so at launch, and Google installs it
/// without leaving the game. Android only; a game installed outside the Play Store never hears of one.
class AppUpdate {
  AppUpdate._();

  static const _channel = MethodChannel('chacha243/update');
  static const _asked = 'chacha243.update_asked';

  /// True when a new version waits and the pilot was not already asked today.
  static Future<bool> due() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (await _channel.invokeMethod<bool>('check') != true) return false;
      final p = await SharedPreferences.getInstance();
      final last = DateTime.fromMillisecondsSinceEpoch(p.getInt(_asked) ?? 0);
      if (DateTime.now().difference(last) < const Duration(hours: 20)) return false;
      await p.setInt(_asked, DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Google's own screen: download, install, restart.
  static Future<void> start() async {
    try {
      await _channel.invokeMethod<bool>('start');
    } catch (_) {}
  }
}
