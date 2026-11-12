import 'package:chacha243/game/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un nom grossier ne passe pas au classement', () {
    expect(cleanPilotName('Merde'), 'Pilote');
    expect(cleanPilotName('gros CON'), 'Pilote');
    expect(cleanPilotName('Enculé 243'), 'Pilote');
    expect(cleanPilotName('s.a.l.o.p.e'), 'Pilote');
    expect(cleanPilotName('Nyoko na yo'), 'Pilote');
    expect(cleanPilotName('   '), 'Pilote');
  });

  test('un vrai nom reste tel quel', () {
    expect(cleanPilotName('Bienvenu'), 'Bienvenu');
    expect(cleanPilotName('Conrad'), 'Conrad');
    expect(cleanPilotName('Mama Pitshou'), 'Mama Pitshou');
    expect(cleanPilotName(' Kabila 2027 '), 'Kabila 2027');
  });
}
