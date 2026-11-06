import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/archive.dart';

/// La musique du jeu : « Indépendance Cha Cha » à l'accueil, silence au décollage,
/// puis les chansons des moments. Chaque fichier n'est joué que s'il est présent
/// dans assets/audio (droits obtenus) ; sinon rien ne se passe.
class Music {
  Music._() {
    musicVolume.addListener(() => _player.setVolume(musicVolume.value));
  }

  static final instance = Music._();

  final _player = AudioPlayer();
  final _available = <String, bool>{};
  String? _playing;

  /// Le titre en cours, pour l'afficher (« ♪ Ali, bomaye ! »).
  MomentSong? current;

  Future<bool> _has(String file) async {
    return _available[file] ??= await rootBundle.load('assets/audio/$file').then((_) => true, onError: (_) => false);
  }

  Future<bool> play(String key, {bool loop = false}) async {
    final song = momentSongs[key];
    if (song == null || _playing == key || !await _has(song.file)) return false;
    try {
      _playing = key;
      current = song;
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await _player.setVolume(musicVolume.value);
      await _player.play(AssetSource('audio/${song.file}'));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _playing = null;
    current = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<bool> isAvailable(String key) async {
    final song = momentSongs[key];
    return song != null && await _has(song.file);
  }
}
