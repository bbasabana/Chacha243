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
