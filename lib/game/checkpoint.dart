import 'package:shared_preferences/shared_preferences.dart';

/// Le point de reprise : après un atterrissage d'urgence, on redécolle là où on s'est arrêté.
///
/// Il est posé à l'entrée de chaque zone de turbulence, à la sortie, et à chaque décennie.
class Checkpoint {
  const Checkpoint(this.year, this.score, this.medals);

  final double year;
  final int score;
  final int medals;

  static const _key = 'chacha243.checkpoint';

  static Future<Checkpoint?> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getStringList(_key);
      if (v == null || v.length != 3) return null;
      return Checkpoint(double.parse(v[0]), int.parse(v[1]), int.parse(v[2]));
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, ['$year', '$score', '$medals']);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}
