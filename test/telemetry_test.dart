import 'package:chacha243/data/medals.dart';
import 'package:chacha243/game/checkpoint.dart';
import 'package:chacha243/game/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La boîte d'envoi hors connexion : rien ne se perd, rien ne grossit sans fin.
void main() {
  String r(String kind, int n) => '{"kind":"$kind","n":$n}';

  test('un nouveau point de reprise remplace celui qui attendait', () {
    var box = <String>[];
    box = Telemetry.keep(box, r('year', 1), save: false);
    box = Telemetry.keep(box, r('save', 1), save: true);
    box = Telemetry.keep(box, r('year', 2), save: false);
    box = Telemetry.keep(box, r('save', 2), save: true);
    expect(box, [r('year', 1), r('year', 2), r('save', 2)]);
  });

  test('la boîte garde les 200 rapports les plus récents', () {
    var box = <String>[];
    for (var i = 0; i < 250; i++) {
      box = Telemetry.keep(box, r('year', i), save: false);
    }
    expect(box.length, 200);
    expect(box.first, r('year', 50));
    expect(box.last, r('year', 249));
  });

  test('un rapport ajouté pendant l\'envoi reste dans la boîte', () {
    final before = [r('year', 1), r('year', 2), r('year', 3)];
    final sending = before.take(2).toList();
    final meanwhile = [...before, r('crash', 4)];
    expect(Telemetry.sent(meanwhile, sending), [r('year', 3), r('crash', 4)]);
  });

  test('envoyer ne touche pas la boîte d\'origine', () {
    final box = [r('year', 1)];
    Telemetry.sent(box, box);
    Telemetry.keep(box, r('year', 2), save: false);
    expect(box, [r('year', 1)]);
  });

  test('le saut du concepteur garde l\'argent et le temps, et compte les médaillons passés', () {
    final cp = Telemetry.jumpedCheckpoint(2023, Checkpoint(1980, 500, 3, money: 9000, seconds: 700));
    expect(cp.year, 2023);
    expect(cp.money, 9000);
    expect(cp.seconds, 700);
    expect(cp.medals, greaterThan(20));
    expect(Telemetry.jumpedCheckpoint(2023, null).money, 3000);
    // Presque sans argent (540 après un vol) : le saut redonne de quoi payer le plein, pas un avion bloqué au sol.
    final poor = Telemetry.jumpedCheckpoint(2017.02, Checkpoint(1997.6, 0, 40, money: 540, seconds: 1363));
    expect(poor.money, 3000);
    expect(poor.year.floor(), 2017);
    // Retour en arrière : 2016, 2017, 2018 ramènent le pilote, avec moins de médaillons.
    for (final y in [2016.0, 2017.0, 2018.0]) {
      final back = Telemetry.jumpedCheckpoint(y, Checkpoint(2023, 900, 99, money: 9000, seconds: 700));
      expect(back.year, y);
      expect(back.medals, lessThan(99));
      expect(back.money, 9000);
    }
  });

  test('la médaille suit jusqu\'où le pilote a volé', () {
    expect(medalFor(1965, 0), isNull);
    expect(medalFor(1970, 0)?.name, 'Bronze');
    expect(medalFor(2023.4, 0)?.name, 'Platine');
    expect(medalFor(2026.9, 0)?.name, 'Platine');
    expect(medalFor(2027, 1)?.name, 'Diamant');
    expect(nextMedal(1990, 0)?.name, 'Or');
    expect(nextMedal(2027, 1), isNull);
  });

  test('hors connexion, le classement garde la dernière place connue et la marque comme ancienne', () async {
    SharedPreferences.setMockInitialValues({
      'chacha243.standing':
          '{"rank":3,"total":40,"bestYear":2016.5,"bestScore":900,"wins":0,"crashes":4,"flights":9,"seconds":3000}',
    });
    final s = await Telemetry.standing();
    expect(s?.rank, 3);
    expect(s?.total, 40);
    expect(s?.stale, isTrue);
    SharedPreferences.setMockInitialValues({});
    expect(await Telemetry.standing(), isNull);
  });
}
