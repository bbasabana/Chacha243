import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'play_games.dart';

/// The pilot's achievements. They are kept on the phone (so they work offline, on iPhone and without
/// a Play Games account), and sent to Google Play Games when the player is signed in there.
/// The 14 together are worth 1000 points, the most Play Games allows for a game.
enum Achievement {
  takeoff(
    'Indépendance',
    "Décolle pour la première fois avec l'avion du Congo.",
    10,
    Icons.flight_takeoff_rounded,
    Color(0xFF2FA8FF),
  ),
  bronze('Médaille de bronze', "Vole jusqu'en 1970.", 40, Icons.workspace_premium_rounded, Color(0xFFC98A4B)),
  silver("Médaille d'argent", "Vole jusqu'en 1990.", 60, Icons.workspace_premium_rounded, Color(0xFFAEB6C2)),
  gold("Médaille d'or", "Vole jusqu'en 2005.", 90, Icons.workspace_premium_rounded, Color(0xFFF2C230)),
  platinum('Médaille de platine', "Vole jusqu'en 2020.", 110, Icons.workspace_premium_rounded, Color(0xFFC9D3E6)),
  diamond(
    'Retour à Kinshasa',
    'Arrive à Kinshasa le 30 juin 2027 : la médaille de diamant.',
    200,
    Icons.diamond_rounded,
    Color(0xFF5AD7FF),
  ),
  ceasefire(
    'Premier cessez-le-feu',
    'Réussis ta première étape de crise.',
    40,
    Icons.shield_rounded,
    Color(0xFF3CC77A),
  ),
  peacemaker(
    'Artisan de la paix',
    'Réussis 10 étapes de crise.',
    90,
    Icons.handshake_rounded,
    Color(0xFF1E9E5A),
    goal: 10,
  ),
  boulevard(
    'Boulevard Lumumba',
    "Frôle le boulevard Lumumba et reprends de l'altitude.",
    70,
    Icons.flight_land_rounded,
    Color(0xFFFF9A3C),
  ),
  quiz(
    'Mémoire du Congo',
    'Donne 10 bonnes réponses aux questions.',
    50,
    Icons.menu_book_rounded,
    Color(0xFFB07CFF),
    goal: 10,
  ),
  naturalist(
    'Œil de la forêt',
    'Aperçois au hublot le gorille, l\'okapi, le léopard et les éléphants.',
    50,
    Icons.forest_rounded,
    Color(0xFF6CC24A),
    goal: 4,
  ),
  crew('Équipage en or', 'Sers 10 repas à tes passagers.', 50, Icons.restaurant_rounded, Color(0xFFFF5A6E), goal: 10),
  traveller(
    'Grand voyageur',
    'Atterris dans 5 aéroports différents.',
    60,
    Icons.connecting_airports_rounded,
    Color(0xFF4FD1C5),
    goal: 5,
  ),
  duel('Champion du duel', 'Gagne un duel contre un autre pilote.', 80, Icons.emoji_events_rounded, Color(0xFFF7D618));

  const Achievement(this.title, this.how, this.points, this.icon, this.color, {this.goal = 1});

  final String title, how;
  final int points;
  final IconData icon;
  final Color color;

  /// How many times (or different things) it takes.
  final int goal;
}

/// The Play Games leaderboards.
enum Board {
  farthest('Plus loin'),
  score('Meilleur score');

  const Board(this.title);
  final String title;
}

class Achievements {
  Achievements._();

  /// The ids Play Console gives each achievement and leaderboard (Services de jeux Play → Succès / Classements).
  /// One left out is simply kept on the phone until it is filled in.
  static const playIds = <Achievement, String>{};
  static const boardIds = <Board, String>{};

  static const _box = 'chacha243.achievements';
  static String _countKey(Achievement a) => '$_box.count.${a.name}';
  static String _thingsKey(Achievement a) => '$_box.things.${a.name}';

  /// What the pilot has earned, for the screens.
  static final earned = ValueNotifier<Set<Achievement>>({});

  /// Where each one stands, for the screens: done things out of [Achievement.goal].
  static final progress = ValueNotifier<Map<Achievement, int>>({});

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final got = p.getStringList(_box) ?? const [];
      earned.value = {
        for (final a in Achievement.values)
          if (got.contains(a.name)) a,
      };
      progress.value = {for (final a in Achievement.values) a: _done(p, a)};
    } catch (_) {}
  }

  static int _done(SharedPreferences p, Achievement a) {
    if (earned.value.contains(a)) return a.goal;
    final things = p.getStringList(_thingsKey(a));
    return things != null ? things.length : p.getInt(_countKey(a)) ?? 0;
  }

  /// One step toward [a]: once more, or one more different thing when [thing] is given
  /// (an airport, an animal). Answers true when this step earned it.
  static Future<bool> step(Achievement a, [String? thing]) async {
    if (earned.value.contains(a)) return false;
    try {
      final p = await SharedPreferences.getInstance();
      if (a.goal > 1) {
        if (thing != null) {
          final things = {...?p.getStringList(_thingsKey(a)), thing};
          await p.setStringList(_thingsKey(a), things.toList());
        } else {
          await p.setInt(_countKey(a), (p.getInt(_countKey(a)) ?? 0) + 1);
        }
      }
      final done = a.goal > 1 ? _done(p, a) : 1;
      progress.value = {...progress.value, a: done};
      if (done < a.goal) return false;
      earned.value = {...earned.value, a};
      await p.setStringList(_box, [for (final x in earned.value) x.name]);
      _send(a);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Everything earned so far goes to Play Games: earned offline, or before the ids were filled in.
  static void sync() {
    for (final a in earned.value) {
      _send(a);
    }
  }

  static void _send(Achievement a) {
    if (playIds[a] case final id?) PlayGames.unlock(id);
  }

  /// A flight's result for a leaderboard; Play Games keeps only the best.
  static void submit(Board b, int score) {
    if (boardIds[b] case final id?) PlayGames.submit(id, score);
  }

  @visibleForTesting
  static void reset() {
    earned.value = {};
    progress.value = {};
  }
}
