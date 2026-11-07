import 'package:chacha243/game/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
