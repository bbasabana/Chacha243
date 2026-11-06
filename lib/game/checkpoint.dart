import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry.dart';

/// Le point de reprise : après un atterrissage d'urgence, on redécolle là où on s'est arrêté.
///
/// Il est posé à l'entrée de chaque zone de turbulence, à la sortie, et à chaque décennie.
/// L'argent, lui, est celui qui restait au moment du crash : ce qui a été dépensé est perdu.
class Checkpoint {
  Checkpoint(this.year, this.score, this.medals, {this.money = 3000});

  final double year;
  final int score;
  final int medals;
  int money;

  static const _key = 'chacha243.checkpoint';

  static Future<Checkpoint?> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getStringList(_key);
      if (v == null || v.length < 3) return null;
      return Checkpoint(
        double.parse(v[0]),
        int.parse(v[1]),
        int.parse(v[2]),
        money: v.length > 3 ? int.parse(v[3]) : 3000,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sur le téléphone, et une copie en ligne pour la retrouver après une réinstallation.
  Future<void> save({bool sync = true}) async {
    if (sync) Telemetry.saveProgress(this);
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, ['$year', '$score', '$medals', '$money']);
    } catch (_) {}
  }

  static Future<void> clear() async {
    Telemetry.saveProgress(null);
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}
