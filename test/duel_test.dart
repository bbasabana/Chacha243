import 'package:chacha243/data/aircraft_types.dart';
import 'package:chacha243/game/chacha_game.dart';
import 'package:chacha243/game/duel.dart';
import 'package:chacha243/ui/duel_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DuelPlayer _p(String id, Pilot s, {double y = 1970, int at = 0}) => DuelPlayer(id, id)
  ..state = s
  ..year = y
  ..arrivedAt = at;

void main() {
  const course = DuelRules(mode: DuelMode.course, start: 1960, target: 2027);
  const equipe = DuelRules(mode: DuelMode.equipe, start: 1960, target: 2027);

  test('course : le premier arrivé gagne, celui qui échoue sort et les autres continuent', () {
    expect(judge(course, [_p('a', Pilot.flying), _p('b', Pilot.flying)]), isNull);
    expect(judge(course, [_p('a', Pilot.crashed), _p('b', Pilot.flying)]), isNull);
    final o = judge(course, [_p('a', Pilot.arrived, at: 20), _p('b', Pilot.arrived, at: 10)]);
    expect(o?.end, DuelEnd.win);
    expect(o?.winners, ['b']);
  });

  test('course : le dernier en vol peut s\'arrêter et gagner', () {
    final o = judge(course, [_p('a', Pilot.crashed), _p('b', Pilot.won), _p('c', Pilot.stopped)]);
    expect(o?.winners, ['b']);
  });

  test('course : tout le monde est tombé, le plus loin gagne, ou égalité', () {
    expect(judge(course, [_p('a', Pilot.crashed, y: 1980), _p('b', Pilot.crashed, y: 1990)])?.winners, ['b']);
    expect(judge(course, [_p('a', Pilot.crashed, y: 1980), _p('b', Pilot.crashed, y: 1980)])?.end, DuelEnd.draw);
  });

  test('équipe : un seul échec et le duel est perdu pour tous, tous arrivés et tous gagnent', () {
    expect(judge(equipe, [_p('a', Pilot.flying), _p('b', Pilot.crashed)])?.end, DuelEnd.teamFail);
    expect(judge(equipe, [_p('a', Pilot.flying), _p('b', Pilot.stopped)])?.end, DuelEnd.teamFail);
    expect(judge(equipe, [_p('a', Pilot.arrived), _p('b', Pilot.flying)]), isNull);
    final o = judge(equipe, [_p('a', Pilot.arrived), _p('b', Pilot.arrived)]);
    expect(o?.end, DuelEnd.win);
    expect(o?.winners.length, 2);
  });

  test('les règles venues du réseau sont refusées quand elles n\'ont pas de sens', () {
    expect(DuelRules.fromJson({'m': 0, 's': 1960, 'g': 2027, 'k': 'un repas'})?.stake, 'un repas');
    expect(DuelRules.fromJson({'m': 9, 's': 1960, 'g': 2027}), isNull);
    expect(DuelRules.fromJson({'m': 0, 's': 2000, 'g': 1990}), isNull);
    expect(DuelRules.fromJson({'m': 0, 's': 1960, 'g': 3000}), isNull);
    expect(DuelRules.fromJson('x'), isNull);
    expect(DuelPlayer.fromWire(['a', 'b', 1, 2, 99, 3]), isNull);
  });

  test('un duel de bout en bout sur le réseau local : salle, départ, états signés, verdict', () async {
    final host = await DuelNet.host(
      myId: 'host-0000001',
      myName: 'Hôte',
      rules: const DuelRules(mode: DuelMode.course, start: 1960, target: 2027, stake: 'un café'),
    );
    expect(host, isNotNull);
    final guest = await DuelNet.join(
      myId: 'guest-000001',
      myName: 'Invité',
      address: '127.0.0.1',
      port: host!.hostPort!,
      code: host.code,
    );
    expect(guest, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(host.players.length, 2);
    expect(guest!.players.length, 2);
    expect(guest.rules.stake, 'un café');

    expect(host.launch(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(guest.started, isTrue);
    expect(guest.seed, host.seed);

    // l'invité avance, l'hôte le voit
    guest.report(year: 1975, lives: 3, state: Pilot.flying);
    guest.report(year: 1975, lives: 2, state: Pilot.crashed);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(host.players.firstWhere((p) => p.id == 'guest-000001').state, Pilot.crashed);
    // l'hôte est seul en vol : il peut gagner
    host.report(year: 1990, lives: 3, state: Pilot.won);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(host.outcome?.winners, ['host-0000001']);
    expect(guest.outcome?.winners, ['host-0000001']);
    expect(guest.result()['win'], isFalse);
    expect(host.result()['win'], isTrue);
    host.close();
    guest.close();
  });

  test('un message mal signé ou rejoué est ignoré', () async {
    final host = await DuelNet.host(myId: 'host-0000002', myName: 'H', rules: const DuelRules());
    final guest = await DuelNet.join(
      myId: 'guest-000002',
      myName: 'G',
      address: '127.0.0.1',
      port: host!.hostPort!,
      code: host.code,
    );
    host.launch();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    guest!.report(year: 1980, lives: 3, state: Pilot.flying);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final seen = host.players.firstWhere((p) => p.id == 'guest-000002').year;
    expect(seen, closeTo(1980, 0.01));
    host.close();
    guest.close();
  });

  test('mauvais code : l\'entrée est refusée', () async {
    final host = await DuelNet.host(myId: 'host-0000003', myName: 'H', rules: const DuelRules());
    final guest = await DuelNet.join(
      myId: 'guest-000003',
      myName: 'G',
      address: '127.0.0.1',
      port: host!.hostPort!,
      code: '0000',
    );
    expect(guest, isNull);
    expect(host.players.length, 1);
    host.close();
  });

  testWidgets('la barre du duel montre les amis, s\'ouvre d\'un toucher et l\'écran de fin tient sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late DuelNet host, guest;
    await tester.runAsync(() async {
      host = (await DuelNet.host(
        myId: 'host-0000009',
        myName: 'Hôte',
        rules: const DuelRules(stake: 'un repas'),
      ))!;
      guest = (await DuelNet.join(
        myId: 'guest-000009',
        myName: 'Invité',
        address: '127.0.0.1',
        port: host.hostPort!,
        code: host.code,
      ))!;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      host.launch();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    final game = ChachaGame(aircraftById('dc6'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DuelOverlay(net: host, game: game, pauseLeft: ValueNotifier<int?>(42), onQuit: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Pause'), findsOneWidget);
    await tester.tapAt(const Offset(320, 20));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Invité'), findsOneWidget);
    // l'invité tombe : l'hôte, seul en vol, peut terminer et gagner
    await tester.runAsync(() async {
      guest.report(year: 1970, lives: 0, state: Pilot.crashed);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Terminer'), findsOneWidget);
    await tester.runAsync(() async {
      host.report(year: 1980, lives: 3, state: Pilot.won);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tu as gagné !'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      host.close();
      guest.close();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
