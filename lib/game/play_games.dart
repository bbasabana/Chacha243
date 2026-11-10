import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Google Play Games, on Android only. The player is signed in by the system at launch, without a click,
/// when the phone has a Play Games account. Never blocks the game: anything that fails just leaves [player] empty.
class PlayGames {
  PlayGames._();

  static const _channel = MethodChannel('chacha243/games');

  /// The Play Games name of the signed-in player, or null.
  static final player = ValueNotifier<String?>(null);

  static bool get _here => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Who did the automatic sign-in let in.
  static Future<void> check() => _ask('player');

  /// Asks the player to sign in, after a tap on a button.
  static Future<void> signIn() => _ask('signIn');

  static Future<void> _ask(String method) async {
    if (!_here) return;
    try {
      player.value = await _channel.invokeMethod<String>(method);
    } catch (_) {}
  }
}
