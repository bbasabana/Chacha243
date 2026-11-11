import 'dart:math' as math;
import 'package:chacha243/data/archive.dart';
import 'package:chacha243/data/eras.dart';
import 'package:chacha243/data/aircraft_types.dart';
import 'package:chacha243/data/history_events.dart';
import 'package:chacha243/data/war_zones.dart';
import 'package:chacha243/data/window_animals.dart';
import 'package:chacha243/game/boulevard.dart';
import 'package:chacha243/game/chacha_game.dart';
import 'package:chacha243/game/kinshasa_descent.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le jeu tourne sans écran : un vol entier en pilote automatique, une reprise sans argent, une reprise avec.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Pas de capteur d'inclinaison dans les tests : le canal répond sans rien faire.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (_) async => null,
    );
  });

  Future<ChachaGame> start({double? year, bool resumed = false, int? money, bool autopilot = false}) async {
    final g = ChachaGame(aircraftById('b737'))
      ..autopilot = autopilot
      ..startYear = year
      ..resumed = resumed
      ..startMoney = money;
    g.onGameResize(Vector2(844, 390));
    await g.onLoad();
    expect(g.size.x, 844, reason: 'taille du jeu');
    return g;
  }

  test('au premier départ, les passagers montent à bord avant le décollage', () async {
    final g = await start();
    expect(g.phase, FlightPhase.ready);
    expect(g.passengers, 0);
    g.boost = true;
    for (var i = 0; i < 180; i++) {
      g.update(1 / 60);
    }
    expect(g.phase, FlightPhase.ready, reason: 'on attend la fin de l\'embarquement');
    expect(g.passengers, greaterThan(0));
    for (var i = 0; i < 480; i++) {
      g.update(1 / 60);
    }
    expect(g.phase, isNot(FlightPhase.ready));
    expect(g.passengers, (g.type.seats * 0.55).round());
  });

  test('repris au sol sans argent, le voyage s\'arrête : seul « recommencer » reste', () async {
    final g = await start(year: 1998.3, resumed: true, money: 96);
    expect(g.phase, FlightPhase.ready);
    expect(g.fuel, lessThan(50));
    expect(g.stranded, isTrue);
  });

  test('au sol, « Kerozene ezali ya ko sila » part dès qu\'on le touche, et le bouton du plein revient', () async {
    final g = await start(year: 1998.3, resumed: true, money: 5000);
    g.boost = true;
    for (var i = 0; i < 10; i++) {
      g.update(1 / 60);
    }
    expect(g.radio.value?.lingala, Lingala.mafuta);
    g.skipMessage();
    g.update(1 / 60);
    expect(g.radio.value, isNull);
  });

  test('l\'avion reste aux couleurs du Zaïre jusqu\'à l\'AFDL, puis prend celles de la RDC', () {
    expect(identical(airlineAt(1996.9).livery, airlineAt(1980).livery), isTrue);
    expect(airlineAt(1996.9).livery.fuselageFlag, FlagStyle.zaire1971);
    expect(airlineAt(1997.5).livery.fuselageFlag, FlagStyle.star1997);
    expect(airlineAt(1997.5).headline, isNotNull);
    expect(airlineAt(2014).livery.emblem, TailEmblem.flag);
    expect(Lingala.crashes.toSet(), hasLength(3), reason: 'une pique différente à chaque crash');
  });

  test('repris au sol avec de l\'argent, on peut faire le plein et repartir', () async {
    final g = await start(year: 1998.3, resumed: true, money: 5000);
    expect(g.stranded, isFalse);
    g.buyFuel();
    for (var i = 0; i < 60 * 30; i++) {
      g.update(1 / 60);
    }
    expect(g.fuel, greaterThanOrEqualTo(50));
    expect(g.stranded, isFalse);
  });

  test('un vol en pilote automatique traverse les années sans erreur, et vite', () async {
    final g = await start(year: 1989.5, autopilot: true);
    final watch = Stopwatch()..start();
    var frames = 0;
    var late = 0.0;
    var lateTitle = '';
    g.card.addListener(() {
      final c = g.card.value;
      // Une fiche passe dans son année : jamais plus d'un an après la date de l'événement.
      if (c != null && g.year - c.event.year > late) {
        late = g.year - c.event.year;
        lateTitle =
            '${c.event.title} (${c.event.year}) en ${g.year.toStringAsFixed(2)} zone=${g.zoneHud.value?.zone.name}';
      }
    });
    while (g.year < 2002 && frames < 60 * 60 * 60) {
      // Le pilote automatique ne va pas à l'entretien : on garde l'avion entier pour traverser toutes les années.
      g.condition = 100;
      g.lives = 5;
      g.update(1 / 60);
      frames++;
      if (g.phase == FlightPhase.crashed || g.phase == FlightPhase.finished) break;
    }
    watch.stop();
    // ignore: avoid_print
    print(
      "vol : $frames images, ${g.year.toStringAsFixed(2)}, ${(watch.elapsedMicroseconds / frames).round()} µs par image, fiche en retard de ${late.toStringAsFixed(2)} an $lateTitle, phase ${g.phase.name} ${g.failWhy} état ${g.condition.round()} kérosène ${g.fuel.round()}",
    );
    // Chaque image du jeu se calcule en bien moins que les 16 ms d'un écran à 60 images par seconde.
    final perFrame = watch.elapsedMicroseconds / frames;
    expect(perFrame, lessThan(4000), reason: '$perFrame µs par image');
    expect(g.year, greaterThan(2001.5), reason: 'le vol s\'est arrêté en ${g.year} : ${g.failWhy}');
    expect(late, lessThan(1.0), reason: 'une fiche est passée $late an(s) après sa date');
  });

  test('le 30 juin 1960 se vit pas à pas : annonce, bulle, visages, objectif, ceintures', () async {
    final g = await start(autopilot: true);
    final seen = <String>[];
    var frame = 0;
    var last = '';
    void note(String what) {
      if (what == last) return;
      last = what;
      seen.add('$what @${g.year.toStringAsFixed(3)} · ${(frame / 60).round()} s');
    }

    g.banner.addListener(() => g.banner.value == null ? null : note('bannière ${g.banner.value!.title}'));
    g.turningPoint.addListener(
      () => g.turningPoint.value == null ? null : note('bulle ${g.turningPoint.value!.event.title}'),
    );
    g.radio.addListener(() => g.radio.value == null ? null : note('radio ${g.radio.value!.speaker}'));
    g.cabin.addListener(() => g.cabin.value == null ? null : note('cabine ${g.cabin.value!.title}'));
    g.zoneHud.addListener(() => g.zoneHud.value == null ? null : note('zone ${g.zoneHud.value!.zone.name}'));
    g.talk.addListener(() => g.talk.value == null ? null : note('bulle-cabine ${g.talk.value!.lines.first.french}'));
    g.card.addListener(() => g.card.value == null ? null : note('fiche ${g.card.value!.event.title}'));
    g.stagePause.addListener(() => g.stagePause.value == null ? null : note('étape ${g.stagePause.value!.title}'));
    g.cabinCamera.addListener(() => g.cabinCamera.value == null ? null : note('caméra'));
    var mixed = 0;
    for (var i = 0; i < 60 * 60 * 6 && g.zoneHud.value == null; i++) {
      g.lives = 5;
      g.update(1 / 60);
      frame++;
      if (g.cabinCamera.value != null &&
          (g.banner.value != null ||
              g.radio.value != null ||
              g.card.value != null ||
              g.turningPoint.value != null ||
              g.cabin.value != null)) {
        mixed++;
      }
      // Le pilote automatique attache les ceintures comme un vrai pilote.
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    // ignore: avoid_print
    print(seen.join("\n"));
    int at(String what) => seen.indexWhere((x) => x.contains(what));
    expect(at('étape Le Congo prend son indépendance'), greaterThanOrEqualTo(0));
    expect(at("cabine Les ceintures s'attachent"), greaterThan(at('étape Le Congo prend son indépendance')));
    expect(at('zone Sécession du Katanga'), greaterThan(at('cabine Ceintures attachées')));
    // Les ceintures ne se demandent qu'une fois avant la première guerre.
    expect(seen.where((x) => x.contains("cabine Les ceintures s'attachent")).length, 1);
    // Rien sur le Katanga avant la fin de l'Indépendance, et la guerre arrive vers une minute.
    final katanga = seen.indexWhere((x) => x.contains('Katanga'));
    expect(katanga, greaterThan(at('cabine Ceintures attachées')));
    int secondsOf(int i) => int.parse(seen[i].split('· ').last.split(' ').first);
    expect(secondsOf(katanga), lessThanOrEqualTo(120));
    // Quand les passagers parlent, rien d'autre : ils arrivent après les ceintures, avant la guerre.
    expect(mixed, 0);
    expect(at('caméra'), -1, reason: 'personne ne parle au tout début du vol');
  });

  test(
    'la guerre de l\'AFDL se raconte : ONU, Mandela, Outeniqua, refus, puis le Congo et le serment de Mzee',
    () async {
      final g = await start(year: 1996.0, autopilot: true);
      final seen = <String>[];
      final cards = <String>[];
      for (var i = 0; i < 60 * 60 * 10 && g.year < 1997.5; i++) {
        g.lives = 5;
        g.condition = 100;
        g.update(1 / 60);
        final now = g.stagePause.value?.title ?? (g.zoneHud.value?.active ?? false ? 'avions' : '');
        if (now.isNotEmpty && (seen.isEmpty || seen.last != now)) seen.add(now);
        final c = g.card.value?.event.title;
        if (c != null && (cards.isEmpty || cards.last != c)) cards.add(c);
      }
      int at(String s) => seen.indexWhere((x) => x.contains(s));
      expect(g.year, greaterThanOrEqualTo(1997.45), reason: seen.join(' > '));
      expect(at('communauté internationale'), greaterThan(at('Le Congo entre dans')), reason: seen.join(' > '));
      expect(at('Mandela, le médiateur'), greaterThan(at('communauté internationale')));
      expect(at('Outeniqua'), greaterThan(at('Mandela, le médiateur')));
      expect(at('Mobutu refuse'), greaterThan(at('Outeniqua')));
      expect(
        seen.indexOf('avions', at('Mobutu refuse')),
        greaterThan(at('Mobutu refuse')),
        reason: 'la guerre continue',
      );
      expect(at("c'est fini"), greaterThan(at('Mobutu refuse')));
      expect(cards.where((c) => c.contains('prête serment')), hasLength(1), reason: cards.join(' > '));
      expect(
        cards.indexWhere((c) => c.contains('redevient le Congo')),
        lessThan(cards.indexWhere((c) => c.contains('prête serment'))),
      );
    },
  );

  test('fin de l\'AFDL : « Debout Congolais » chante une fois, puis la chanson du franc congolais en 1998', () async {
    final g = await start(year: 1996.0, autopilot: true);
    final songs = <String>[];
    g
      ..onSong = ((key, {level, loop = false}) => songs.add(key))
      ..songBusy = (() => true);
    final cards = <String>{};
    for (var i = 0; i < 60 * 60 * 14 && g.year < 1998.9; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.card.value case final c?) cards.add(c.event.title);
    }
    expect(g.year, greaterThanOrEqualTo(1998.5));
    expect(songs.where((s) => s == 'congo'), hasLength(1), reason: songs.join(' > '));
    expect(songs, contains('monnaie'), reason: '${songs.join(' > ')} | ${cards.join(' > ')} | ${g.year}');
    expect(songs.indexOf('monnaie'), greaterThan(songs.indexOf('congo')));
  });

  test('après un crash, une fiche déjà lue ne revient pas (le serment de Mzee passe une fois)', () async {
    final e = historyEvents.firstWhere((e) => e.title.contains('Mzee Laurent-Désiré Kabila prête serment'));
    final oath = e.title;
    // Le crash est venu plus tard : la fiche et sa suite ont été lues.
    SharedPreferences.setMockInitialValues({
      'chacha243.seen': [
        for (final n in historyEvents)
          if (n.year >= e.year && n.year <= e.year + 0.3) n.title,
      ],
    });
    final g = await start(year: 1997.36, autopilot: true);
    final cards = <String>[];
    for (var i = 0; i < 60 * 60 * 3 && g.year < 1998.2; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.card.value case final c?) cards.add(c.event.title);
    }
    expect(g.year, greaterThan(1997.45));
    expect(cards, isNot(contains(oath)), reason: cards.toSet().join(' > '));
  });

  test('lue juste avant le crash, la mort de Mzee repasse avant le serment de Joseph Kabila', () async {
    final death = historyEvents.firstWhere((e) => e.title.contains('Mzee Laurent-Désiré Kabila est assassiné'));
    SharedPreferences.setMockInitialValues({
      'chacha243.seen': [
        for (final n in historyEvents)
          if (n.year <= death.year) n.title,
      ],
    });
    final g = await start(year: 2000.9, resumed: true, autopilot: true);
    final cards = <String>[];
    for (var i = 0; i < 60 * 60 * 4 && g.year < 2001.3; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      for (final c in [g.card.value?.event, g.turningPoint.value?.event]) {
        if (c != null && (cards.isEmpty || cards.last != c.title)) cards.add(c.title);
      }
    }
    final d = cards.indexOf(death.title), j = cards.indexOf('Joseph Kabila prête serment');
    expect(d, greaterThanOrEqualTo(0), reason: cards.join(' > '));
    expect(j, greaterThan(d), reason: cards.join(' > '));
  });

  test(
    'de 1961 à 2026, une reprise ne fait pas « entrer » dans une guerre déjà commencée, et les fiches restent à leur date',
    () async {
      final titles = {for (final e in historyEvents) e.title};
      final problems = <String>[];
      for (var y = 1961.0; y < 2026.6; y += 0.5) {
        // Le crash est venu un peu plus tard : tout ce qui le précède a été lu.
        SharedPreferences.setMockInitialValues({
          'chacha243.seen': [
            for (final e in historyEvents)
              if (e.year < y + 1.2) e.title,
          ],
        });
        final g = await start(year: y, resumed: true, autopilot: true);
        final shown = <(String, double, double)>[];
        void card(HistoryEvent e) => titles.contains(e.title) ? shown.add((e.title, e.year, g.year)) : null;
        g.card.addListener(() => g.card.value == null ? null : card(g.card.value!.event));
        g.turningPoint.addListener(() => g.turningPoint.value == null ? null : card(g.turningPoint.value!.event));
        g.stagePause.addListener(() {
          final title = g.stagePause.value?.title ?? '';
          if (!title.startsWith('Le Congo entre dans : ')) return;
          final z = warZones.where((z) => title.endsWith(z.name)).firstOrNull;
          if (z != null && y > z.from + 0.02) problems.add('reprise $y : « $title » en ${g.year.toStringAsFixed(2)}');
        });
        for (var i = 0; i < 60 * 60 * 6 && g.year < y + 2; i++) {
          g.lives = 5;
          g.condition = 100;
          g.fuel = 80;
          g.update(1 / 60);
          if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
          if (g.phase == FlightPhase.crashed || g.phase == FlightPhase.finished) break;
        }
        var last = 0.0;
        for (final (title, ey, at) in shown) {
          if (at < ey - 0.08) problems.add('reprise $y : « $title » ($ey) trop tôt, en ${at.toStringAsFixed(2)}');
          if (at > ey + 0.7) problems.add('reprise $y : « $title » ($ey) trop tard, en ${at.toStringAsFixed(2)}');
          if (ey < last - 0.01) problems.add('reprise $y : « $title » ($ey) après une fiche de $last');
          last = ey;
        }
      }
      expect(problems, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  test(
    '1998 : le franc et la rupture avant la guerre, puis le RCD, l\'Angola, Lusaka ; 2001 : Mzee, l\'intérim, Joseph',
    () async {
      final g = await start(year: 1997.9, autopilot: true);
      final said = <String>[];
      void add(String s) => said.contains(s) ? null : said.add(s);
      for (var i = 0; i < 60 * 60 * 30 && g.year < 2001.3; i++) {
        g.lives = 5;
        g.condition = 100;
        g.fuel = 80;
        g.update(1 / 60);
        if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
        if (g.card.value case final c?) add(c.event.title);
        if (g.turningPoint.value case final c?) add(c.event.title);
        if (g.stagePause.value case final p? when p.title.contains('Deuxième guerre')) add(p.title);
      }
      final order = [
        'Retour du franc congolais',
        'Kabila renvoie ses anciens alliés',
        'Le Congo entre dans : Deuxième guerre du Congo',
        'Le RCD naît à Goma',
        'L\'Angola et le Zimbabwe au secours de Kinshasa',
        'Le cessez-le-feu de Lusaka',
        'Mzee Laurent-Désiré Kabila est assassiné',
        'Qui succède à Mzee ?',
        'Joseph Kabila prête serment',
      ];
      final at = [for (final o in order) said.indexOf(o)];
      expect(at, isNot(contains(-1)), reason: said.join(' > '));
      for (var i = 1; i < at.length; i++) {
        expect(at[i], greaterThan(at[i - 1]), reason: said.join(' > '));
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('à Kinshasa, on survole le stade, le boulevard puis N\'djili, et on se pose sur le tarmac', () async {
    final g = await start(year: 2025.6, autopilot: true);
    for (var i = 0; i < 60 * 4; i++) {
      g.update(1 / 60);
    }
    g.landAt('Kinshasa');
    final said = <String>[];
    g.radio.addListener(() {
      final r = g.radio.value;
      if (r != null && r.speaker == 'Tour de Kinshasa') said.add(r.french);
    });
    for (var i = 0; i < 60 * 45 && g.phase != FlightPhase.ground; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
    }
    expect(g.phase, FlightPhase.ground, reason: said.join(' > '));
    expect(said.take(3), [
      KinshasaDescent.stadiumLine(g.year),
      KinshasaDescent.roadLine(g.year),
      KinshasaDescent.airportLine(g.year),
    ]);
    expect(said, contains(contains('Piste en vue')));
  });

  test(
    'le survol de Kinshasa suit les années : stade des Martyrs en 1994, passerelle en 2015, saut-de-mouton en 2020',
    () {
      expect(KinshasaDescent.stadiumLine(1965), contains('Roi Baudouin'));
      expect(KinshasaDescent.stadiumLine(1980), contains('20 Mai'));
      expect(KinshasaDescent.stadiumLine(2010), contains('Martyrs'));
      expect(KinshasaDescent.roadLine(2010), isNot(contains('passerelle')));
      expect(KinshasaDescent.roadLine(2016), contains('passerelle'));
      expect(KinshasaDescent.roadLine(2016), isNot(contains('saut-de-mouton')));
      expect(KinshasaDescent.roadLine(2024), contains('saut-de-mouton'));
      expect(KinshasaDescent.airportLine(2010), isNot(contains('orange')));
      expect(KinshasaDescent.airportLine(2016), contains('orange'));
    },
  );

  test('la guerre se joue par étapes : pause, combat, acclamation, étape suivante', () async {
    final g = await start(year: 1960.52, resumed: true, autopilot: true);
    final seen = <String>[];
    final sounds = <String>[];
    g.onSound = sounds.add;
    var noise = 0;
    final noisy = <String>{};
    for (var i = 0; i < 60 * 240; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      final attack = g.zoneHud.value?.active ?? false;
      // Seule l'alerte du kit d'entretien reste : sans elle, l'avion tombe sans prévenir.
      final alert = g.banner.value?.title.startsWith('Kit') ?? false;
      if (attack &&
          ((g.banner.value != null && !alert) || g.cabinCamera.value != null || (g.card.value?.event.war ?? false))) {
        noise++;
        noisy.add('${g.banner.value?.title}|${g.cabinCamera.value != null}|${g.card.value?.event.title}');
      }
      final now = g.stagePause.value?.title ?? (attack ? 'avions' : '');
      if (now.isNotEmpty && (seen.isEmpty || seen.last != now)) seen.add(now);
    }
    // ignore: avoid_print
    print(seen.join(' > '));
    // Le tableau de bord se rafraîchit avec quelques images de retard.
    expect(noise, lessThan(30), reason: '$noisy');
    final enter = seen.indexOf('Le Congo entre dans : Sécession du Katanga');
    final won = seen.indexOf('Sécession du Katanga : c\'est fini');
    final next = seen.indexOf('Le Congo entre dans : Sécession du Sud-Kasaï');
    expect(enter, greaterThanOrEqualTo(0));
    expect(seen.indexOf('avions'), greaterThan(enter));
    expect(won, greaterThan(seen.indexOf('avions')));
    expect(next, won + 1);
    expect(seen.indexOf('avions', next), greaterThan(next));
    expect(seen.indexOf('Sécession du Sud-Kasaï : c\'est fini'), greaterThan(next));
    expect(sounds.where((x) => x == 'acclamation').length, greaterThanOrEqualTo(2));
  });

  test('aucune proposition de descente avant 1962, ni pendant que les passagers parlent', () async {
    final g = await start(year: 1960.52, resumed: true, autopilot: true);
    final offers = <double>[];
    var mixed = 0;
    g.radio.addListener(() {
      if (g.radio.value?.offer != null && g.radio.value!.french.startsWith('Mission')) offers.add(g.year);
    });
    var talked = false;
    for (var i = 0; i < 60 * 60 * 6 && g.year < 1964; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      if (g.cabinCamera.value != null) {
        talked = true;
        if (g.radio.value != null || g.banner.value != null || g.card.value != null) mixed++;
      }
    }
    expect(talked, isTrue);
    expect(mixed, 0);
    expect(offers.where((y) => y < 1962), isEmpty, reason: '$offers');
  });

  test('Air Congo naît en 1961 dans un ciel calme, les avions de chasse reviennent après', () async {
    final g = await start(year: 1961.3, autopilot: true);
    var frame = 0;
    int? born;
    int? jetsBack;
    g.banner.addListener(() {
      if (born == null && (g.banner.value?.title.contains('Air Congo') ?? false)) born = frame;
    });
    for (var i = 0; i < 60 * 60 * 6 && g.year < 1962; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      frame++;
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      if (born != null && jetsBack == null && (g.zoneHud.value?.active ?? false)) jetsBack = frame;
    }
    expect(born, isNotNull, reason: 'Air Congo n\'a pas été annoncée');
    expect(jetsBack, isNotNull, reason: 'les avions de chasse ne sont pas revenus');
    // ignore: avoid_print
    final calm = jetsBack! - born!;
    // ignore: avoid_print
    print('Air Congo à ${born! ~/ 60} s, avions de chasse ${calm ~/ 60} s après');
    expect(calm, greaterThanOrEqualTo(60 * 10));
  });

  test('un crash en pleine guerre reprend à l\'année atteinte, pas au début de la guerre', () async {
    final g = await start(year: 1961.3, autopilot: true);
    for (var i = 0; i < 60 * 60 * 8 && g.year < 1962.3; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    expect(g.zoneHud.value?.zone.name, 'Sécession du Katanga');
    expect(g.checkpoint.value?.year.floor(), 1962);

    // La reprise en 1962 repart au milieu de la sécession, avec les vagues déjà passées.
    final again = await start(year: 1962.0, autopilot: true);
    for (var i = 0; i < 60 * 40 && again.zoneHud.value == null; i++) {
      again.update(1 / 60);
      if (again.cabin.value?.mode == CabinMode.beltsAsk) again.fastenBelts();
    }
    expect(again.zoneHud.value?.zone.name, 'Sécession du Katanga');
    expect(again.zoneHud.value!.wave, greaterThan(1));
    expect(again.year, greaterThanOrEqualTo(1962));
  });

  test('après un crash, la musique revient dès le sol : la chanson de l\'époque, puis Indépendance', () async {
    final g = await start(year: 1966.2, resumed: true, money: 5000);
    final songs = <String>[];
    g
      ..onSong = ((key, {level, loop = false}) => songs.add(key))
      ..songBusy = (() => false);
    for (var i = 0; i < 60 * 12; i++) {
      g.update(1 / 60);
    }
    expect(g.phase, FlightPhase.ready);
    expect(songs, isNotEmpty, reason: 'aucune chanson au sol après la reprise');
    expect(songs, everyElement('fond'));
  });

  test('Mario pour Franco en 1989, le chant pour Mobutu le temps de son émotion, puis une autre chanson', () async {
    final g = await start(year: 1989.6, autopilot: true);
    final songs = <String>[];
    var until = 0.0, clock = 0.0;
    g
      ..onSong = ((key, {level, loop = false}) {
        songs.add(key);
        until = clock + (momentSongs[key]?.seconds ?? 40);
      })
      ..songBusy = (() => clock < until);
    for (var i = 0; i < 60 * 120 && g.year < 1991.6; i++) {
      clock += 1 / 60;
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    final mario = songs.indexOf('mario'), desire = songs.indexOf('desire');
    expect(mario, greaterThanOrEqualTo(0), reason: '$songs');
    expect(desire, greaterThan(mario), reason: '$songs');
    expect(songs.skip(desire + 1), isNotEmpty, reason: 'le silence après le chant : $songs');
    expect(songs.skip(desire + 1), isNot(contains('desire')), reason: '$songs');
  });

  test('dans une guerre, le silence ne dure pas : la louange réconforte', () async {
    final g = await start(year: 1962.0, autopilot: true);
    final songs = <String>[];
    var playing = false;
    g
      ..onSong = ((key, {level, loop = false}) {
        songs.add('${g.atWar ? 'guerre:' : ''}$key');
        playing = true;
      })
      ..onHush = (() => playing = false)
      ..songBusy = (() => playing);
    var silent = 0.0, longest = 0.0;
    for (var i = 0; i < 60 * 90; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      // Chaque chanson « joue » 20 secondes dans ce test.
      if (playing && songs.isNotEmpty) silent = 0;
      // Au sol, pendant une escale, l'aéroport a ses propres bruits : on ne compte que le vol.
      if (!playing && g.phase != FlightPhase.ground) longest = math.max(longest, silent += 1 / 60);
      if (i % (60 * 20) == 0) playing = false;
    }
    expect(songs.where((s) => s.startsWith('guerre:')), contains('guerre:louange'));
    expect(songs.where((s) => s.startsWith('guerre:') && s != 'guerre:louange'), isEmpty);
    expect(longest, lessThan(12), reason: 'trop de silence');
  });

  test('de 1985 à 2008, chaque fiche s\'affiche dans son année, et dans l\'ordre', () async {
    final g = await start(year: 1985.0, autopilot: true);
    final wrong = <String>[];
    final shown = <String>[];
    final banners = <String>[];
    g.banner.addListener(() {
      final b = g.banner.value;
      if (b != null && b.title.startsWith('Bientôt 2') && g.year.floor() >= int.parse(b.title.substring(8))) {
        banners.add('${b.title} en ${g.year}');
      }
    });
    void check(HistoryEvent e) {
      if (shown.contains(e.title)) return;
      shown.add(e.title);
      if (g.year.floor() != e.year.floor()) {
        wrong.add('${e.title} (${e.year}) affichée en ${g.year.toStringAsFixed(2)}');
      }
    }

    g.card.addListener(() => g.card.value == null ? null : check(g.card.value!.event));
    g.turningPoint.addListener(() => g.turningPoint.value == null ? null : check(g.turningPoint.value!.event));
    for (var i = 0; i < 60 * 60 * 120 && g.year < 2008; i++) {
      g.condition = 100;
      g.lives = 5;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      if (g.phase == FlightPhase.crashed || g.phase == FlightPhase.finished) break;
    }
    // ignore: avoid_print
    print('fiches : ${shown.join(' · ')}');
    expect(g.year, greaterThanOrEqualTo(2008), reason: 'le vol s\'est arrêté en ${g.year} ${g.failWhy} ${g.phase}');
    expect(wrong, isEmpty);
    expect(banners, isEmpty);
    for (final t in [
      'Franco Luambo Makiadi nous quitte',
      '« Comprenez mon émotion »',
      'Les pillages',
      'Mzee Laurent-Désiré Kabila prête serment',
      'Mzee Laurent-Désiré Kabila est assassiné',
      'Joseph Kabila prête serment',
      'Kabila renvoie ses anciens alliés',
      'Jean-Pierre Bemba et le MLC',
      'L\'accord global de Pretoria',
      'Kabila face à Bemba',
      'Antoine Gizenga, Premier ministre',
    ]) {
      expect(shown, contains(t));
    }
    expect(
      shown.indexOf('Mzee Laurent-Désiré Kabila est assassiné'),
      lessThan(shown.indexOf('Joseph Kabila prête serment')),
    );
  });

  test('de 1965 à 1985, les fiches restent dans leur année, et le MPR et Ali ont leur chanson', () async {
    final g = await start(year: 1965.5, autopilot: true);
    final wrong = <String>[];
    final shown = <String>{};
    final songs = <String>[];
    g.onSong = ((key, {level, loop = false}) => songs.add(key));
    void check(HistoryEvent e) {
      if (!shown.add(e.title)) return;
      if (g.year.floor() != e.year.floor()) {
        wrong.add('${e.title} (${e.year}) affichée en ${g.year.toStringAsFixed(2)}');
      }
    }

    g.card.addListener(() => g.card.value == null ? null : check(g.card.value!.event));
    g.turningPoint.addListener(() => g.turningPoint.value == null ? null : check(g.turningPoint.value!.event));
    for (var i = 0; i < 60 * 60 * 90 && g.year < 1985; i++) {
      g.condition = 100;
      g.lives = 5;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      if (g.phase == FlightPhase.crashed || g.phase == FlightPhase.finished) break;
    }
    expect(g.year, greaterThanOrEqualTo(1985), reason: 'le vol s\'est arrêté en ${g.year}');
    expect(wrong, isEmpty);
    expect(shown, containsAll(['Naissance du MPR', 'Ali – Foreman']));
    expect(songs, containsAll(['mpr', 'bomaye']));
  });

  for (final (from, name) in [(1976.9, 'Guerres du Shaba'), (1996.5, 'AFDL')]) {
    test('dans la guerre « $name », deux kits d\'entretien viennent toujours', () async {
      final g = await start(year: from, autopilot: true);
      var kits = 0, before = 0, inZone = false;
      for (var i = 0; i < 60 * 60 * 12; i++) {
        g.lives = 5;
        g.condition = 100;
        g.fuel = 90;
        g.update(1 / 60);
        if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
        if (g.atWar && !inZone) {
          inZone = true;
          before = g.kitsOffered;
        }
        if (inZone && !g.atWar) break;
        if (inZone) kits = g.kitsOffered - before;
      }
      expect(inZone, isTrue);
      expect(kits, greaterThanOrEqualTo(2));
    });
  }

  test('l\'avion abîmé est signalé à 25, 20 et 10 % : kit bleu ou entretien', () async {
    final g = await start(year: 1970.0, autopilot: true);
    final alerts = <String>[];
    g.banner.addListener(() {
      final b = g.banner.value;
      if (b != null && (b.title.startsWith('État de l\'avion') || b.title.startsWith('Danger'))) alerts.add(b.title);
    });
    // Le kit arrive vite et répare l'avion : on regarde chaque seuil quelques secondes seulement.
    for (var i = 0; i < 60 * 20; i++) {
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    for (final level in [24.0, 19.0, 9.0]) {
      // Pendant un entretien (kit pris), on ne prévient pas : on attend la fin, puis on remet l'avion à ce seuil.
      g.condition = level;
      for (var i = 0; i < 60 * 40 && !alerts.any((a) => a.endsWith(' ${level.round()} %')); i++) {
        g.lives = 5;
        g.invulnerable = 1;
        g.update(1 / 60);
        if (g.condition >= 99.9) g.condition = level;
        if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      }
    }
    // Les alertes passent l'une après l'autre, le temps de les lire.
    for (var i = 0; i < 60 * 25; i++) {
      g.lives = 5;
      g.update(1 / 60);
    }
    // (Pendant une réparation, on ne prévient pas : le seuil de 20 % peut tomber dans ce moment-là.)
    // Le temps que l'alerte passe, l'avion a pu s'user d'un point.
    expect(alerts.first, anyOf('État de l\'avion : 24 %', 'État de l\'avion : 23 %'));
    expect(alerts.last, 'Danger : avion à 9 %');
    expect(alerts.toSet().length, alerts.length, reason: 'une alerte répétée');
  });

  test('le quiz parle de l\'année qu\'on vit, et dit si la réponse est bonne', () async {
    final g = await start(year: 1974.5, autopilot: true);
    final asked = <String>[];
    final wrongYear = <String>[];
    final said = <String>[];
    g.quiz.addListener(() {
      final e = g.quiz.value?.event;
      if (e == null) return;
      asked.add(e.title);
      if (g.year - e.year > 1.1) wrongYear.add('${e.title} en ${g.year.toStringAsFixed(2)}');
    });
    g.banner.addListener(() {
      final b = g.banner.value;
      if (b != null && (b.title == 'Bonne réponse !' || b.title == 'Mauvaise réponse')) said.add(b.title);
    });
    for (var i = 0; i < 60 * 60 * 10 && g.year < 1977; i++) {
      g.lives = 5;
      g.condition = 100;
      if (i % (60 * 20) == 0) g.quizNow = true;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    expect(asked, isNotEmpty);
    expect(wrongYear, isEmpty);
    expect(said, isNotEmpty);
    expect(historyEvents.firstWhere((e) => e.title == 'Ali – Foreman').photo2, 'aliforeman');
  });

  test('de 1970 à 1979, la cabine mange et boit après la guerre', () async {
    final g = await start(year: 1970.0, autopilot: true);
    g.passengers = 80;
    var meals = 0, drinks = 0;
    g.meal.addListener(() => g.meal.value != null ? meals++ : null);
    g.cabin.addListener(() {
      if (g.cabin.value?.title.endsWith(' servis') ?? false) drinks++;
    });
    for (var i = 0; i < 60 * 60 * 30 && g.year < 1979; i++) {
      g.lives = 5;
      g.condition = 100;
      if (g.passengers < 40) g.passengers = 80;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
      if (g.phase == FlightPhase.crashed) break;
    }
    // ignore: avoid_print
    print('repas $meals, eau et café $drinks, en ${g.year.toStringAsFixed(2)}');
    expect(g.year, greaterThanOrEqualTo(1979));
    expect(meals, greaterThanOrEqualTo(1));
    expect(drinks, greaterThanOrEqualTo(1));
  });

  test('dès le deuxième repas, « Boko lia te » ferme le menu : personne ne mange aujourd\'hui', () async {
    final g = await start(year: 1970.0, autopilot: true)
      ..showcase = 'repas';
    g.passengers = 80;
    final offers = <MealOffer>[];
    final said = <String>[];
    g.meal.addListener(() {
      final m = g.meal.value;
      if (m == null) return;
      offers.add(m);
      if (m.canRefuse) {
        g.refuseMeal();
      } else {
        g.serveMeal('Fufu', 'Poisson grillé', ['Fanta']);
      }
    });
    g.radio.addListener(() => g.radio.value != null ? said.add(g.radio.value!.lingala) : null);
    for (var i = 0; i < 60 * 60 * 15 && offers.length < 3; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    for (var i = 0; i < 60 * 20; i++) {
      g.lives = 5;
      g.update(1 / 60);
    }
    expect(offers.length, greaterThanOrEqualTo(2));
    expect(offers.first.canRefuse, isFalse, reason: 'le premier repas est toujours servi');
    expect(offers[1].canRefuse, isTrue);
    expect(said, contains(Lingala.bokoliate));
  });

  test('2001 : la mort de Mzee passe avant le médaillon de Joseph Kabila, et le procès de 2003 suit', () async {
    final g = await start(year: 2000.2, autopilot: true);
    g.passengers = 80;
    final seen = <String>[];
    g.card.addListener(() => g.card.value != null ? seen.add(g.card.value!.event.title) : null);
    g.banner.addListener(() => g.banner.value != null ? seen.add(g.banner.value!.title) : null);
    for (var i = 0; i < 60 * 600 && g.year < 2003.45; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    final death = seen.indexOf('Mzee Laurent-Désiré Kabila est assassiné');
    final joseph = seen.indexOf('Joseph Kabila prête serment');
    expect(death, greaterThanOrEqualTo(0), reason: '$seen');
    expect(joseph, greaterThan(death), reason: '$seen');
    expect(seen.indexOf('Le procès de l\'assassinat de Mzee'), greaterThan(joseph), reason: '$seen');
  });

  test('dans les années calmes, la tour propose d\'aller chercher des passagers', () async {
    final g = await start(year: 1964.0, autopilot: true);
    final missions = <String>[];
    g.radio.addListener(() {
      final r = g.radio.value;
      if (r != null && r.offer != null && r.french.startsWith('Mission')) missions.add('${g.year.floor()} ${r.french}');
    });
    for (var i = 0; i < 60 * 60 * 30 && g.year < 1971.0; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    expect(g.year, greaterThanOrEqualTo(1971.0));
    expect(missions.length, greaterThanOrEqualTo(1), reason: '$missions');
  });

  test('les deux Coupes d\'Afrique passent, avec leurs ballons, le fleuve et le hublot dans le ciel libre', () async {
    final g = await start(year: 1967.7, autopilot: true);
    final cards = <String>[];
    final banners = <String>[];
    final animals = <String>[];
    g.card.addListener(() {
      final c = g.card.value;
      if (c != null) cards.add(c.event.title);
    });
    g.banner.addListener(() {
      final b = g.banner.value;
      if (b != null) banners.add(b.title);
    });
    g.windowView.addListener(() {
      final a = g.windowView.value;
      if (a != null) animals.add(a.name);
    });
    for (var i = 0; i < 60 * 60 * 30 && g.year < 1975.5; i++) {
      g.lives = 5;
      g.condition = 100;
      g.update(1 / 60);
    }
    expect(g.year, greaterThanOrEqualTo(1975.5), reason: '${g.year} ${g.failWhy}');
    expect(cards, contains('Champions d\'Afrique'), reason: '$cards');
    expect(cards, contains('Deuxième titre africain'), reason: '$cards');
    expect(cards.indexOf('Champions d\'Afrique'), lessThan(cards.indexOf('Deuxième titre africain')));
    expect(banners, contains('Le fleuve Congo'), reason: '$banners');
    expect(animals, isNotEmpty);
  });

  test('le Nyiragongo : en altitude on passe, trop bas l\'avion prend feu', () async {
    Future<ChachaGame> flyOver(double heightRatio) async {
      final g = await start(year: 2001.9, autopilot: false);
      g.boost = true;
      for (var i = 0; i < 60 * 40 && g.phase != FlightPhase.cruising; i++) {
        g.update(1 / 60);
      }
      g.lives = 5;
      for (var i = 0; i < 60 * 150 && g.year < 2003.0 && g.phase == FlightPhase.cruising; i++) {
        g.condition = 100;
        g.fuel = 100;
        g.touchTarget = Offset(g.size.x * 0.26, g.size.y * heightRatio);
        g.update(1 / 60);
      }
      return g;
    }

    final high = await flyOver(0.2);
    expect(high.failWhy, isNot(contains('Nyiragongo')), reason: high.failWhy);
    final low = await flyOver(0.85);
    expect(low.phase, FlightPhase.crashed, reason: 'année ${low.year}');
    expect(low.failWhy, contains('Nyiragongo'));
  });
  test('la descente sur le boulevard Lumumba : treize répliques lentes, puis l\'avion remonte', () async {
    final g = await start(year: 1997.6, autopilot: true)
      ..showcase = 'boulevard';
    final lines = <SceneLine>[];
    final at = <double>[];
    var clock = 0.0, lowest = 0.0, endY = 1.0, sawScene = false, hidden = false;
    final sounds = <String>[];
    g.onSound = sounds.add;
    g.sceneLine.addListener(() {
      if (g.sceneLine.value case final l?) {
        lines.add(l);
        at.add(clock);
      }
    });
    for (var i = 0; i < 60 * 96; i++) {
      g.update(1 / 60);
      clock += 1 / 60;
      if (g.onBoulevard) {
        endY = g.planeY / g.size.y;
        sawScene = true;
        lowest = math.max(lowest, g.planeY / g.size.y);
        expect(g.year, closeTo(1997.6, 0.02), reason: 'le calendrier attend la fin de la scène');
        expect(g.radio.value, isNull, reason: 'rien d\'autre ne parle pendant la scène');
        expect(g.banner.value, isNull);
        hidden = hidden || (g.hud.value?.scene ?? false);
      }
    }
    expect(sawScene, isTrue);
    expect(hidden, isTrue, reason: 'le tableau de bord s\'efface pendant la scène');
    expect(g.hud.value?.scene, isFalse);
    expect(g.onBoulevard, isFalse, reason: 'la scène a une fin');
    expect(lines, hasLength(13));
    expect(lines.map((l) => l.voice), contains(SceneVoice.street), reason: 'le motard parle');
    for (var i = 1; i < at.length; i++) {
      expect(at[i] - at[i - 1], greaterThanOrEqualTo(5), reason: 'cinq à six secondes entre deux répliques');
    }
    expect(lines.map((l) => l.text), contains('Na tuta wewa oyo ! Ba yebaka ko kumba te'));
    expect(lines.map((l) => l.text), contains('Tuta ye Papa ! Ba wewa pardon'));
    expect(lines.map((l) => l.text), contains('Keba 207, Esprit de mort !'));
    expect(lowest, greaterThan(0.66), reason: 'l\'avion rase le boulevard');
    expect(endY, lessThan(0.5), reason: 'puis il remonte');
    expect(sounds, containsAll(['choc', 'klaxon']));
    expect(g.phase, FlightPhase.cruising);
    expect(g.lives, greaterThan(0));
    expect(g.sceneLine.value, isNull);
  });

  test(
    'en 1990, la descente du robot roulage : plus courte, le 207, le Wewa, la maman, le roulage, puis on remonte',
    () async {
      final g = await start(year: 1990.85, autopilot: true)
        ..showcase = 'boulevard';
      final lines = <SceneLine>[];
      final at = <double>[];
      var clock = 0.0, lowest = 0.0, endY = 1.0, began = -1.0, ended = -1.0;
      g.sceneLine.addListener(() {
        if (g.sceneLine.value case final l?) {
          lines.add(l);
          at.add(clock);
        }
      });
      for (var i = 0; i < 60 * 90; i++) {
        g.update(1 / 60);
        clock += 1 / 60;
        if (g.onBoulevard) {
          if (began < 0) began = clock;
          endY = g.planeY / g.size.y;
          lowest = math.max(lowest, g.planeY / g.size.y);
          expect(g.year, closeTo(1990.85, 0.02), reason: 'le calendrier attend la fin de la scène');
        } else if (began >= 0 && ended < 0) {
          ended = clock;
        }
      }
      expect(ended - began, lessThan(72), reason: 'plus courte que les deux autres');
      expect(lines, hasLength(11));
      expect(lines.map((l) => l.voice), containsAll([SceneVoice.bus, SceneVoice.street, SceneVoice.police]));
      for (var i = 1; i < at.length; i++) {
        expect(at[i] - at[i - 1], greaterThanOrEqualTo(5), reason: 'le temps de lire chaque réplique');
      }
      final said = lines.map((l) => l.text).join('\n');
      for (final words in [
        'Tozo kita na Boulevard Lumumba',
        'Eza normal te avion akita awa',
        'epesa santa kindoki',
        'Eza te',
        'Type K ya mibale',
        'Jésus Marie Joseph',
        'kitisa nga awa na 12ème',
        'kende CNPP',
        'bazo sambela',
      ]) {
        expect(said, contains(words));
      }
      expect(lowest, greaterThan(0.66), reason: 'l\'avion rase le boulevard');
      expect(endY, lessThan(0.5), reason: 'puis il remonte');
      expect(g.lives, greaterThan(0));
    },
  );

  test('trois descentes dans le voyage, chacune disposée autrement', () {
    expect(ChachaGame.boulevardYears, [1963.5, 1990.9, 1997.7]);
    expect(Boulevard.plans, hasLength(3));
    expect(Boulevard.plans[1].robotAt, isNotNull, reason: 'le robot roulage est au rond-point de 1990');
    expect(Boulevard.plans.map((p) => p.wewaStop).toSet(), hasLength(3), reason: 'le Wewa n\'est pas au même endroit');
  });

  test('en 1963, après les sécessions, la descente arrive une seule fois ; le pilote automatique la saute', () async {
    final g = await start(year: 1963.42);
    var seen = 0, was = false;
    for (var i = 0; i < 60 * 110; i++) {
      // Personne ne pilote : le réservoir reste plein, pour que rien d'autre n'arrête le vol.
      g.fuel = 100;
      g.update(1 / 60);
      if (g.onBoulevard && !was) seen++;
      was = g.onBoulevard;
    }
    expect(seen, 1);
    expect(g.year, greaterThan(1963.52), reason: 'après la scène, le calendrier repart');
    expect(g.meal.value, isNull, reason: 'pas de repas collé à la scène');
    expect(g.phase, FlightPhase.cruising);

    final auto = await start(year: 1963.42, autopilot: true);
    for (var i = 0; i < 60 * 40; i++) {
      auto.update(1 / 60);
      expect(auto.onBoulevard, isFalse);
    }
  });

  test('un animal vu par le hublot amène sa question « vrai ou faux » (l\'okapi ne vit qu\'en RDC)', () async {
    final g = await start(year: 1963.8, autopilot: true);
    for (final a in WindowAnimal.values) {
      g.sawThroughWindow(a);
    }
    final asked = <String>[];
    for (var k = 0; k < 10; k++) {
      g.quizNow = true;
      for (var i = 0; i < 60 * 12 && g.quiz.value == null; i++) {
        g.fuel = 60;
        g.update(1 / 60);
      }
      final q = g.quiz.value;
      if (q == null) continue;
      asked.add(q.question);
      if (q.options.length == 2) {
        expect(q.options, ['Vrai', 'Faux']);
        expect(q.why, isNotNull);
      }
      g.answerQuiz(q.answer);
    }
    expect(asked.where((q) => natureQuizzes.any((n) => n.question == q)), isNotEmpty, reason: asked.join(' | '));
    expect(natureQuizzes.first.isTrue, isTrue, reason: 'l\'okapi ne vit qu\'en RDC');
  });
}
