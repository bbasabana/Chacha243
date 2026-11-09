import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../app_state.dart';

/// Les petits sons du vol : une médaille, un bidon, un kit, une étoile, une ceinture.
///
/// Ils ne prennent jamais la main sur la musique : sans cela, Android couperait la chanson
/// à chaque étoile attrapée.
class Sfx {
  Sfx._();

  static final instance = Sfx._();

  static final _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(options: const {AVAudioSessionOptions.mixWithOthers}),
  );

  // Deux lecteurs par son : deux étoiles attrapées de suite ne se coupent pas.
  final _players = <String, List<AudioPlayer>>{};
  final _turn = <String, int>{};

  void play(String name) {
    if (!soundsOn.value) return;
    final volume = musicVolume.value.clamp(0.3, 1.0) * (name == 'etoile' ? 0.35 : 0.7);
    final pair = _players[name] ??= [
      for (var i = 0; i < 2; i++)
        AudioPlayer()
          // Un petit son ne dit jamais qu'il est fini : sans cela, chaque lecteur demanderait sa position
          // à Android à chaque image, pour toujours, et la mémoire du téléphone finirait par déborder.
          ..positionUpdater = null
          ..setAudioContext(_context)
          ..setPlayerMode(PlayerMode.lowLatency),
    ];
    final i = _turn[name] = ((_turn[name] ?? 0) + 1) % pair.length;
    pair[i].play(AssetSource('sfx/$name.wav'), volume: volume).catchError((_) {});
  }

  AudioPlayer? _suspense;
  bool _suspenseOn = false;

  /// La guerre approche : le grondement tourne en boucle, sous la musique.
  void suspense(bool on) {
    if (on == _suspenseOn) return;
    _suspenseOn = on;
    if (!on) {
      _suspense?.stop().catchError((_) {});
      return;
    }
    if (!soundsOn.value) return;
    final p = _suspense ??= AudioPlayer()
      ..positionUpdater = null
      ..setAudioContext(_context)
      ..setReleaseMode(ReleaseMode.loop);
    p.play(AssetSource('sfx/suspense.wav'), volume: musicVolume.value.clamp(0.3, 1.0) * 0.8).catchError((_) {});
  }

  /// Le vol en pause : le grondement attend avec lui.
  void holdSuspense(bool hold) {
    if (!_suspenseOn) return;
    (hold ? _suspense?.pause() : _suspense?.resume())?.catchError((_) {});
  }

  bool? _vibrator;

  /// Le crash est fini, le vol en pause : le téléphone arrête de vibrer tout de suite.
  Future<void> still() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  /// Une vraie vibration du téléphone : [ms] millisecondes, force de 1 à 255.
  Future<void> buzz(int ms, int amplitude) async {
    if (!vibrationsOn.value) return;
    try {
      _vibrator ??= await Vibration.hasVibrator();
      if (_vibrator == true) {
        await Vibration.vibrate(duration: ms, amplitude: amplitude);
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }
}
