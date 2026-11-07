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
    musicVolume.addListener(_applyVolume);
    musicOn.addListener(_applyVolume);
  }

  static final instance = Music._();

  /// Le volume réglé à l'accueil, ou zéro quand la musique est coupée.
  double get _volume => musicOn.value ? musicVolume.value : 0;

  void _applyVolume() => _player.setVolume(_volume * _level).catchError((_) {});

  static const _fadeOut = Duration(milliseconds: 1200);
  static const _endFade = Duration(seconds: 4);

  final _player = AudioPlayer();
  final _available = <String, bool>{};
  String? _playing;

  /// Une chanson joue en ce moment (pour ne pas en lancer une autre par-dessus).
  bool get busy => _playing != null;

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
      _applyVolume();
      if (i >= steps) {
        t.cancel();
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  /// Joue la chanson [key]. En vol, un extrait ; avec [loop], la chanson entière en boucle.
  /// [level] remplace le volume prévu pour la chanson (la finale la joue plus fort).
  Future<bool> play(String key, {bool loop = false, double? level}) async {
    final song = momentSongs[key];
    if (song == null || _playing == key || !await _has(song.file)) return false;
    final order = ++_order;
    _end?.cancel();
    _endAt = null;
    _endLeft = null;
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
      await _player.play(
        AssetSource('audio/${song.file}'),
        volume: 0,
        position: Duration(milliseconds: (song.start * 1000).round()),
      );
      unawaited(_slide(level ?? song.level, Duration(milliseconds: (song.fadeIn * 1000).round()), order));
      if (!loop) {
        // Une chanson qui en enchaîne une autre lui passe la main un peu avant sa propre fin.
        final fadeAt =
            Duration(milliseconds: (song.seconds * 1000).round()) - (song.then != null ? _fadeOut : _endFade);
        _endIn(fadeAt.isNegative ? Duration.zero : fadeAt, order);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  DateTime? _endAt;
  Duration? _endLeft;

  void _endIn(Duration d, int order) {
    _endAt = DateTime.now().add(d);
    _end = Timer(d, () {
      final next = current?.then;
      if (next != null && order == _order) {
        play(next);
      } else {
        _fadeAway(order);
      }
    });
  }

  /// La pause du vol : la chanson s'arrête là où elle est, et sa fin attend aussi.
  Future<void> pause() async {
    if (_playing == null || _endLeft != null) return;
    _end?.cancel();
    _endLeft = _endAt == null ? Duration.zero : _endAt!.difference(DateTime.now());
    try {
      await _player.pause();
    } catch (_) {}
  }

  /// La reprise : la chanson repart d'où elle s'était arrêtée.
  Future<void> resume() async {
    final left = _endLeft;
    _endLeft = null;
    if (_playing == null || left == null) return;
    try {
      await _player.resume();
    } catch (_) {}
    if (_endAt != null) _endIn(left.isNegative ? Duration.zero : left, _order);
  }

  /// Fait remonter (ou baisser) la chanson en cours jusqu'à [level], en [seconds] secondes.
  void swell(double level, double seconds) {
    if (_playing == null) return;
    _slide(level, Duration(milliseconds: (seconds * 1000).round()), _order);
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
    _endAt = null;
    if (_endLeft != null) {
      _endLeft = null;
      _level = 0;
    }
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
