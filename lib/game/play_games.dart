import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Google Play Games, on Android only. The player is signed in by the system at launch, without a click,
/// when the phone has a Play Games account. Never blocks the game: anything that fails just leaves [player] empty.
class PlayGames {
  PlayGames._();

  static const _channel = MethodChannel('chacha243/games');

  /// The Play Games name of the signed-in player, or null.
  static final player = ValueNotifier<String?>(null);

  static bool get here => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Who did the automatic sign-in let in.
  static Future<void> check() => _ask('player');

  /// Asks the player to sign in, after a tap on a button.
  static Future<void> signIn() => _ask('signIn');

  static Future<void> _ask(String method) async {
    if (!here) return;
    try {
      player.value = await _channel.invokeMethod<String>(method);
    } catch (_) {}
  }

  static void unlock(String id) => _call('unlock', {'id': id});

  static void submit(String id, int score) => _call('submit', {'id': id, 'score': score});

  /// The Play Games screens: the pilot's achievements, the leaderboards.
  static void showAchievements() => _call('achievements');
  static void showLeaderboards() => _call('leaderboards');

  static Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!here || player.value == null) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {}
  }
}
