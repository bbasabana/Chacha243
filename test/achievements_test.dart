import 'package:chacha243/game/achievements.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Achievements.reset();
  });

  test('les 14 succès valent 1000 points, le maximum de Play Jeux', () {
    expect(Achievement.values.length, 14);
    expect(Achievement.values.fold(0, (n, a) => n + a.points), 1000);
    for (final a in Achievement.values) {
      expect(a.points % 5, 0, reason: a.title);
      expect(a.points, inInclusiveRange(5, 200), reason: a.title);
    }
  });

  test('un succès simple se gagne une fois, pas deux', () async {
    expect(await Achievements.step(Achievement.boulevard), isTrue);
    expect(await Achievements.step(Achievement.boulevard), isFalse);
    expect(Achievements.earned.value, {Achievement.boulevard});
  });

  test('dix bonnes réponses donnent « Mémoire du Congo »', () async {
    for (var i = 0; i < 9; i++) {
      expect(await Achievements.step(Achievement.quiz), isFalse);
    }
    expect(Achievements.progress.value[Achievement.quiz], 9);
    expect(await Achievements.step(Achievement.quiz), isTrue);
  });

  test('cinq aéroports différents, pas cinq fois le même', () async {
    for (var i = 0; i < 6; i++) {
      await Achievements.step(Achievement.traveller, 'Kinshasa');
    }
    expect(Achievements.earned.value, isEmpty);
    for (final c in ['Lubumbashi', 'Goma', 'Kisangani']) {
      await Achievements.step(Achievement.traveller, c);
    }
    expect(await Achievements.step(Achievement.traveller, 'Mbandaka'), isTrue);
  });

  test('les médailles déjà gagnées allument leurs succès, sans rien inventer', () async {
    await Achievements.catchUp(bestYear: 2000.4, flights: 12);
    expect(Achievements.earned.value, {Achievement.takeoff, Achievement.bronze, Achievement.silver});
    await Achievements.catchUp(wins: 1);
    expect(Achievements.earned.value, containsAll([Achievement.gold, Achievement.platinum, Achievement.diamond]));
    expect(Achievements.earned.value, isNot(contains(Achievement.boulevard)));
    expect(await Achievements.catchUp(bestYear: 2027, wins: 1), isFalse, reason: 'rien de neuf');
  });

  test('ceux que le serveur connaît reviennent, par leur nom', () async {
    await Achievements.grant([
      for (final n in ['quiz', 'inconnu', 'duel']) ?Achievements.byName(n),
    ]);
    expect(Achievements.earned.value, {Achievement.quiz, Achievement.duel});
    expect(Achievements.progress.value[Achievement.quiz], 10);
    expect(Achievements.names, containsAll(['quiz', 'duel']));
  });

  test('les succès restent sur le téléphone', () async {
    await Achievements.step(Achievement.takeoff);
    for (final c in ['gorilla', 'okapi']) {
      await Achievements.step(Achievement.naturalist, c);
    }
    Achievements.reset();
    await Achievements.load();
    expect(Achievements.earned.value, {Achievement.takeoff});
    expect(Achievements.progress.value[Achievement.naturalist], 2);
  });
}
