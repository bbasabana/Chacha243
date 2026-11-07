import 'dart:math' as math;
import 'package:chacha243/data/aircraft_types.dart';
import 'package:chacha243/game/chacha_game.dart';
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

  test('repris au sol sans argent, le voyage s\'arrête : seul « recommencer » reste', () async {
    final g = await start(year: 1998.3, resumed: true, money: 96);
    expect(g.phase, FlightPhase.ready);
    expect(g.fuel, lessThan(50));
    expect(g.stranded, isTrue);
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
    for (var i = 0; i < 60 * 60 * 4 && g.zoneHud.value == null; i++) {
      g.lives = 5;
      g.update(1 / 60);
      frame++;
      // Le pilote automatique attache les ceintures comme un vrai pilote.
      if (g.cabin.value?.mode == CabinMode.beltsAsk) g.fastenBelts();
    }
    // ignore: avoid_print
    print(seen.join("\n"));
    int at(String what) => seen.indexWhere((x) => x.contains(what));
    expect(at('L\'indépendance du Congo arrive'), greaterThanOrEqualTo(0));
    expect(at('bulle Indépendance du Congo'), greaterThan(at('L\'indépendance du Congo arrive')));
    expect(at('Lumumba et Kasa-Vubu') < 0 || at('Indépendance · 30 juin') > at('bulle'), isTrue);
    expect(at('radio Commandant de bord'), greaterThan(at('bulle Indépendance du Congo')));
    expect(at('cabine Attachez vos ceintures'), greaterThan(at('radio Commandant de bord')));
    expect(at('zone Sécession du Katanga'), greaterThan(at('cabine Ceintures attachées')));
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
    expect(songs.first, 'okjazz');
    expect(songs.skip(1), everyElement('fond'));
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
      if (!playing) longest = math.max(longest, silent += 1 / 60);
      if (i % (60 * 20) == 0) playing = false;
    }
    expect(songs.where((s) => s.startsWith('guerre:')), contains('guerre:louange'));
    expect(songs.where((s) => s.startsWith('guerre:') && s != 'guerre:louange'), isEmpty);
    expect(longest, lessThan(7), reason: 'trop de silence');
  });
}
