import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/archive.dart';

/// La musique du jeu : « Indépendance Cha Cha » à l'accueil, silence au décollage,
/// puis les chansons des moments. Chaque fichier n'est joué que s'il est présent
/// dans assets/audio (droits obtenus) ; sinon rien ne se passe.
///
/// Rien ne coupe net : une chanson monte en fondu, l'extrait d'un moment s'éteint
/// en fondu à la fin de sa durée, et une nouvelle chanson attend que la précédente
/// se soit tue.
class Music {
  Music._() {
    musicVolume.addListener(() {
      if (_level == 1) _player.setVolume(musicVolume.value);
    });
  }

  static final instance = Music._();

  static const _fadeIn = Duration(milliseconds: 1500);
  static const _fadeOut = Duration(milliseconds: 1200);
  static const _endFade = Duration(seconds: 4);

  final _player = AudioPlayer();
  final _available = <String, bool>{};
  String? _playing;

  /// Le niveau du fondu, de 0 (muet) à 1 (volume réglé par le joueur).
  double _level = 0;
  Timer? _fade, _end;

  /// Chaque nouvel ordre annule les fondus en cours de l'ordre précédent.
  int _order = 0;

  /// Le titre en cours, pour l'afficher (« ♪ Ali, bomaye ! »).
  MomentSong? current;

  Future<bool> _has(String file) async {
    return _available[file] ??= await rootBundle.load('assets/audio/$file').then((_) => true, onError: (_) => false);
  }

  /// Fait glisser le volume jusqu'à [to] ; se termine plus tôt si un autre ordre arrive.
  Future<void> _slide(double to, Duration over, int order) {
    _fade?.cancel();
    final from = _level;
    final steps = (over.inMilliseconds / 50).ceil().clamp(1, 1000);
    var i = 0;
    final done = Completer<void>();
    _fade = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (order != _order) {
        t.cancel();
        if (!done.isCompleted) done.complete();
        return;
      }
      i++;
      _level = from + (to - from) * (i / steps);
      _player.setVolume(musicVolume.value * _level).catchError((_) {});
      if (i >= steps) {
        t.cancel();
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  /// Joue la chanson [key]. En vol, un extrait ; avec [loop], la chanson entière en boucle.
  Future<bool> play(String key, {bool loop = false}) async {
    final song = momentSongs[key];
    if (song == null || _playing == key || !await _has(song.file)) return false;
    final order = ++_order;
    _end?.cancel();
    try {
      if (_playing != null) {
        await _slide(0, _fadeOut, order);
        if (order != _order) return false;
        await _player.stop();
      }
      _playing = key;
      current = song;
      _level = 0;
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await _player.play(AssetSource('audio/${song.file}'),
          volume: 0, position: Duration(milliseconds: (song.start * 1000).round()));
      unawaited(_slide(1, _fadeIn, order));
      if (!loop) {
        final fadeAt = Duration(milliseconds: (song.seconds * 1000).round()) - _endFade;
        _end = Timer(fadeAt.isNegative ? Duration.zero : fadeAt, () => _fadeAway(order));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// La fin de l'extrait : la chanson s'éteint doucement, puis le silence revient.
  Future<void> _fadeAway(int order) async {
    if (order != _order) return;
    await _slide(0, _endFade, order);
    if (order != _order) return;
    _playing = null;
    current = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Arrête la musique en fondu court (décollage, retour à l'accueil).
  Future<void> stop() async {
    final order = ++_order;
    _end?.cancel();
    if (_playing != null) await _slide(0, _fadeOut, order);
    if (order != _order) return;
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
