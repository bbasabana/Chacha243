import 'package:audioplayers/audioplayers.dart';

import '../app_state.dart';

/// Les petits sons du vol : une médaille, un bidon, un kit, une étoile, une ceinture.
///
/// Ils suivent le volume réglé à l'accueil, un peu plus bas que la musique.
class Sfx {
  Sfx._();

  static final instance = Sfx._();

  // Deux lecteurs par son : deux étoiles attrapées de suite ne se coupent pas.
  final _players = <String, List<AudioPlayer>>{};
  final _turn = <String, int>{};

  void play(String name) {
    final volume = musicVolume.value * (name == 'etoile' ? 0.35 : 0.7);
    if (volume <= 0) return;
    final pair = _players[name] ??= [for (var i = 0; i < 2; i++) AudioPlayer()..setPlayerMode(PlayerMode.lowLatency)];
    final i = _turn[name] = ((_turn[name] ?? 0) + 1) % pair.length;
    pair[i].play(AssetSource('sfx/$name.wav'), volume: volume).catchError((_) {});
  }
}
