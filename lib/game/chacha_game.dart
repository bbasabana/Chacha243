import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/aircraft_types.dart';
import '../app_state.dart';
import '../data/airports.dart';
import '../data/archive.dart';
import '../data/cabin_talk.dart';
import '../data/eras.dart';
import '../data/history_events.dart';
import '../data/war_zones.dart';
import '../painting/aircraft_painter.dart';
import '../theme/chacha_colors.dart';
import 'checkpoint.dart';
import 'scenery.dart';
import 'tilt_control.dart';

enum FlightPhase { ready, rolling, climbing, cruising, approach, ground, crashed, finished }

class HudState {
  const HudState({
    required this.phase,
    required this.year,
    required this.airline,
    required this.flag,
    required this.lives,
    required this.score,
    required this.fuel,
    required this.speed,
    required this.magnetReady,
    required this.medals,
    required this.tiltAvailable,
    required this.altitude,
    required this.speedKmh,
    required this.pitch,
    required this.condition,
    required this.inZone,
    required this.airport,
    required this.firstFlight,
    required this.passengers,
    required this.seats,
    required this.money,
    required this.currency,
    this.finale = false,
  });

  final FlightPhase phase;
  final double year;
  final String airline;
  final FlagStyle flag;
  final int lives;
  final int score;
  final double fuel;
  final double speed;
  final double magnetReady;
  final int medals;
  final bool tiltAvailable;

  /// Tableau de bord : altitude en pieds, vitesse, assiette (radians), état de l'avion (0-100).
  final double altitude;
  final double speedKmh;
  final double pitch;
  final double condition;
  final bool inZone;

  /// L'aéroport où l'avion est posé (« Kisangani · Bangoka »).
  final String airport;
  final bool firstFlight;

  final int passengers;
  final int seats;

  /// L'argent gagné en vol, dans la monnaie de l'époque (F, Z, NZ, FC).
  final int money;
  final String currency;

  /// La dernière ligne droite : les mois défilent jusqu'au 30 juin 2027.
  final bool finale;
}

/// Une conversation dans la cabine : deux ou trois répliques, en lingala et en français.
class CabinTalk {
  const CabinTalk(this.lines);

  final List<TalkLine> lines;
}

/// La fiche de l'avion, glissée à l'écran au départ et à chaque changement d'avion.
class PlaneCard {
  const PlaneCard(this.type, this.airline, this.passengers, this.title);

  final AircraftType type;
  final String airline;
  final int passengers;
  final String title;
}

/// Une mission : prendre des passagers dans une ville et les déposer dans une autre.
class Mission {
  Mission(this.from, this.to, this.count, this.why);

  final Airport from, to;
  final int count;

  /// Ce qui rend l'arrivée difficile (« Goma : guerre et volcan »), ou vide.
  final String why;
  bool boarded = false;
  int hits = 0;

  int get stars => (3 - hits).clamp(1, 3);
}

/// Une question d'histoire contre du kérosène.
class Quiz {
  const Quiz(this.question, this.options, this.answer, this.event);

  final String question;
  final List<String> options;
  final int answer;
  final HistoryEvent event;
}

/// Ce qui se passe dans la cabine : le signal des ceintures, ou le service du repas.
enum CabinMode { beltsAsk, beltsFastening, beltsDone, serving, served }

class CabinHud {
  const CabinHud(this.mode, this.progress, this.seats, this.title, this.detail);

  final CabinMode mode;

  /// Avancement de l'animation (ceintures qui se bouclent, chariot qui passe), de 0 à 1.
  final double progress;
  final int seats;
  final String title, detail;
}

/// Le menu du repas à bord, proposé au pilote ; le vol attend son choix.
class MealOffer {
  const MealOffer(this.passengers);

  final int passengers;
}

/// Un grand tournant : le drapeau d'avant, celui d'après.
class TurningPoint {
  const TurningPoint(this.event, this.before, this.after);

  final HistoryEvent event;
  final FlagStyle before, after;
}

/// Un message de la tour de contrôle : la phrase en lingala, puis sa traduction.
class RadioCall {
  const RadioCall(this.speaker, this.lingala, this.french, {this.offer});

  final String speaker;
  final String lingala;
  final String french;

  /// Une escale proposée : le nom de l'aéroport sur le bouton « Descendre ».
  final String? offer;
}

/// L'escale au sol : le plein, l'entretien, les contrôles.
class StopoverHud {
  const StopoverHud(
    this.airport,
    this.fuel,
    this.repair,
    this.checks,
    this.step, {
    this.rescue = false,
    this.boarding,
    this.boardingLabel = '',
    this.fleet = const [],
    this.current,
    this.bill = '',
  });

  final String airport;
  final double fuel, repair, checks;
  final String step;
  final bool rescue;

  /// Embarquement ou débarquement des passagers d'une mission (null : pas de mission ici).
  final double? boarding;
  final String boardingLabel;

  /// Les avions de l'époque, au choix pendant l'escale.
  final List<AircraftType> fleet;
  final AircraftType? current;

  /// Ce que l'escale a coûté : droits d'atterrissage et kérosène.
  final String bill;
}

/// Une fiche d'histoire affichée pendant le vol.
class StoryCard {
  const StoryCard(this.event, {this.caught = true});

  final HistoryEvent event;
  final bool caught;
}

/// Une annonce courte en haut de l'écran (nouvelle compagnie, nouveau drapeau…).
class FlightBanner {
  const FlightBanner(this.title, this.subtitle, {this.color = ChachaColors.yellow});

  final String title;
  final String subtitle;
  final Color color;
}

/// La zone de turbulence en cours, pour le tableau de bord.
class ZoneHud {
  const ZoneHud(this.zone, this.wave, this.active, this.progress);

  final WarZone zone;

  /// La vague en cours (ou la prochaine, entre deux vagues).
  final int wave;
  final bool active;
  final double progress;
}

/// Un avion de chasse noir : il arrive de face, annoncé par un signal rouge au bord de l'écran.
class _Jet {
  _Jet(this.x, this.y, this.wait, this.speed, this.drift);

  double x, y;

  /// Attente avant le signal, puis durée du signal.
  double wait, warn = 0.9;
  final double speed;
  final double drift;
  bool hit = false;
}

enum _PickupKind { medal, star, fuel, repair }

class _Pickup {
  _Pickup(this.kind, this.x, this.y, {this.event, this.label});

  final _PickupKind kind;
  double x, y;
  final HistoryEvent? event;
  final TextPainter? label;
  bool taken = false;

  double get radius => switch (kind) {
    _PickupKind.medal => 34,
    _PickupKind.star => 18,
    _PickupKind.fuel => 20,
    _PickupKind.repair => 26,
  };
}

class _Cloud {
  _Cloud(this.x, this.y, this.r, this.depth, {this.storm = false});

  double x, y;
  final double r, depth;
  final bool storm;
  double flash = 0;
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.color, this.size, {this.smoke = false});

  /// La fumée monte et grossit au lieu de tomber.
  final bool smoke;

  double x, y, vx, vy, life;
  final Color color;
  final double size;
  double age = 0;
  double rot = 0;
}

/// Le vol de 1960 à 2026 : décollage de Léopoldville, puis les années défilent.
class ChachaGame extends FlameGame {
  ChachaGame(this.type);

  /// L'avion change avec l'histoire : nouvelle compagnie, nouvel avion.
  AircraftType type;

  final hud = ValueNotifier<HudState?>(null);
  final card = ValueNotifier<StoryCard?>(null);
  final banner = ValueNotifier<FlightBanner?>(null);
  final zoneHud = ValueNotifier<ZoneHud?>(null);
  final radio = ValueNotifier<RadioCall?>(null);
  final stopover = ValueNotifier<StopoverHud?>(null);

  /// Les médaillons attrapés pendant ce vol, pour la liste des dates.
  final caught = <String>{};

  /// Appelé une fois au 30 juin 2027, pour la musique.
  VoidCallback? onFinale;

  /// Appelé quand un moment a sa chanson (clé de momentSongs).
  void Function(String song)? onSong;

  final planeCard = ValueNotifier<PlaneCard?>(null);
  final mission = ValueNotifier<Mission?>(null);
  final quiz = ValueNotifier<Quiz?>(null);
  final turningPoint = ValueNotifier<TurningPoint?>(null);
  final cabin = ValueNotifier<CabinHud?>(null);
  final meal = ValueNotifier<MealOffer?>(null);
  final talk = ValueNotifier<CabinTalk?>(null);

  /// Vrai une fois l'avion posé à Kinshasa le 30 juin 2027 : l'écran joue la fête.
  final homecoming = ValueNotifier<bool>(false);

  /// Fait monter ou baisser la chanson en cours (niveau de 0 à 1, en secondes).
  void Function(double level, double seconds)? onSwell;

  /// Les droits d'escale, toujours 1 000 dans la monnaie du moment ; le kérosène se paie en plus.
  static const landingFee = 1000;
  static const fuelPrice = 8;

  /// Le portefeuille : on gagne en volant, en livrant des passagers, en attrapant des médaillons.
  int money = 3000;

  /// Pour les tests : poser tout de suite une question de kérosène.
  bool quizNow = false;

  /// Pour les captures : montrer tout de suite « fiche », « tournant » ou « quiz » après l'avance.
  String? showcase;

  /// Le dernier point de reprise posé pendant ce vol.
  final checkpoint = ValueNotifier<Checkpoint?>(null);

  final tilt = TiltControl();
  final _rng = math.Random();

  // Entrées
  bool boost = false;

  /// Mode démo (bande-annonce, tests) : l'avion se pilote seul.
  bool autopilot = false;
  double timeScale = 1;

  /// Pour les tests et les captures : commencer directement en vol à cette année.
  double? startYear;

  /// Pour les captures : simuler ces secondes de vol dès le chargement.
  double warmup = 0;
  int startScore = 0, startMedals = 0;

  /// Pour les tests : kérosène au départ (0-100).
  double? startFuel;
  double keyX = 0, keyY = 0;
  Offset? touchTarget;

  // État du vol
  FlightPhase phase = FlightPhase.ready;
  double t = 0, phaseTime = 0;
  double year = 1960.5;
  double worldX = 0;
  double groundSpeed = 0;
  double climb = 0;
  double planeX = 0, planeY = 0, vy = 0, vx = 0, pitch = 0, gear = 1;
  double climbStartY = 0;
  int lives = 3, score = 0, medals = 0;
  double fuel = 100;
  double invulnerable = 0, shake = 0, flash = 0, slowMo = 0;
  double magnetTime = 0, magnetCooldown = 0;
  double stormUntil = -1, _nextStorm = 0, _nextStar = 0, _nextFuel = 6;
  double _cardTimer = 0, _bannerTimer = 0, _hudTimer = 0;
  int _nextEvent = 0;
  late AirlineEra _airline;
  late FlagEra _flag;
  final List<FlightBanner> _bannerQueue = [];

  final _clouds = <_Cloud>[];
  final _pickups = <_Pickup>[];
  final _particles = <_Particle>[];
  final _trail = <Offset>[];
  final _jets = <_Jet>[];

  // Zones de turbulence
  WarZone? _zone;
  int _nextZone = 0, _wave = 0, _wavesCleared = 0, _decade = 0;
  bool _waveActive = false;
  double _waveDelay = 0, _zoneFade = 0, _peace = 0;

  // Escales
  double condition = 100;
  double _runwayOrigin = 0, _radioTimer = 0, _offerAt = 0, _nextOffer = 0, _nextKit = 6;
  bool _offerPending = false,
      _wrecked = false,
      _rescue = false,
      _cueGear = false,
      _cueRunway = false,
      _lowFuelSaid = false;
  Airport? _airport;
  int _airportIndex = 0, _takeoffs = 0;
  double _approachT = 0, _approachY0 = 0, _approachSpeed = 0, _prevShift = 0, _climbFrom = 0;
  double _service = -1, _fuelAtLanding = 0, _conditionAtLanding = 0;

  // Passagers, missions, quiz, grands tournants
  int passengers = 0;
  int _quizCount = 0, _stopPurpose = 0; // 0 escale, 1 embarquement, 2 débarquement
  double _nextMission = 0, _nextQuiz = 50, _quizWait = 0, _planeCardTimer = 0, _turningTimer = 0, _boil = 0;
  double _missionSince = 0, _gust = 0, _tutorial = 0;
  bool _gusty = false, _hitWarned = false;
  final _askedQuiz = <String>{};

  // Cabine : ceintures, repas, argent
  double _nextBelts = 40,
      _nextMeal = 75,
      _cabinT = 0,
      _beltsDeadline = 0,
      _turbulence = 0,
      _moneyAcc = 0,
      _mealWait = 0;
  double _fuelTarget = 100;
  String _lastCurrency = 'F', _bill = '';
  String _menu = '';

  // Volcan
  double _volcanoX = -1e9, _volcanoUntil = 0, _nextBomb = 0;
  final _bombs = <_Particle>[];

  // Finale
  final _gifts = <_Particle>[];

  /// La dernière ligne droite commence en octobre 2026 et dure [_finaleLength] secondes,
  /// le temps d'« Alain Moloto » : les mois défilent, l'avion se pilote seul et dévie
  /// des orages, puis il descend vers Kinshasa pour le 30 juin 2027.
  static const _finaleFrom = 2026.75;
  static const _finaleLength = 40.0;
  static const _homeYear = 2027.44;
  double _finaleT = -1, _finaleYear0 = 0, _gapY = 0, _wallX = -1e9;
  int _finaleStep = 0;
  bool _homeApproach = false;

  // Cabine qui parle, louange des moments difficiles
  double _talkTimer = 0, _nextTalk = 0, _nextComfort = 0;

  static const _runwayStart = -400.0;
  static const _runwayEnd = 3600.0;
  static const _yearSeconds = 6.5;
  static const _endYear = 2027.5;
  static const _approachTime = 9.0;

  double get _w => size.x;
  double get _h => size.y;
  double get _unit => _h / 420;
  double get planeLength => math.min(_w * 0.31, _h * 0.7) * (0.62 + type.length * 0.38);
  double get _groundY0 => _h * 0.8;
  double get _groundShift => _h * 1.15 * math.pow(climb, 1.4).toDouble();
  double get groundY => _groundY0 + _groundShift;

  double get _planeOnGroundY => _groundY0 - (type.bodyHeight / 2 + 7.7) * planeLength / 100;

  @override
  Color backgroundColor() => ChachaColors.night;

  @override
  Future<void> onLoad() async {
    planeX = _w * 0.2;
    planeY = _planeOnGroundY;
    if (startYear != null) {
      year = startYear!;
      climb = 1;
      gear = 0;
      planeY = _h * 0.45;
      groundSpeed = _scroll;
      phase = FlightPhase.cruising;
      _takeoffs = 1;
      score = startScore;
      medals = startMedals;
      _queueBanner(FlightBanner('Reprise en ${year.floor()}', '${Lingala.tokende} « Allons-y ! » On repart d\'ici'));
      while (_nextEvent < historyEvents.length && historyEvents[_nextEvent].year < year) {
        _nextEvent++;
      }
    }
    if (startFuel != null) fuel = startFuel!;
    if (!type.fliesIn(year)) type = aircraftById(airlineAt(year).flagship);
    passengers = (type.seats * 0.55).round();
    _lastCurrency = currencyAt(year);
    _nextMission = 30;
    _airline = airlineAt(year);
    _flag = flagAt(year);
    _decade = (year / 10).floor();
    while (_nextZone < warZones.length && warZones[_nextZone].to <= year) {
      _nextZone++;
    }
    for (var i = 0; i < 9; i++) {
      _clouds.add(
        _Cloud(
          _rng.nextDouble() * _w * 1.4,
          _h * (0.08 + _rng.nextDouble() * 0.4),
          _unit * (18 + _rng.nextDouble() * 26),
          0.2 + _rng.nextDouble() * 0.5,
        ),
      );
    }
    tilt.start();
  }

  bool _started = false;

  /// L'avance et les captures, au premier pas du jeu : onLoad tourne pendant la construction
  /// des widgets, où l'on ne peut pas encore mettre à jour le tableau de bord.
  void _firstStep() {
    _started = true;
    for (var i = 0; i < warmup * 60; i++) {
      _tick(_step);
    }
    switch (showcase) {
      case 'fiche':
        _showPlaneCard('Ton avion');
      case 'tournant':
        _showCard(historyEvents.firstWhere((e) => e.big && e.year >= year - 0.5));
      case 'quiz':
        _askQuiz();
      case 'repas':
        _offerMeal();
      case 'ceintures':
        _askBelts('Zone de turbulences droit devant');
      case 'service':
        serveMeal('Fufu', 'Poisson grillé', ['Primus', 'Fanta', 'Jameson']);
    }
    _pushHud();
  }

  @override
  void onRemove() {
    tilt.stop();
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (phase == FlightPhase.ready || phase == FlightPhase.rolling) {
      planeX = _w * 0.2;
      planeY = _planeOnGroundY;
    }
  }

  // ---------------------------------------------------------------- actions

  void useMagnet() {
    if (phase != FlightPhase.cruising || magnetCooldown > 0) return;
    magnetTime = 3;
    magnetCooldown = 10;
    HapticFeedback.selectionClick();
  }

  void _setPhase(FlightPhase p) {
    if (p == FlightPhase.crashed && phase != p && !autopilot) {
      saveFlight(FlightRecord(DateTime.now(), score, medals, money, currencyAt(year), false, year));
    }
    phase = p;
    phaseTime = 0;
    _pushHud();
  }

  void _queueBanner(FlightBanner b) {
    _bannerQueue.add(b);
    if (banner.value == null) _nextBanner();
  }

  void _nextBanner() {
    if (_bannerQueue.isEmpty) {
      banner.value = null;
      return;
    }
    banner.value = _bannerQueue.removeAt(0);
    _bannerTimer = 3.2;
  }

  final List<StoryCard> _cardQueue = [];

  void _showCard(HistoryEvent e, {bool caught = true}) {
    if (e.song != null && e.kind != EventKind.memory) onSong?.call(e.song!);
    if (e.big && caught) {
      // Grand tournant : le ciel bout, le drapeau change, la fiche suit.
      _boil = 4.5;
      slowMo = math.max(slowMo, 3.5);
      shake = 0.3;
      turningPoint.value = TurningPoint(e, flagAt(e.year - 0.02).style, flagAt(e.year + 0.12).style);
      _turningTimer = 4.6;
      HapticFeedback.heavyImpact();
    }
    _cardQueue.add(StoryCard(e, caught: caught));
    // Quand les événements s'enchaînent, on garde les plus récents.
    while (_cardQueue.length > 3) {
      _cardQueue.removeAt(0);
    }
    if (card.value == null) _nextCard();
  }

  void _nextCard() {
    if (_cardQueue.isEmpty) {
      card.value = null;
      return;
    }
    final c = _cardQueue.removeAt(0);
    card.value = c;
    _cardTimer = c.event.kind == EventKind.memory ? 5 : (_cardQueue.isEmpty ? 4.2 : 3.2);
  }

  void _loseLife() {
    if (invulnerable > 0 || phase != FlightPhase.cruising || _finaleT >= 0) return;
    lives -= 1;
    condition = math.max(0, condition - 20);
    invulnerable = 2;
    final m = mission.value;
    if (m != null && m.boarded) {
      m.hits++;
      if (!_hitWarned) {
        _hitWarned = true;
        _say('Tour de contrôle', Lingala.keba, 'Protège tes ${m.count} passagers ! Chaque choc leur fait peur.');
      }
    }
    shake = 0.5;
    HapticFeedback.heavyImpact();
    _burst(planeX, planeY, 26, const [Color(0xFFFFB04A), Color(0xFFFF3B3B), Colors.white]);
    if (lives <= 0) {
      lives = 0;
      _setPhase(FlightPhase.crashed);
    }
    _pushHud();
  }

  void _burst(double x, double y, int n, List<Color> colors, {double speed = 260, double size = 4}) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final v = speed * (0.3 + _rng.nextDouble()) * _unit;
      _particles.add(
        _Particle(
          x,
          y,
          math.cos(a) * v,
          math.sin(a) * v,
          0.6 + _rng.nextDouble() * 0.8,
          colors[_rng.nextInt(colors.length)],
          size * _unit * (0.6 + _rng.nextDouble()),
        ),
      );
    }
  }

  void _confetti() {
    for (var i = 0; i < 90; i++) {
      _particles.add(
        _Particle(
          _rng.nextDouble() * _w,
          -20 - _rng.nextDouble() * _h * 0.3,
          (-40 + _rng.nextDouble() * 80) * _unit,
          (120 + _rng.nextDouble() * 160) * _unit,
          2.4 + _rng.nextDouble(),
          const [ChachaColors.sky, ChachaColors.red, ChachaColors.yellow, Colors.white][_rng.nextInt(4)],
          5 * _unit,
        )..rot = _rng.nextDouble() * 6,
      );
    }
  }

  TextPainter _label(String text, double size) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFF5A3A00),
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  // ----------------------------------------------------------------- boucle

  double _pending = 0;

  @override
  void update(double dt) {
    super.update(dt);
    // Flame appelle update(0) pendant la construction de son widget : rien à faire à ce moment-là.
    if (dt == 0) return;
    if (!_started) _firstStep();
    // Pendant une question, le vol attend la réponse.
    if (quiz.value != null) {
      if (autopilot && showcase != 'quiz' && (_quizWait += dt) > 1.2) answerQuiz(quiz.value!.answer);
      return;
    }
    if (meal.value != null) {
      if (autopilot && showcase != 'repas' && (_mealWait += dt) > 1.2) {
        serveMeal(mealBases[_rng.nextInt(mealBases.length)], mealDishes[_rng.nextInt(mealDishes.length)], [
          mealBeers[_rng.nextInt(mealBeers.length)],
          mealSodas[_rng.nextInt(mealSodas.length)],
        ]);
      }
      return;
    }
    // Pas de temps fixe : le jeu avance à la même vitesse sur un téléphone lent ou rapide.
    _pending = math.min(_pending + dt * timeScale, 0.5 * math.max(1, timeScale));
    while (_pending >= _step) {
      _pending -= _step;
      _tick(_step);
    }
  }

  static const _step = 1 / 60;

  void _tick(double dt) {
    if (autopilot) _autopilot();
    t += dt;
    phaseTime += dt;
    final ts = slowMo > 0 ? 0.45 : 1.0;
    slowMo = math.max(0, slowMo - dt);
    invulnerable = math.max(0, invulnerable - dt);
    shake = math.max(0, shake - dt);
    flash = math.max(0, flash - dt * 1.6);
    magnetTime = math.max(0, magnetTime - dt);
    magnetCooldown = math.max(0, magnetCooldown - dt);
    _boil = math.max(0, _boil - dt);
    if (planeCard.value != null && (_planeCardTimer -= dt) <= 0) planeCard.value = null;
    if (talk.value != null && (_talkTimer -= dt) <= 0) talk.value = null;
    if (turningPoint.value != null && (_turningTimer -= dt) <= 0) turningPoint.value = null;

    switch (phase) {
      case FlightPhase.ready:
        if (boost) _setPhase(FlightPhase.rolling);
      case FlightPhase.rolling:
        _roll(dt);
      case FlightPhase.climbing:
        _climb(dt);
      case FlightPhase.cruising:
        _cruise(dt, ts);
      case FlightPhase.approach:
        _approach(dt);
      case FlightPhase.ground:
        _ground(dt);
      case FlightPhase.crashed:
        if (_wrecked) {
          groundSpeed = math.max(0, groundSpeed - _unit * 700 * dt);
          worldX += groundSpeed * dt;
          _smoke(dt);
        } else {
          vy += _h * 1.2 * dt;
          planeY += vy * dt;
          pitch = math.min(0.7, pitch + dt * 0.6);
          worldX += groundSpeed * dt * 0.6;
          _smoke(dt);
        }
      case FlightPhase.finished:
        if (homecoming.value) {
          // Posé à N'djili : l'avion freine sur la piste pendant que la fête commence.
          groundSpeed = math.max(0, groundSpeed - _unit * 180 * dt);
          worldX += groundSpeed * dt;
          planeY = _planeOnGroundY + _groundShift;
          pitch += (0 - pitch) * math.min(1, dt * 4);
        } else {
          worldX += groundSpeed * dt;
          planeX += (_w * 0.5 - planeX) * dt;
          planeY += (_h * 0.45 - planeY) * dt;
        }
        if (phaseTime % 1.6 < dt) _confetti();
        if (phaseTime % 0.3 < dt) {
          _gifts.add(
            _Particle(
              _rng.nextDouble() * _w,
              -30,
              0,
              (90 + _rng.nextDouble() * 80) * _unit,
              9,
              Colors.white,
              (14 + _rng.nextDouble() * 10) * _unit,
            )..rot = _rng.nextDouble(),
          );
        }
    }

    _updateWorld(dt, ts);

    if (card.value != null) {
      _cardTimer -= dt;
      if (_cardTimer <= 0) _nextCard();
    }
    if (banner.value != null) {
      _bannerTimer -= dt;
      if (_bannerTimer <= 0) _nextBanner();
    }
    if (radio.value != null) {
      _radioTimer -= dt;
      if (_radioTimer <= 0) {
        if (_offerPending) {
          // Sans réponse, on continue et la tour rappellera.
          _offerPending = false;
          _nextOffer = t + 12;
        }
        radio.value = null;
      }
    }
    _hudTimer -= dt;
    if (_hudTimer <= 0) {
      _hudTimer = 0.1;
      _pushHud();
    }
  }

  void _autopilot() {
    if (phase != FlightPhase.cruising) {
      boost = phase != FlightPhase.crashed && phase != FlightPhase.finished;
      touchTarget = null;
      return;
    }
    if (_offerPending && t - _offerAt > 1.5) acceptStopover();
    boost = (t % 8) < 3;
    _Pickup? goal;
    for (final p in _pickups) {
      if (p.x < planeX - 10) continue;
      final better =
          goal == null ||
          (p.kind == _PickupKind.medal && goal.kind != _PickupKind.medal) ||
          (p.kind == goal.kind && p.x < goal.x) ||
          (p.kind == _PickupKind.fuel && fuel < 55 && goal.kind == _PickupKind.star);
      if (better) goal = p;
    }
    var y = goal?.y ?? _h * 0.45;
    for (final c in _clouds) {
      if (!c.storm || c.x < planeX - c.r || c.x > planeX + 420 * _unit) continue;
      if ((y - c.y).abs() < c.r * 2.4) y = c.y + (planeY > c.y ? 1 : -1) * c.r * 2.6;
    }
    // Les avions de chasse : choisir la hauteur la plus éloignée de ceux qui arrivent.
    final threats = [
      for (final j in _jets)
        if (j.x > planeX - _jetLength * 0.5 && j.wait < 0.5) Offset(j.x, j.y),
      for (final b in _bombs)
        if (b.x > planeX - 40 * _unit && b.x < planeX + 500 * _unit) Offset(b.x, b.y + b.vy * 0.4),
    ];
    if (threats.any((j) => (j.dy - y).abs() < _h * 0.16)) {
      var best = y, bestGap = -1.0;
      for (var i = 0; i <= 12; i++) {
        final c = _h * (0.14 + i * 0.06);
        final gap = threats.map((j) => (j.dy - c).abs()).reduce(math.min) - (c - planeY).abs() * 0.15;
        if (gap > bestGap) {
          bestGap = gap;
          best = c;
        }
      }
      y = best;
    }
    touchTarget = Offset(_w * 0.26, y.clamp(_h * 0.14, _h * 0.86));
  }

  void _roll(double dt) {
    if (_takeoffs == 0 && _tutorial == 0 && groundSpeed > _unit * 300) {
      _tutorial = 1;
      _say('Tour de Léopoldville', Lingala.tokende, 'Encore ! À la bonne vitesse, l\'avion lève le nez tout seul.');
    }
    final accel = boost ? 0.3 : -0.12;
    final v = (groundSpeed / (_unit * 560)).clamp(0.0, 1.0);
    final nv = (v + accel * dt).clamp(0.0, 1.0);
    groundSpeed = nv * _unit * 560;
    worldX += groundSpeed * dt;
    planeY = _planeOnGroundY;
    // Rotation : au bout de l'élan, ou en fin de piste pour ne jamais sortir
    final nearEnd = worldX - _runwayOrigin + planeX > _runwayEnd * _unit - planeLength * 1.5;
    if (nv >= 1 || nearEnd) {
      climbStartY = planeY;
      _climbFrom = climb;
      _setPhase(FlightPhase.climbing);
      HapticFeedback.mediumImpact();
    }
  }

  void _climb(double dt) {
    climb = math.min(1, climb + dt / 5);
    final e = Curves.easeInOut.transform(((climb - _climbFrom) / (1 - _climbFrom)).clamp(0.0, 1.0));
    planeY = climbStartY + (_h * 0.45 - climbStartY) * e;
    pitch = -0.2 * math.sin(math.pi * math.min(1, climb * 1.15));
    gear = (1 - (climb - 0.12) / 0.3).clamp(0.0, 1.0);
    groundSpeed = _unit * (560 + 120 * climb);
    worldX += groundSpeed * dt;
    if (climb >= 1) {
      tilt.calibrate();
      _setPhase(FlightPhase.cruising);
      _nextOffer = t + 20;
      if (_takeoffs++ == 0) {
        _queueBanner(
          const FlightBanner(
            '${Lingala.tokende} Bon vol !',
            '« Allons-y ! » Attrape les médaillons des moments marquants',
          ),
        );
        _say(
          'Tour de Léopoldville',
          Lingala.elonga,
          'Bravo ! Incline le téléphone, glisse le doigt ou utilise ▲ ▼ pour monter et descendre. Évite les orages.',
          seconds: 7,
        );
        _showPlaneCard('Ton avion');
      } else if (_airport != null) {
        final m = mission.value;
        _queueBanner(
          FlightBanner(
            '${Lingala.tokende} De retour en vol',
            m != null && m.boarded
                ? '$passengers passagers à bord · cap sur ${m.to.cityAt(year)}'
                : 'Plein fait à ${_airport!.cityAt(year)} · avion révisé',
          ),
        );
        if (m != null && m.boarded) _missionSince = t;
      }
    }
  }

  double get _scroll => _unit * 520 * (boost ? 1.6 : 1) * (0.8 + type.speed * 0.4);

  void _cruise(double dt, double ts) {
    if (_finaleT >= 0) return _cruiseFinale(dt, ts);
    final scroll = _scroll * ts;
    worldX += scroll * dt;
    groundSpeed = scroll;
    if (_zone == null) {
      year += dt * ts / _yearSeconds * (boost ? 1.6 : 1);
      _checkDecade();
    } else {
      _updateZone(dt * ts);
    }
    _checkZone();
    if (_zone == null && year >= _finaleFrom && year < _homeYear) return _startFinale();
    _steer(dt);

    // Carburant
    final maxVy = _h * (0.7 + type.handling * 0.6);
    double targetVy, targetVx;
    if (touchTarget != null) {
      targetVy = ((touchTarget!.dy - planeY) * 5).clamp(-maxVy, maxVy);
      targetVx = ((touchTarget!.dx.clamp(_w * 0.1, _w * 0.45) - planeX) * 3).clamp(-_w, _w);
    } else {
      final iy = (keyY + tilt.vertical).clamp(-1.0, 1.0);
      final ix = (keyX + tilt.horizontal).clamp(-1.0, 1.0);
      targetVy = iy * maxVy;
      targetVx = ix * _w * 0.4;
    }
    vy += (targetVy - vy) * math.min(1, dt * 8);
    vx += (targetVx - vx) * math.min(1, dt * 6);
    planeY = (planeY + vy * dt).clamp(_h * 0.12, _h * 0.88);
    planeX = (planeX + vx * dt).clamp(_w * 0.1, _w * 0.45);
    // En guerre, le kérosène part bien plus vite.
    fuel -= dt * ts * (1.15 + (boost ? 1.3 : 0)) * (1.35 - type.tank * 0.6) * (_zone != null ? 1.8 : 1);
    condition = math.max(0, condition - dt * ts * 0.3);
    if (fuel < 25 && !_lowFuelSaid) {
      _lowFuelSaid = true;
      _say('Tour de contrôle', Lingala.mafuta, 'Le kérosène va finir. Attrape un bidon ou fais escale.');
    }
    if (fuel > 40) _lowFuelSaid = false;
    if (_zone == null && !_offerPending && t >= _nextOffer && (fuel < 35 || condition < 30)) _offerStopover();
    _checkMission();
    _updateCabin(dt);
    if (fuel < 14 && _quizCount < 3 && t >= _nextQuiz || quizNow) {
      quizNow = false;
      _askQuiz();
    }
    if (t >= _nextKit && (fuel < 55 || condition < 55)) _spawnKit();
    if (fuel <= 0) {
      fuel = 45;
      _queueBanner(
        const FlightBanner('Panne sèche !', "Ravitaillement d'urgence : une vie en moins", color: ChachaColors.red),
      );
      _loseLife();
    }

    _spawnHistory();
    _spawnAmbient();
    _checkEras();

    if (year >= _endYear) {
      year = _endYear;
      _setPhase(FlightPhase.finished);
      if (!autopilot) {
        Checkpoint.clear();
        saveFlight(FlightRecord(DateTime.now(), score, medals, money, currencyAt(year), true, year));
      }
      _queueBanner(
        const FlightBanner('${Lingala.dipanda} 30 juin 2027', '67 ans d\'indépendance · Indépendance Cha Cha'),
      );
      _queueBanner(const FlightBanner('Des cadeaux pour toi !', 'Le Congo t\'a raconté son histoire, de 1960 à 2027'));
      _confetti();
      onFinale?.call();
    }
  }

  /// Pilotage : doigt, inclinaison ou flèches.
  void _steer(double dt) {
    final maxVy = _h * (0.7 + type.handling * 0.6);
    double targetVy, targetVx;
    if (touchTarget != null) {
      targetVy = ((touchTarget!.dy - planeY) * 5).clamp(-maxVy, maxVy);
      targetVx = ((touchTarget!.dx.clamp(_w * 0.1, _w * 0.45) - planeX) * 3).clamp(-_w, _w);
    } else {
      final iy = (keyY + tilt.vertical).clamp(-1.0, 1.0);
      final ix = (keyX + tilt.horizontal).clamp(-1.0, 1.0);
      targetVy = iy * maxVy;
      targetVx = ix * _w * 0.4;
    }
    vy += (targetVy - vy) * math.min(1, dt * 8);
    vx += (targetVx - vx) * math.min(1, dt * 6);
    planeY = (planeY + vy * dt).clamp(_h * 0.12, _h * 0.88);
    planeX = (planeX + vx * dt).clamp(_w * 0.1, _w * 0.45);
    pitch += ((vy / maxVy) * 0.28 - pitch) * math.min(1, dt * 6);
  }

  // ------------------------------------------------------------- finale

  void _startFinale() {
    _finaleT = 0;
    _finaleStep = 0;
    _finaleYear0 = year;
    boost = false;
    mission.value = null;
    cabin.value = null;
    _offerPending = false;
    radio.value = null;
    if (passengers == 0) passengers = (type.seats * 0.8).round();
    onSong?.call('moloto');
    _queueBanner(
      const FlightBanner('La dernière ligne droite', 'Le pilote automatique te ramène à Kinshasa pour le 30 juin 2027'),
    );
    _say(
      'Tour de Kinshasa',
      'Tokokoma !',
      '« Nous allons arriver ! » On prend les commandes avec toi : regarde, et tiens bon.',
      seconds: 6,
    );
    _talk(TalkMoment.finaleStart, force: true);
    _pushHud();
  }

  /// Un mur d'orages avec un seul passage : le pilote automatique dévie au dernier moment.
  void _stormWall() {
    final gaps = [_h * 0.25, _h * 0.5, _h * 0.72]..remove(_gapY);
    _gapY = gaps[_rng.nextInt(gaps.length)];
    _wallX = _w + 140 * _unit;
    for (var y = _h * 0.12; y <= _h * 0.9; y += _h * 0.13) {
      if ((y - _gapY).abs() < _h * 0.15) continue;
      _clouds.add(
        _Cloud(
          _wallX + (_rng.nextDouble() - 0.5) * 40 * _unit,
          y,
          _unit * (30 + _rng.nextDouble() * 12),
          1,
          storm: true,
        ),
      );
    }
  }

  void _cruiseFinale(double dt, double ts) {
    _finaleT += dt;
    final scroll = _scroll * ts;
    worldX += scroll * dt;
    groundSpeed = scroll;
    _wallX -= scroll * dt;
    final k = (_finaleT / _finaleLength).clamp(0.0, 1.0);
    year = _finaleYear0 + (_homeYear - _finaleYear0) * k;
    fuel = math.min(100, fuel + dt * 4);

    // L'avion se pilote seul : il garde le cap, puis plonge vers le passage du mur d'orages.
    final wallAhead = _wallX > planeX - 60 * _unit && _wallX < planeX + 520 * _unit;
    final cruiseY = _h * (0.45 + 0.08 * math.sin(_finaleT * 0.7));
    touchTarget = Offset(_w * (wallAhead ? 0.3 : 0.24), wallAhead ? _gapY : cruiseY);
    _steer(dt);

    switch (_finaleStep) {
      case 0 when _finaleT >= 9:
        // Le son très doux remonte : quelque chose arrive.
        onSwell?.call(1, 5);
        _queueBanner(
          const FlightBanner('Orages droit devant', 'Le pilote automatique cherche un passage', color: _warRed),
        );
        _finaleStep++;
      case 1 when _finaleT >= 11:
        _stormWall();
        _talk(TalkMoment.finaleStorm, force: true);
        _finaleStep++;
      case 2 when _finaleT >= 13.5:
        slowMo = 1.6;
        shake = 0.35;
        HapticFeedback.heavyImpact();
        _finaleStep++;
      case 3 when _finaleT >= 18:
        _stormWall();
        flash = 0.5;
        _finaleStep++;
      case 4 when _finaleT >= 20.5:
        slowMo = 1.4;
        shake = 0.45;
        HapticFeedback.heavyImpact();
        _talk(TalkMoment.finaleStorm, force: true);
        _finaleStep++;
      case 5 when _finaleT >= 25:
        _stormWall();
        _finaleStep++;
      case 6 when _finaleT >= 27.5:
        slowMo = 1.2;
        shake = 0.3;
        _finaleStep++;
      case 7 when _finaleT >= 31:
        // Le calme après la tempête.
        _peace = 6;
        _confetti();
        _queueBanner(
          const FlightBanner('Le calme après la tempête', 'Le ciel s\'ouvre au-dessus du pays', color: _peaceGreen),
        );
        _talk(TalkMoment.finaleCalm, force: true);
        HapticFeedback.mediumImpact();
        _finaleStep++;
      case 8 when _finaleT >= _finaleLength:
        _beginHomecoming();
        _finaleStep++;
    }

    _spawnHistory();
    _spawnAmbient();
    _checkEras();
  }

  /// Début juin 2027 : « Indépendance Cha Cha » prend le relais et l'avion descend vers N'djili.
  void _beginHomecoming() {
    _homeApproach = true;
    _airport = airports.first;
    _stopPurpose = 0;
    _gusty = false;
    touchTarget = null;
    onFinale?.call();
    _talk(TalkMoment.approachHome, force: true);
    _startApproach();
    _say(
      'Tour de Kinshasa',
      Lingala.kitaMalembe,
      '« Descends doucement. » Bienvenue à la maison : le pays t\'attend pour le 30 juin.',
      seconds: 7,
    );
  }

  void _arriveHome() {
    year = _endYear;
    vy = 0;
    pitch = 0;
    _setPhase(FlightPhase.finished);
    homecoming.value = true;
    if (!autopilot) Checkpoint.clear();
    if (!autopilot) saveFlight(FlightRecord(DateTime.now(), score, medals, money, currencyAt(year), true, year));
    _confetti();
    HapticFeedback.heavyImpact();
    _burst(
      planeX - planeLength * 0.1,
      planeY + planeLength * 0.08,
      14,
      const [Color(0xFFB8B8B8), Color(0xFFE0E0E0)],
      speed: 120,
      size: 5,
    );
    _talk(TalkMoment.arrival, force: true, seconds: 9);
  }

  /// Une fête : des confettis aux couleurs du drapeau, appelée par l'écran à chaque « Vive… ».
  void cheer() {
    _confetti();
    HapticFeedback.lightImpact();
  }

  /// Les gens de la cabine parlent : une conversation tirée au hasard pour ce moment.
  void _talk(TalkMoment m, {bool force = false, double? seconds}) {
    if (!force && (t < _nextTalk || _finaleT >= 0)) return;
    final options = cabinTalks[m];
    if (options == null || options.isEmpty) return;
    final lines = options[_rng.nextInt(options.length)];
    talk.value = CabinTalk(lines);
    _talkTimer = seconds ?? 2.2 + lines.length * 1.6;
    _nextTalk = t + 14;
  }

  /// Un moment difficile : une louange douce réconforte, sans revenir trop souvent.
  void _comfort() {
    if (t < _nextComfort || _finaleT >= 0) return;
    _nextComfort = t + 75;
    onSong?.call('louange');
  }

  void _spawnHistory() {
    final secondsToPlane = (_w + 60 - planeX) / _scroll;
    final lead = secondsToPlane / _yearSeconds * (boost ? 1.6 : 1);
    while (_nextEvent < historyEvents.length && historyEvents[_nextEvent].year <= year + lead) {
      final e = historyEvents[_nextEvent++];
      switch (e.kind) {
        case EventKind.life:
        case EventKind.glory:
          final y = _h * (0.18 + _rng.nextDouble() * 0.64);
          _pickups.add(_Pickup(_PickupKind.medal, _w + 60, y, event: e, label: _label('${e.yearLabel}', 15 * _unit)));
        case EventKind.obstacle:
          // Les guerres se traversent en vagues d'avions de chasse, les autres épreuves en orages.
          if (!e.war) {
            stormUntil = math.max(stormUntil, e.year + lead + 0.9);
            _nextStorm = t + secondsToPlane * 0.2;
            _talk(e.volcano ? TalkMoment.volcano : TalkMoment.storm);
            _comfort();
          }
          if (e.volcano) {
            _volcanoX = _w * 1.05;
            _volcanoUntil = t + 18;
            _nextBomb = t + 2.5;
            _queueBanner(
              FlightBanner(e.title, '${e.date} · évite la lave et les cendres', color: const Color(0xFFFFA24A)),
            );
          }
          _showCard(e);
        case EventKind.memory:
          slowMo = 4.5;
          _showCard(e);
          if (e.song != null) onSong?.call(e.song!);
      }
    }
  }

  void _spawnAmbient() {
    if (year < stormUntil && t >= _nextStorm) {
      _nextStorm = t + 1.0 + _rng.nextDouble() * 0.8;
      final y = (planeY + (_rng.nextDouble() - 0.5) * _h * 0.7).clamp(_h * 0.15, _h * 0.85);
      _clouds.add(_Cloud(_w + 120 * _unit, y, _unit * (34 + _rng.nextDouble() * 20), 1, storm: true));
    }
    if (t >= _nextStar) {
      _nextStar = t + 1.3 + _rng.nextDouble();
      _pickups.add(_Pickup(_PickupKind.star, _w + 40, _h * (0.15 + _rng.nextDouble() * 0.7)));
    }
    if (t >= _nextFuel) {
      _nextFuel = t + 9 + _rng.nextDouble() * 5;
      _pickups.add(_Pickup(_PickupKind.fuel, _w + 40, _h * (0.2 + _rng.nextDouble() * 0.6)));
    }
    final decor = _clouds.where((c) => !c.storm).length;
    if (decor < 10 && _rng.nextDouble() < 0.04) {
      _clouds.add(
        _Cloud(
          _w + 80,
          _h * (0.06 + _rng.nextDouble() * 0.85),
          _unit * (16 + _rng.nextDouble() * 30),
          0.2 + _rng.nextDouble() * 0.9,
        ),
      );
    }
  }

  // ------------------------------------------------------------- escales

  void _say(String speaker, String lingala, String french, {String? offer, double seconds = 5}) {
    radio.value = RadioCall(speaker, lingala, french, offer: offer);
    _radioTimer = seconds;
  }

  void _offerStopover() {
    final open = [
      for (final a in airports)
        if (a.openAt(year)) a,
    ];
    _airport = open[_airportIndex++ % open.length];
    _stopPurpose = 0;
    _gusty = false;
    _offerPending = true;
    _offerAt = t;
    _nextKit = math.max(_nextKit, t + 20);
    final km = 20 + _rng.nextInt(40);
    final why = fuel < 35 ? 'Kérosène bas' : "L'avion a besoin d'entretien";
    _say(
      'Tour de ${_airport!.cityAt(year)}',
      '${Lingala.mbote} ${Lingala.tokende}',
      '$why. Aéroport le plus proche : ${_airport!.titleAt(year)}, à $km km.',
      offer: _airport!.cityAt(year),
      seconds: 10,
    );
    HapticFeedback.selectionClick();
  }

  /// Le joueur accepte l'escale : on commence l'approche.
  void acceptStopover() {
    if (!_offerPending || phase != FlightPhase.cruising) return;
    if (money < landingFee) {
      // Pas assez pour les droits d'escale : on convertit des points en argent, si on en a.
      final missing = landingFee - money;
      if (score >= missing) {
        score -= missing;
        money += missing;
        _queueBanner(
          FlightBanner(
            'Points convertis',
            '${_fmt(missing)} points → ${_fmt(missing)} ${currencyAt(year)} pour les droits d\'escale',
            color: ChachaColors.yellow,
          ),
        );
      } else {
        _offerPending = false;
        _nextOffer = t + 14;
        _say(
          'Tour de ${_airport!.cityAt(year)}',
          Lingala.zelaMoke,
          'Les droits d\'escale coûtent ${_fmt(landingFee)} ${currencyAt(year)}. Tu n\'as que ${_fmt(money)} : continue et gagne encore un peu.',
        );
        return;
      }
    }
    _startApproach();
    _say(
      'Tour de ${_airport!.cityAt(year)}',
      Lingala.zelaMoke,
      _gusty
          ? 'Vent fort et turbulences : garde le couloir jaune, on te guide.'
          : 'Suis le couloir jaune, on te guide jusqu\'à la piste.',
    );
  }

  void _startApproach() {
    _offerPending = false;
    cabin.value = null;
    _approachT = 0;
    _approachY0 = planeY;
    _approachSpeed = _unit * 420;
    _prevShift = _groundShift;
    _cueGear = _cueRunway = false;
    // La piste commence sous l'avion juste avant la fin de la descente.
    _runwayOrigin = worldX + _approachSpeed * _approachTime * 0.84 + _w * 0.22 - _runwayStart * _unit;
    _setPhase(FlightPhase.approach);
  }

  void declineStopover() {
    if (!_offerPending) return;
    _offerPending = false;
    _nextOffer = t + 14;
    if (_stopPurpose == 2) _missionSince = t - 10;
    _say('Tour de contrôle', Lingala.matondo, 'Très bien, continue. Surveille ton kérosène.');
  }

  void _spawnKit() {
    _nextKit = t + 24 + _rng.nextDouble() * 10;
    // Le kit d'abord : la tour ne propose l'escale que s'il est manqué.
    _nextOffer = math.max(_nextOffer, t + 8);
    _pickups.add(_Pickup(_PickupKind.repair, _w + 300 * _unit, _h * (0.25 + _rng.nextDouble() * 0.5)));
    _say(
      'Tour de contrôle',
      Lingala.keba,
      'Un kit d\'entretien arrive devant toi. Attrape-le : pas besoin de descendre !',
    );
  }

  /// Hauteur cible sur le couloir d'approche, [k] secondes après le début.
  double _glide(double k) {
    final f = (k / _approachTime).clamp(0.0, 1.0);
    return _approachY0 + (_planeOnGroundY - _approachY0) * (f * f * (3 - 2 * f));
  }

  void _approach(double dt) {
    _approachT += dt;
    worldX += _approachSpeed * dt;
    groundSpeed = _approachSpeed;
    climb = (1 - _approachT / _approachTime).clamp(0.0, 1.0);
    gear = ((0.65 - climb) / 0.25).clamp(0.0, 1.0);
    planeX += (_w * 0.22 - planeX) * math.min(1, dt * 2);

    // Sans toucher, l'avion suit seul le couloir ; on peut aussi piloter, et piquer trop fort.
    final maxVy = _h * (0.7 + type.handling * 0.6);
    // Le retour à Kinshasa se fait seul, calmement : on regarde l'avion se poser.
    final manual = !_homeApproach && (touchTarget != null || keyY != 0 || tilt.vertical.abs() > 0.2);
    if (_homeApproach) year = _homeYear + (_endYear - 0.004 - _homeYear) * (_approachT / _approachTime).clamp(0.0, 1.0);
    double targetVy;
    if (touchTarget != null) {
      targetVy = ((touchTarget!.dy - planeY) * 5).clamp(-maxVy, maxVy);
    } else if (manual) {
      targetVy = (keyY + tilt.vertical).clamp(-1.0, 1.0) * maxVy;
    } else {
      targetVy = (_glide(_approachT + 0.25) - planeY) * 4;
    }
    if (_gusty) {
      // Rafales : l'avion est secoué, il faut tenir le couloir.
      _gust += (_rng.nextDouble() - 0.5) * dt * 6;
      _gust *= 1 - dt * 0.8;
      targetVy += _gust * _h * 0.5;
      if (_rng.nextDouble() < dt * 0.6) shake = 0.15;
    }
    final prevY = planeY;
    vy += (targetVy - vy) * math.min(1, dt * 6);
    planeY = math.max(_h * 0.1, planeY + vy * dt);
    pitch += ((vy / maxVy) * 0.28 - pitch) * math.min(1, dt * 6);

    if (_approachT > _approachTime * 0.35 && !_cueGear) {
      _cueGear = true;
      if (!_homeApproach) {
        _say('Tour de ${_airport!.cityAt(year)}', Lingala.kitaMalembe, 'Train sorti. Descends doucement.');
      }
    }
    if (_approachT > _approachTime * 0.7 && !_cueRunway) {
      _cueRunway = true;
      _homeApproach
          ? _say('Tour de Kinshasa', Lingala.elonga, 'Piste de N\'djili en vue. Tout le pays te regarde.')
          : _say('Tour de ${_airport!.cityAt(year)}', Lingala.tokende, 'Piste en vue : tu peux te poser !');
    }

    final shift = _groundShift;
    final groundOnPlane = _planeOnGroundY + shift;
    if (planeY >= groundOnPlane) {
      final closing = ((planeY - prevY) - (shift - _prevShift)) / dt;
      final gx = worldX - _runwayOrigin;
      final onRunway = planeX > _runwayStart * _unit - gx && planeX < _runwayEnd * _unit - gx - planeLength;
      planeY = groundOnPlane;
      if (_homeApproach) {
        _arriveHome();
      } else if (closing > _h * 0.55 || !onRunway) {
        _crashLanding(onRunway ? 'Descente trop rapide' : 'Hors de la piste');
      } else {
        _land();
      }
    } else if (_approachT > _approachTime + 4) {
      // Remise des gaz : on remonte et la tour reproposera l'escale.
      climbStartY = planeY;
      _climbFrom = climb;
      _setPhase(FlightPhase.climbing);
      _offerPending = false;
      _nextOffer = t + 3;
      _say('Tour de contrôle', Lingala.keba, 'Remise des gaz ! On refait l\'approche.');
    }
    _prevShift = shift;
  }

  void _land() {
    _setPhase(FlightPhase.ground);
    _service = -1;
    vy = 0;
    pitch = 0;
    score += 200;
    HapticFeedback.mediumImpact();
    _burst(
      planeX - planeLength * 0.1,
      planeY + planeLength * 0.08,
      14,
      const [Color(0xFFB8B8B8), Color(0xFFE0E0E0)],
      speed: 120,
      size: 5,
    );
    _queueBanner(FlightBanner('Bienvenue à ${_airport!.cityAt(year)}', _airport!.label));
    if (airportPostcards[_airport!.city] case (final photo, final text)) {
      _showCard(
        HistoryEvent(
          year,
          EventKind.life,
          'Escale',
          _airport!.cityAt(year),
          'Carte postale de ${_airport!.cityAt(year)}',
          text,
          photo: photo,
        ),
        caught: false,
      );
    }
    final m = mission.value;
    _say(
      'Tour de ${_airport!.cityAt(year)}',
      Lingala.elonga,
      _stopPurpose == 1 && m != null
          ? 'Bel atterrissage ! Les ${m.count} passagers montent à bord.'
          : _stopPurpose == 2
          ? 'Bel atterrissage ! Tes passagers sont arrivés.'
          : 'Bel atterrissage ! Zela moke : l\'équipe arrive.',
    );
  }

  void _crashLanding(String why) {
    lives -= 1;
    condition = 0;
    shake = 0.9;
    pitch = 0.12;
    vy = 0;
    _wrecked = true;
    _rescue = true;
    HapticFeedback.heavyImpact();
    _burst(planeX, planeY, 40, const [Color(0xFFFFB04A), Color(0xFFFF3B3B), Colors.white], speed: 300, size: 5);
    if (lives <= 0) {
      lives = 0;
      _setPhase(FlightPhase.crashed);
      return;
    }
    _setPhase(FlightPhase.ground);
    _service = -1;
    mission.value?.hits += 2;
    _queueBanner(FlightBanner('Crash à l\'atterrissage', '$why · une vie en moins', color: ChachaColors.red));
    _say('Tour de ${_airport!.cityAt(year)}', Lingala.keba, 'Les secours arrivent. Zela moke : patiente.');
  }

  void _ground(double dt) {
    planeY = _planeOnGroundY + _groundShift;
    pitch += ((_wrecked ? 0.12 : 0) - pitch) * math.min(1, dt * 4);
    if (_wrecked) _smoke(dt);
    if (_service < 0) {
      // Freinage sur la piste
      groundSpeed = math.max(0, groundSpeed - _unit * (_wrecked ? 700 : 260) * dt);
      worldX += groundSpeed * dt;
      if (groundSpeed == 0) {
        _service = 0;
        _fuelAtLanding = fuel;
        _conditionAtLanding = condition;
        _payStopover();
      }
      _pushStopover();
      return;
    }
    _service += dt;
    final r = _rescue ? 2.5 : 0.0;
    double span(double a, double b) => ((_service - a - r) / (b - a)).clamp(0.0, 1.0);
    fuel = _fuelAtLanding + (_fuelTarget - _fuelAtLanding) * span(1.5, 4);
    final m = mission.value;
    if (m != null && _stopPurpose == 1 && !m.boarded && span(1.5, 4.5) >= 1) {
      m.boarded = true;
      passengers = math.min(type.seats, passengers + m.count);
      _hitWarned = false;
    }
    if (m != null && _stopPurpose == 2 && span(1.5, 4.5) >= 1) {
      passengers = math.max(0, passengers - m.count);
      final stars = m.stars;
      score += 300 * stars;
      money += m.count * 40;
      mission.value = null;
      _nextMission = t + 35;
      _stopPurpose = 0;
      if (!autopilot) addMission();
      _queueBanner(
        FlightBanner(
          'Mission réussie ${'★' * stars}${'☆' * (3 - stars)}',
          '${m.count} passagers déposés à ${m.to.cityAt(year)} · +${_fmt(m.count * 40)} ${currencyAt(year)} · ${pilotRank(missionsDone.value)}',
          color: const Color(0xFF7CF0A6),
        ),
      );
      _say('Passagers', Lingala.matondo, 'Merci commandant ${pilotName.value ?? ''} ! Nous sommes bien arrivés.');
    }
    condition = _conditionAtLanding + (100 - _conditionAtLanding) * span(2, 4.5);
    if (_wrecked && _service > r + 4.5) {
      _wrecked = false;
      _particles.removeWhere((p) => p.smoke);
    }
    if (_service >= 5.5 + r && _service - dt < 5.5 + r) {
      _say(
        'Tour de ${_airport!.cityAt(year)}',
        Lingala.tokende,
        'Contrôles faits. Roule jusqu\'à la piste, elle est libre.',
      );
    }
    if (_service >= 5.5 + r) groundSpeed = _unit * 90;
    // Roulage : demi-tour vers le taxiway, puis demi-tour pour s'aligner sur la piste.
    worldX += groundSpeed * dt * _facing;
    if (_service >= 7.5 + r) {
      // Aligné en bout de piste, prêt à redécoller.
      flash = 0.7;
      groundSpeed = 0;
      climb = 0;
      _runwayOrigin = worldX + planeX - _runwayStart * _unit - 60 * _unit;
      stopover.value = null;
      _rescue = false;
      _setPhase(FlightPhase.ready);
      _say('Tour de ${_airport!.cityAt(year)}', Lingala.tokende, 'Aligné sur la piste. Maintiens TURBO pour décoller.');
      return;
    }
    _pushStopover();
  }

  /// Sens de l'avion au roulage : 1 vers la droite, -1 pendant le demi-tour.
  double get _facing {
    if (phase != FlightPhase.ground || _service < 0) return 1;
    final r = _rescue ? 2.5 : 0.0;
    final p = ((_service - 5.5 - r) / 2).clamp(0.0, 1.0);
    return math.cos(p * math.pi * 2);
  }

  void _pushStopover() {
    final r = _rescue ? 2.5 : 0.0;
    double span(double a, double b) => _service < 0 ? 0 : ((_service - a - r) / (b - a)).clamp(0.0, 1.0);
    final step = _service < 0
        ? 'Freinage…'
        : _service < r
        ? 'Les pompiers éteignent le feu'
        : _service < 1.5 + r
        ? 'Le camion de kérosène arrive'
        : _service < 4.5 + r
        ? 'Plein de kérosène et entretien'
        : _service < 5.5 + r
        ? 'Contrôles avant le départ'
        : 'Roulage vers la piste';
    final m = mission.value;
    final boarding = m == null || _stopPurpose == 0 ? null : span(1.5, 4.5);
    stopover.value = StopoverHud(
      _airport!.titleAt(year),
      span(1.5, 4),
      span(2, 4.5),
      span(4.5, 5.5),
      _service >= 5.5 + r ? 'Demi-tour et roulage vers la piste' : step,
      rescue: r > 0,
      boarding: boarding,
      boardingLabel: _stopPurpose == 1 ? 'Embarquement' : 'Débarquement',
      fleet: fleetAt(year),
      current: type,
      bill: _bill,
    );
  }

  void _smoke(double dt) {
    if (_rng.nextDouble() < dt * 30) {
      _particles.add(
        _Particle(
          planeX + (_rng.nextDouble() - 0.6) * planeLength * 0.4,
          planeY - planeLength * 0.02,
          0,
          -40 * _unit,
          1.6,
          _rng.nextBool() ? const Color(0xFF3A3A3A) : const Color(0xFFFF8A1E),
          10 * _unit,
          smoke: true,
        ),
      );
    }
  }

  Offset get _volcanoCrater => Offset(_volcanoX, _h * 1.02 - _w * 0.5 * 0.42);

  // ------------------------------------------------- cabine, repas, argent

  static String _fmt(int v) {
    final s = v.abs().toString();
    final b = StringBuffer(v < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('\u202f');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Au sol : on paie les droits d'escale, puis le kérosène qu'on peut se payer.
  void _payStopover() {
    if (_rescue) {
      _fuelTarget = 100;
      _bill = 'Atterrissage d\'urgence : les secours sont gratuits';
      return;
    }
    final cur = currencyAt(year);
    money -= math.min(money, landingFee);
    final want = ((100 - fuel) * fuelPrice).round();
    final pay = math.min(money, want);
    money -= pay;
    _fuelTarget = math.min(100, fuel + pay / fuelPrice);
    _bill = 'Droits ${_fmt(landingFee)} $cur · kérosène ${_fmt(pay)} $cur${pay < want ? ' (plein partiel)' : ''}';
  }

  void _updateCabin(double dt) {
    // On gagne de l'argent en volant : un peu pour l'avion, un peu par passager.
    _moneyAcc += dt * (6 + passengers / 6);
    if (_moneyAcc >= 1) {
      money += _moneyAcc.floor();
      _moneyAcc -= _moneyAcc.floor();
    }
    final cur = currencyAt(year);
    if (cur != _lastCurrency) {
      _lastCurrency = cur;
      _queueBanner(
        FlightBanner(
          'Nouvelle monnaie',
          'Ton portefeuille passe en ${switch (cur) {
            'Z' => 'zaïres',
            'NZ' => 'nouveaux zaïres',
            _ => 'francs congolais',
          }}',
          color: ChachaColors.yellow,
        ),
      );
    }

    final c = cabin.value;
    if (c != null) {
      _cabinT += dt;
      switch (c.mode) {
        case CabinMode.beltsAsk:
          if (autopilot && showcase != 'ceintures' && _cabinT > 1) fastenBelts();
          if (t > _beltsDeadline && showcase != 'ceintures') {
            // Personne n'a allumé le signal : les passagers sont secoués.
            shake = 0.6;
            condition = math.max(0, condition - 10);
            final m = mission.value;
            if (m != null && m.boarded) m.hits++;
            _queueBanner(
              const FlightBanner(
                'Passagers secoués !',
                'Le signal des ceintures n\'était pas allumé',
                color: Color(0xFFFF7A7A),
              ),
            );
            HapticFeedback.heavyImpact();
            fastenBelts();
          }
        case CabinMode.beltsFastening:
          final p = math.min(1.0, _cabinT / 2.2);
          cabin.value = CabinHud(CabinMode.beltsFastening, p, c.seats, c.title, c.detail);
          if (p >= 1) {
            _cabinT = 0;
            cabin.value = CabinHud(
              CabinMode.beltsDone,
              1,
              c.seats,
              'Ceintures attachées',
              'Les ${c.seats} passagers sont bouclés',
            );
          }
        case CabinMode.serving:
          final p = math.min(1.0, _cabinT / 6);
          cabin.value = CabinHud(CabinMode.serving, p, c.seats, c.title, c.detail);
          if (p >= 1) {
            _cabinT = 0;
            score += 100;
            money += _sales;
            _talk(TalkMoment.meal);
            cabin.value = CabinHud(
              CabinMode.served,
              1,
              c.seats,
              'Les ${c.seats} passagers sont servis',
              'Boissons vendues : +${_fmt(_sales)} ${currencyAt(year)}',
            );
            _say(
              'Cabine',
              Lingala.matondo,
              'Le commandant ${pilotName.value ?? ''} et le copilote mangent aussi : $_menu. Bon appétit !'.replaceAll(
                '  ',
                ' ',
              ),
            );
          }
        case CabinMode.beltsDone:
        case CabinMode.served:
          if (_cabinT > 2.6) cabin.value = null;
      }
    }
    if (_turbulence > 0) {
      _turbulence -= dt;
      if (_rng.nextDouble() < dt * 2.5) shake = math.max(shake, 0.12);
      vy += (_rng.nextDouble() - 0.5) * _h * dt * 3;
    }

    final free = cabin.value == null && quiz.value == null && _zone == null && !_offerPending && passengers > 0;
    if (free && t >= _nextBelts) {
      _askBelts('Zone de turbulences droit devant');
    } else if (free && t >= _nextMeal && _turbulence <= 0) {
      _offerMeal();
    }
  }

  /// La tour annonce des turbulences : le pilote doit allumer le signal des ceintures.
  void _askBelts(String why) {
    if (cabin.value?.mode == CabinMode.beltsAsk || passengers == 0) return;
    _nextBelts = t + 80 + _rng.nextDouble() * 40;
    _cabinT = 0;
    _beltsDeadline = t + 6;
    final seats = passengers;
    cabin.value = CabinHud(CabinMode.beltsAsk, 0, seats, 'Attachez vos ceintures', why);
    _say(
      'Tour de contrôle',
      Lingala.mikaba,
      '$why : allume le signal des ceintures pour tes $seats passagers.',
      seconds: 6,
    );
    HapticFeedback.selectionClick();
  }

  void fastenBelts() {
    final c = cabin.value;
    if (c == null || c.mode != CabinMode.beltsAsk) return;
    _cabinT = 0;
    if (_zone == null) _turbulence = 8;
    cabin.value = CabinHud(
      CabinMode.beltsFastening,
      0,
      c.seats,
      'Attachez vos ceintures',
      'Clic, clic… les passagers se bouclent',
    );
    HapticFeedback.mediumImpact();
  }

  void _offerMeal() {
    _nextMeal = t + 110 + _rng.nextDouble() * 40;
    _mealWait = 0;
    meal.value = MealOffer(passengers);
    _say(
      'Cabine',
      Lingala.tolia,
      'C\'est l\'heure du repas ! Choisis le plat du jour et les boissons du chariot.',
      seconds: 6,
    );
    _pushHud();
  }

  /// Le pilote choisit le plat du jour, le même pour tout le monde, et les boissons du chariot ;
  /// chaque passager prend la boisson qu'il veut parmi celles-là. Puis le chariot passe dans l'allée.
  void serveMeal(String base, String dish, List<String> drinks) {
    if (drinks.isEmpty) return;
    meal.value = null;
    final served = math.max(1, passengers);
    // Chacun se sert : les goûts se répartissent au hasard, sans être égaux.
    final weights = [for (final _ in drinks) 0.5 + _rng.nextDouble()];
    final total = weights.reduce((a, b) => a + b);
    final counts = [for (final w in weights) (served * w / total).floor()];
    counts[0] += served - counts.reduce((a, b) => a + b);
    final order = List.generate(drinks.length, (i) => i)..sort((a, b) => counts[b].compareTo(counts[a]));
    _sales = 0;
    for (var i = 0; i < drinks.length; i++) {
      _sales += counts[i] * drinkPrice(drinks[i]);
    }
    final pilotDrink = drinks.firstWhere(
      (d) => !mealSpirits.contains(d) && !mealBeers.contains(d),
      orElse: () => 'Eau',
    );
    _menu =
        '${base.toLowerCase()} et ${dish.toLowerCase()}, avec un verre de $pilotDrink (pas d\'alcool aux commandes)';
    _cabinT = 0;
    cabin.value = CabinHud(
      CabinMode.serving,
      0,
      served,
      'Plat du jour : $base et $dish',
      [
        for (final i in order.take(4))
          if (counts[i] > 0) '${counts[i]} ${drinks[i]}',
      ].join(' · '),
    );
    _pushHud();
  }

  int _sales = 0;

  // ------------------------------------------------- avion, missions, quiz

  void _showPlaneCard(String title) {
    planeCard.value = PlaneCard(type, _airline.name, passengers, title);
    _planeCardTimer = 5;
  }

  /// Change d'avion (nouvelle époque, ou choix du joueur pendant une escale).
  void changeAircraft(AircraftType t) {
    if (phase != FlightPhase.ground || !t.fliesIn(year) || t == type) return;
    _changeAircraft(t);
  }

  void _changeAircraft(AircraftType t) {
    type = t;
    passengers = math.min(passengers, t.seats);
    flash = 0.8;
    _burst(planeX, planeY, 30, const [Colors.white, ChachaColors.yellow], speed: 260);
    _queueBanner(
      FlightBanner(
        'Nouvel avion · ${t.maker} ${t.name}',
        '${t.seats} places · ${t.story}',
        color: ChachaColors.skyLight,
      ),
    );
    _showPlaneCard('Nouvel avion');
    if (phase == FlightPhase.ground) _pushStopover();
  }

  /// Les villes difficiles de chaque époque, où les passagers doivent arriver quand même.
  (Airport, String)? _hardCity() {
    Airport city(String name) => airports.firstWhere((a) => a.city == name);
    if (year >= 2016.6 && year < 2017.9) return (city('Kananga'), 'Kasaï : violences de Kamuina Nsapu');
    if (year >= 2007.0 && year < 2008.5) return (city('Matadi'), 'Bas-Congo : affrontements de Bundu dia Kongo');
    if ((year >= 2002.0 && year < 2002.6) || (year >= 2021.4 && year < 2021.7)) {
      return (city('Goma'), 'Goma : le Nyiragongo en éruption');
    }
    if ((year >= 2012.88 && year < 2013.9) || (year >= 2021.9 && year < 2025.08)) {
      return (city('Goma'), 'Goma : la guerre est proche');
    }
    return null;
  }

  void _checkMission() {
    final m = mission.value;
    if (_zone != null || _offerPending) return;
    if (m == null) {
      if (t < _nextMission) return;
      final open = [
        for (final a in airports)
          if (a.openAt(year)) a,
      ];
      final hard = _hardCity();
      final to = hard?.$1 ?? open[_rng.nextInt(open.length)];
      var from = open[_rng.nextInt(open.length)];
      while (from == to) {
        from = open[_rng.nextInt(open.length)];
      }
      final room = type.seats - passengers;
      if (room < 10) {
        _nextMission = t + 20;
        return;
      }
      final count = math.max(8, (room * (0.4 + _rng.nextDouble() * 0.5)).round());
      final next = Mission(from, to, count, hard?.$2 ?? '');
      mission.value = next;
      _airport = from;
      _stopPurpose = 1;
      _openOffer(
        Lingala.mbote,
        'Mission : $count passagers attendent à ${from.cityAt(year)}. Destination : ${to.cityAt(year)}.',
        from.cityAt(year),
      );
    } else if (m.boarded && t - _missionSince > 22) {
      _airport = m.to;
      _stopPurpose = 2;
      _gusty = m.why.isNotEmpty;
      _openOffer(
        m.why.isNotEmpty ? Lingala.keba : Lingala.tokende,
        m.why.isNotEmpty
            ? 'Approche de ${m.to.cityAt(year)}. ${m.why}. Tes passagers comptent sur toi.'
            : 'Approche de ${m.to.cityAt(year)} : tes ${m.count} passagers arrivent.',
        m.to.cityAt(year),
      );
    } else if (!m.boarded && t >= _nextOffer) {
      _airport = m.from;
      _stopPurpose = 1;
      _openOffer(
        Lingala.mbote,
        'Les ${m.count} passagers attendent toujours à ${m.from.cityAt(year)}.',
        m.from.cityAt(year),
      );
    }
  }

  void _openOffer(String lingala, String french, String city) {
    _offerPending = true;
    _offerAt = t;
    _nextKit = math.max(_nextKit, t + 15);
    _say('Tour de $city', lingala, french, offer: city, seconds: 10);
    HapticFeedback.selectionClick();
  }

  void _askQuiz() {
    final past = [
      for (final e in historyEvents)
        if (e.year < year - 0.3 && !_askedQuiz.contains(e.title)) e,
    ];
    if (past.length < 4) return;
    _quizCount++;
    _nextQuiz = t + 70;
    _quizWait = 0;
    final e = past[_rng.nextInt(past.length)];
    _askedQuiz.add(e.title);
    final byYear = _rng.nextBool();
    late final List<String> options;
    late final String question;
    if (byYear) {
      final y = e.yearLabel;
      final years = <int>{y};
      while (years.length < 3) {
        final d = 2 + _rng.nextInt(10);
        final c = _rng.nextBool() ? y + d : y - d;
        if (c >= 1960 && c <= 2027) years.add(c);
      }
      options = [for (final v in years.toList()..shuffle(_rng)) '$v'];
      question = 'En quelle année : ${e.title} (${e.city}) ?';
    } else {
      final others = [
        for (final o in historyEvents)
          if (o.title != e.title && (o.year - e.year).abs() > 2) o,
      ]..shuffle(_rng);
      options = [e.title, others[0].title, others[1].title]..shuffle(_rng);
      question = 'Que s\'est-il passé en ${e.date}, à ${e.city} ?';
    }
    quiz.value = Quiz(question, options, options.indexOf(byYear ? '${e.yearLabel}' : e.title), e);
    _say(
      'Tour de contrôle',
      Lingala.mafuta,
      'Plus de kérosène ! Réponds juste et un ravitaillement arrive.',
      seconds: 6,
    );
    _pushHud();
  }

  void answerQuiz(int i) {
    final q = quiz.value;
    if (q == null) return;
    quiz.value = null;
    if (i == q.answer) {
      fuel = math.min(100, fuel + 55);
      score += 150;
      _confetti();
      onSong?.call(q.event.song ?? 'chacha');
      _say('Tour de contrôle', Lingala.elonga, 'Bonne réponse ! Ravitaillement en vol : +55 % de kérosène.');
    } else {
      fuel = math.min(100, fuel + 15);
      _say(
        'Tour de contrôle',
        Lingala.makasi,
        'La réponse était « ${q.options[q.answer]} ». Un petit bidon quand même.',
      );
    }
    _pushHud();
  }

  // ------------------------------------------------------ zones de turbulence

  void _saveCheckpoint(double y) {
    final cp = Checkpoint(y, score, medals);
    checkpoint.value = cp;
    if (!autopilot) cp.save();
  }

  void _checkDecade() {
    final d = (year / 10).floor();
    if (d == _decade) return;
    _decade = d;
    _saveCheckpoint(year);
  }

  void _checkZone() {
    if (_zone != null || _nextZone >= warZones.length || year < warZones[_nextZone].from) return;
    final z = warZones[_nextZone++];
    _zone = z;
    final span = (z.to - z.from) / z.waves;
    // En reprenant au milieu d'une zone, les vagues déjà passées comptent.
    _wavesCleared = _wave = ((year - z.from) / span).floor().clamp(0, z.waves - 1);
    year = math.max(year, z.from);
    _waveActive = false;
    _waveDelay = 3.4;
    _saveCheckpoint(z.from + span * _wavesCleared);
    shake = 0.35;
    HapticFeedback.heavyImpact();
    _queueBanner(
      FlightBanner('Zone de turbulence', 'Tu arrives dans un moment de turbulence · ${z.name}', color: _warRed),
    );
    if (passengers > 0) _askBelts('Zone de guerre droit devant');
    _talk(TalkMoment.war, force: true);
    _comfort();
    _queueBanner(
      const FlightBanner(
        Lingala.keba,
        '« Attention ! Le désordre est devant » · évite les avions de chasse',
        color: _warRed,
      ),
    );
  }

  void _updateZone(double dt) {
    final z = _zone!;
    final span = (z.to - z.from) / z.waves;
    final target = _wavesCleared >= z.waves ? z.to : z.from + span * (_wavesCleared + (_waveActive ? 0.7 : 0));
    year = math.min(target, year + dt * span / 3.2);

    if (_waveActive) {
      if (_jets.isEmpty) {
        _waveActive = false;
        _wavesCleared++;
        score += 100 * _wavesCleared;
        _waveDelay = 1.6;
      }
    } else {
      _waveDelay -= dt;
      if (_waveDelay > 0) return;
      if (_wavesCleared < z.waves) {
        _launchWave();
      } else if (year >= z.to) {
        _exitZone();
      }
    }
  }

  void _launchWave() {
    _wave = _wavesCleared + 1;
    _waveActive = true;
    // Six couloirs : deux avions qui se suivent ne prennent jamais le même.
    final lanes = [for (var i = 0; i < 6; i++) _h * (0.17 + i * 0.13)];
    var last = -1, before = -1;
    for (var i = 0; i < _wave; i++) {
      int lane;
      do {
        lane = _rng.nextInt(lanes.length);
      } while (lane == last || lane == before);
      before = last;
      last = lane;
      // Dès la troisième vague, certains avions dérivent vers toi.
      final drift = _wave >= 3 && _rng.nextBool() ? ((planeY - lanes[lane]) * 0.22).clamp(-_h * 0.12, _h * 0.12) : 0.0;
      _jets.add(_Jet(_w + _jetLength, lanes[lane], i * 0.55, _unit * (560 + 90 * _wave), drift));
    }
    if (_wave > 1) HapticFeedback.selectionClick();
    _pushHud();
  }

  void _exitZone() {
    final z = _zone!;
    _zone = null;
    _waveActive = false;
    lives = math.min(9, lives + 1);
    score += 500;
    flash = 0.5;
    _peace = 7;
    _confetti();
    HapticFeedback.mediumImpact();
    _saveCheckpoint(z.to);
    _queueBanner(
      FlightBanner(
        '${Lingala.kimia} · ${z.peaceTitle}',
        '« La paix est revenue » · ${z.peaceText}',
        color: _peaceGreen,
      ),
    );
    _talk(TalkMoment.peace, force: true);
    _queueBanner(
      const FlightBanner('Étape de paix', '+1 vie · +500 points · la réconciliation continue', color: _peaceGreen),
    );
    _pushHud();
  }

  static const _warRed = Color(0xFFFF7A7A);
  static const _peaceGreen = Color(0xFF7CF0A6);

  double get _jetLength => planeLength * 0.52;

  void _checkEras() {
    final a = airlineAt(year);
    if (!identical(a, _airline)) {
      _airline = a;
      flash = 1;
      _burst(planeX, planeY, 40, const [Colors.white, ChachaColors.yellow, ChachaColors.skyLight], speed: 320);
      _queueBanner(FlightBanner('${a.from.floor()} · ${a.name}', a.note));
      HapticFeedback.mediumImpact();
      final next = aircraftById(a.flagship);
      if (next != type && phase == FlightPhase.cruising) _changeAircraft(next);
    }
    if (!type.fliesIn(year) && phase == FlightPhase.cruising) _changeAircraft(aircraftById(a.flagship));
    final f = flagAt(year);
    if (!identical(f, _flag)) {
      _flag = f;
      _queueBanner(FlightBanner('${f.from.floor()} · ${f.label}', 'Le drapeau change', color: ChachaColors.skyLight));
    }
  }

  void _updateWorld(double dt, double ts) {
    final move = groundSpeed * dt;
    // Nuages : plus ils sont proches, plus ils défilent vite
    for (final c in _clouds) {
      c.x -= move * (c.storm ? 1 : c.depth) + (phase == FlightPhase.ready ? 6 * _unit * dt : 0);
      if (c.storm) {
        c.flash = math.max(0, c.flash - dt * 3);
        if (_rng.nextDouble() < dt * 0.8) c.flash = 1;
        if (phase == FlightPhase.cruising && _hits(c.x, c.y, c.r * 1.2)) _loseLife();
      }
    }
    _clouds.removeWhere((c) => c.x < -c.r * 4);

    for (final j in _jets) {
      if (j.wait > 0) {
        j.wait -= dt;
        continue;
      }
      if (j.warn > 0) {
        j.warn -= dt;
        continue;
      }
      j.x -= move + j.speed * dt;
      j.y += j.drift * dt;
      if (!j.hit && phase == FlightPhase.cruising && _hits(j.x, j.y, _jetLength * 0.16)) {
        j.hit = true;
        _loseLife();
      }
    }
    _jets.removeWhere((j) => j.x < -_jetLength);
    _zoneFade = (_zoneFade + (_zone != null ? dt : -dt) * 0.8).clamp(0.0, 1.0);

    // Le volcan défile lentement, loin en bas, et crache des bombes de lave.
    _volcanoX -= move * 0.14;
    if (t < _volcanoUntil && t >= _nextBomb && _volcanoX < _w * 1.05 && _volcanoX > _w * 0.2) {
      _nextBomb = t + 0.45 + _rng.nextDouble() * 0.4;
      final crater = _volcanoCrater;
      _bombs.add(
        _Particle(
          crater.dx,
          crater.dy,
          (-140 - _rng.nextDouble() * 260) * _unit,
          -_h * (1.05 + _rng.nextDouble() * 0.5),
          6,
          const Color(0xFFFF7A1E),
          (7 + _rng.nextDouble() * 6) * _unit,
        ),
      );
    }
    for (final b in _bombs) {
      b.age += dt;
      b.x += (b.vx - move / dt * 0.14) * dt;
      b.y += b.vy * dt;
      b.vy += _h * 0.95 * dt;
      if (phase == FlightPhase.cruising && b.life > 0 && _hits(b.x, b.y, b.size)) {
        b.life = 0;
        _loseLife();
      }
      if (_rng.nextDouble() < dt * 20) {
        _particles.add(_Particle(b.x, b.y, 0, -20 * _unit, 0.8, const Color(0xFF4A4040), b.size * 0.8, smoke: true));
      }
    }
    _bombs.removeWhere((b) => b.life <= 0 || b.y > _h + 40);
    for (final g in _gifts) {
      g.y += g.vy * dt;
      g.rot += dt * 1.5;
    }
    _gifts.removeWhere((g) => g.y > _h + 60);
    _peace = math.max(0, _peace - dt);

    final rx = planeLength * 0.42;
    for (final p in _pickups) {
      p.x -= move;
      if (magnetTime > 0 && !p.taken) {
        final d = Offset(planeX - p.x, planeY - p.y);
        if (d.distance < 320 * _unit) {
          p.x += d.dx * dt * 4;
          p.y += d.dy * dt * 4;
        }
      }
      if (!p.taken && phase == FlightPhase.cruising && _hits(p.x, p.y, p.radius * _unit)) {
        p.taken = true;
        _collect(p);
      }
      if (!p.taken && p.x < -rx && p.kind == _PickupKind.medal) {
        p.taken = true;
        _showCard(p.event!, caught: false);
      }
    }
    _pickups.removeWhere((p) => p.taken || p.x < -100);

    for (final p in _particles) {
      p.age += dt;
      p.x += p.vx * dt - (p.smoke ? move * 0.6 : 0);
      p.y += p.vy * dt;
      p.vy += (p.smoke ? -10 : 60) * _unit * dt;
      p.rot += dt * 6;
    }
    _particles.removeWhere((p) => p.age > p.life);

    // Traînée aux couleurs du drapeau quand on met les gaz
    for (var i = 0; i < _trail.length; i++) {
      _trail[i] = _trail[i].translate(-move, 0);
    }
    if (boost && (phase == FlightPhase.cruising || phase == FlightPhase.climbing)) {
      _trail.add(_tail());
    } else if (_trail.isNotEmpty) {
      _trail.removeAt(0);
    }
    while (_trail.length > 40) {
      _trail.removeAt(0);
    }
  }

  Offset _tail() {
    final back = Offset(-planeLength * 0.47, -planeLength * 0.01);
    final c = math.cos(pitch), s = math.sin(pitch);
    return Offset(planeX + back.dx * c - back.dy * s, planeY + back.dx * s + back.dy * c);
  }

  bool _hits(double x, double y, double r) {
    final rx = planeLength * 0.42 + r, ry = planeLength * 0.09 + r;
    final dx = x - planeX, dy = y - planeY;
    return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) < 1;
  }

  void _collect(_Pickup p) {
    switch (p.kind) {
      case _PickupKind.medal:
        final e = p.event!;
        final glory = e.kind == EventKind.glory;
        lives = math.min(9, lives + 1);
        // Chaque vie rapporte aussi un peu de kérosène.
        fuel = math.min(100, fuel + 15);
        score += glory ? 300 : 150;
        medals++;
        money += 150;
        caught.add(e.title);
        _showCard(e);
        _burst(p.x, p.y, 30, const [ChachaColors.yellow, Colors.white, Color(0xFFFFE9A0)], speed: 300);
        if (glory) {
          _confetti();
          _talk(TalkMoment.glory);
        }
        HapticFeedback.lightImpact();
      case _PickupKind.star:
        score += 10;
        _burst(p.x, p.y, 8, const [ChachaColors.yellow, Colors.white], speed: 140, size: 3);
      case _PickupKind.fuel:
        fuel = math.min(100, fuel + 32);
        score += 20;
        _burst(p.x, p.y, 10, const [ChachaColors.red, Colors.white], speed: 160, size: 3);
      case _PickupKind.repair:
        fuel = 100;
        condition = 100;
        score += 80;
        _burst(p.x, p.y, 24, const [Color(0xFF7CF0A6), Colors.white], speed: 220, size: 4);
        _say('Tour de contrôle', Lingala.matondo, 'Plein et entretien faits en vol : pas besoin de descendre.');
        HapticFeedback.mediumImpact();
    }
    _pushHud();
  }

  void _pushHud() {
    hud.value = HudState(
      phase: phase,
      year: year,
      airline: _airline.name,
      flag: _flag.style,
      lives: lives,
      score: score,
      fuel: fuel,
      speed: groundSpeed / (_unit * 560),
      magnetReady: 1 - magnetCooldown / 10,
      medals: medals,
      tiltAvailable: tilt.available,
      altitude: phase == FlightPhase.ground || phase == FlightPhase.ready || phase == FlightPhase.rolling
          ? 0
          : math.max(
              0,
              math.pow(climb, 1.4) * 30000 +
                  (groundY - planeY - (type.bodyHeight / 2 + 7.7) * planeLength / 100) / _h * 4000,
            ),
      // Le TURBO pousse l'avion, sans dépasser une vitesse de ligne crédible.
      speedKmh: () {
        final r = groundSpeed / (_unit * 560);
        return r <= 1 ? r * 820 : 820 + (r - 1) * 150;
      }(),
      pitch: pitch,
      condition: condition,
      inZone: _zone != null,
      airport: _airport == null ? "Léopoldville · N'djili" : _airport!.titleAt(year),
      firstFlight: _takeoffs == 0,
      passengers: passengers,
      seats: type.seats,
      money: money,
      currency: currencyAt(year),
      finale: _finaleT >= 0 && phase != FlightPhase.finished,
    );
    final z = _zone;
    zoneHud.value = z == null
        ? null
        : ZoneHud(
            z,
            _waveActive ? _wave : math.min(z.waves, _wavesCleared + 1),
            _waveActive,
            ((year - z.from) / (z.to - z.from)).clamp(0.0, 1.0),
          );
  }

  // ----------------------------------------------------------------- dessin

  @override
  void render(Canvas canvas) {
    final s = Size(_w, _h);
    canvas.save();
    if (shake > 0) canvas.translate((_rng.nextDouble() - 0.5) * 14 * shake, (_rng.nextDouble() - 0.5) * 14 * shake);

    final day = (phase.index >= FlightPhase.cruising.index || _takeoffs > 0) ? 1.0 : climb * 0.9;
    final stormy = math.max(year < stormUntil && phase == FlightPhase.cruising ? 1.0 : 0.0, _zoneFade * 0.75);
    Scenery.sky(canvas, s, day, stormy, slowMo > 0 ? math.min(1, slowMo) : 0);
    if (_zoneFade > 0) {
      // Ciel de guerre : une lueur rouge sombre monte de l'horizon.
      canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(60, 8, 12, 0.35 * _zoneFade),
              Color.fromRGBO(140, 24, 20, 0.42 * _zoneFade),
              Color.fromRGBO(230, 80, 20, 0.6 * _zoneFade),
            ],
          ).createShader(Offset.zero & s),
      );
    }
    if (_peace > 0) _drawPeace(canvas, s);
    if (_boil > 0) _drawBoil(canvas, s);
    Scenery.sun(canvas, s, Offset(_w * 0.78, _groundY0 - _h * 0.12 + _groundShift * 0.25 - day * _h * 0.45), day);

    for (final c in _clouds.where((c) => !c.storm && c.depth < 0.6)) {
      Scenery.cloud(canvas, Offset(c.x, c.y), c.r);
    }

    final hillBase = _groundY0 + _groundShift * 0.55;
    Scenery.hills(
      canvas,
      s,
      worldX * 0.15,
      hillBase - 10 * _unit,
      90 * _unit,
      Color.lerp(const Color(0xFF6A5A9A), const Color(0xFF7FA6D6), day)!,
      1.3,
    );
    Scenery.hills(
      canvas,
      s,
      worldX * 0.3,
      hillBase + 4 * _unit,
      60 * _unit,
      Color.lerp(const Color(0xFF43406E), const Color(0xFF5C8A6E), day)!,
      4.1,
    );

    if (_volcanoX > -_w) {
      final fury = t < _volcanoUntil ? 1.0 : math.max(0.3, 1 - (t - _volcanoUntil) / 4);
      Scenery.volcano(canvas, Offset(_volcanoX, _h * 1.02), _w * 0.5, t, fury);
    }
    for (final b in _bombs) {
      Scenery.glow(canvas, Offset(b.x, b.y), b.size * 0.7, b.color);
    }

    if (groundY < _h + 300 * _unit) {
      final dusk = 1 - day;
      final gx = worldX - _runwayOrigin;
      Scenery.city(canvas, s, gx * 0.5, groundY - 8 * _unit, _unit, dusk);
      Scenery.tower(canvas, Offset(260 * _unit - gx * 0.85, groundY - 6 * _unit), _unit, t, dusk);
      for (var i = 0; i < 26; i++) {
        final x = i * 230 * _unit + 80 * _unit - gx * 0.92;
        if (x > -60 && x < _w + 60) {
          Scenery.palm(canvas, Offset(x, groundY - 5 * _unit), (46 + (i * 37) % 30) * _unit, const Color(0xFF16261C));
        }
      }
      Scenery.runway(canvas, s, gx, groundY, _runwayStart * _unit, _runwayEnd * _unit, _unit, t);
      // Ombre de l'avion sur la piste
      final alt = (groundY - planeY) / _h;
      if (alt < 1.2) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(planeX, groundY + 10 * _unit),
            width: planeLength * (0.9 - alt * 0.4),
            height: 10 * _unit,
          ),
          Paint()
            ..color = Color.fromRGBO(0, 0, 0, (0.45 - alt * 0.35).clamp(0, 1))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    for (final c in _clouds.where((c) => c.storm)) {
      Scenery.cloud(canvas, Offset(c.x, c.y), c.r, storm: true, flash: c.flash);
    }

    for (final p in _pickups) {
      final at = Offset(p.x, p.y);
      switch (p.kind) {
        case _PickupKind.medal:
          Scenery.medal(canvas, at, p.radius * _unit, t, p.label!, glory: p.event!.kind == EventKind.glory);
        case _PickupKind.star:
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(t * 2 + p.y);
          Scenery.glow(canvas, Offset.zero, 2 * _unit, ChachaColors.yellow);
          canvas.drawPath(_star(p.radius * _unit), Paint()..color = ChachaColors.yellow);
          canvas.restore();
        case _PickupKind.fuel:
          Scenery.fuelCan(canvas, at, p.radius * _unit);
        case _PickupKind.repair:
          Scenery.repairKit(canvas, at, p.radius * _unit, t);
      }
    }

    _drawTrail(canvas);
    if (phase == FlightPhase.approach) _drawGlidePath(canvas);
    if (phase == FlightPhase.ground) _drawCrew(canvas, behind: true);
    _drawPlane(canvas);
    if (phase == FlightPhase.ground) _drawCrew(canvas, behind: false);
    for (final j in _jets) {
      if (j.wait > 0) continue;
      j.warn > 0 ? _drawWarning(canvas, j) : _drawJet(canvas, j);
    }

    for (final c in _clouds.where((c) => !c.storm && c.depth >= 0.6)) {
      Scenery.cloud(canvas, Offset(c.x, c.y), c.r * 1.2);
    }

    for (final g in _gifts) {
      Scenery.gift(canvas, Offset(g.x, g.y), g.size, math.sin(g.rot) * 0.4);
    }
    for (final p in _particles) {
      final a = (1 - p.age / p.life).clamp(0.0, 1.0);
      if (p.smoke) {
        canvas.drawCircle(
          Offset(p.x, p.y),
          p.size * (1 + p.age * 1.6),
          Paint()
            ..color = p.color.withValues(alpha: a * 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        continue;
      }
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        Paint()..color = p.color.withValues(alpha: a),
      );
      canvas.restore();
    }

    if (magnetTime > 0) {
      canvas.drawCircle(
        Offset(planeX, planeY),
        320 * _unit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Color.fromRGBO(255, 255, 255, 0.25 * magnetTime / 3),
      );
    }
    if (flash > 0) canvas.drawRect(Offset.zero & s, Paint()..color = Color.fromRGBO(255, 255, 255, 0.6 * flash));
    canvas.restore();
    super.render(canvas);
  }

  Path _star(double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.42;
      final a = -math.pi / 2 + i * math.pi / 5;
      i == 0 ? p.moveTo(math.cos(a) * rr, math.sin(a) * rr) : p.lineTo(math.cos(a) * rr, math.sin(a) * rr);
    }
    return p..close();
  }

  void _drawTrail(Canvas canvas) {
    if (_trail.length < 2) return;
    final path = Path()..moveTo(_trail.first.dx, _trail.first.dy);
    for (final o in _trail.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    path.lineTo(_tail().dx, _tail().dy);
    final b = path.getBounds();
    Shader fade(Color c) => LinearGradient(
      colors: [c.withValues(alpha: 0), c],
    ).createShader(Rect.fromLTRB(b.left, b.top - 1, b.right + 1, b.bottom + 1));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = planeLength * 0.11
        ..shader = fade(ChachaColors.yellow),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = planeLength * 0.075
        ..shader = fade(ChachaColors.red),
    );
  }

  /// Ébullition : le ciel bout aux grands tournants de l'histoire.
  void _drawBoil(Canvas canvas, Size s) {
    final a = math.min(1.0, _boil / 1.5) * math.min(1.0, (4.5 - _boil) * 2);
    for (var i = 0; i < 6; i++) {
      final r = ((t * 0.6 + i / 6) % 1) * _w * 0.9;
      canvas.drawCircle(
        Offset(_w * 0.5, _h * 0.55),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _h * 0.06
          ..color = Color.lerp(
            ChachaColors.red,
            ChachaColors.yellow,
            i / 6,
          )!.withValues(alpha: 0.18 * a * (1 - r / (_w * 0.9)))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    canvas.drawRect(Offset.zero & s, Paint()..color = Color.fromRGBO(255, 120, 40, 0.12 * a));
  }

  /// Le couloir d'approche : des anneaux jaunes jusqu'à la piste.
  void _drawGlidePath(Canvas canvas) {
    for (var k = 1; k <= 7; k++) {
      final dt = k * 0.55;
      if (_approachT + dt > _approachTime) break;
      final x = planeX + _approachSpeed * dt;
      final y = _glide(_approachT + dt);
      final r = (26 - k * 1.5) * _unit;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 0.8, height: r * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * _unit
          ..color = ChachaColors.yellow.withValues(alpha: 0.75 - k * 0.08),
      );
    }
  }

  /// L'équipe au sol : camion de kérosène, mécaniciens, pompiers après un crash.
  void _drawCrew(Canvas canvas, {required bool behind}) {
    if (_service < 0) return;
    final ground = groundY - 4 * _unit;
    final r = _rescue ? 2.5 : 0.0;
    final leave = ((_service - 5.5 - r) / 1.5).clamp(0.0, 1.0);
    if (behind) {
      final arrive = Curves.easeOut.transform(((_service - r) / 1.5).clamp(0.0, 1.0));
      final truckX = _w + 200 * _unit + (planeX + planeLength * 0.3 - _w - 200 * _unit) * arrive + leave * _w;
      Scenery.fuelTruck(canvas, Offset(truckX, ground), _unit, hose: _service > 1.5 + r && _service < 4.2 + r ? 1 : 0);
      if (r > 0 && _service < r + 2) {
        final fx =
            _w +
            200 * _unit +
            (planeX + planeLength * 0.55 - _w - 200 * _unit) *
                Curves.easeOut.transform((_service / 1.2).clamp(0.0, 1.0));
        Scenery.fireTruck(canvas, Offset(fx, ground), _unit, t);
      }
      return;
    }
    if (_service < 1.2 + r || leave >= 1) return;
    Scenery.crew(canvas, Offset(planeX - planeLength * 0.12, ground), _unit, t * 6);
    Scenery.crew(canvas, Offset(planeX + planeLength * 0.18, ground), _unit, t * 4 + 1, vest: const Color(0xFFF7D618));
    if (_service > 4.5 + r) {
      Scenery.crew(canvas, Offset(planeX + planeLength * 0.45, ground), _unit, t * 8, vest: const Color(0xFF7CF0A6));
    }
  }

  /// L'étape de paix : un arc aux couleurs du drapeau se lève dans le ciel.
  void _drawPeace(Canvas canvas, Size s) {
    final a = math.min(1.0, _peace / 2) * math.min(1.0, (7 - _peace) * 1.5);
    final c = Offset(_w * 0.62, _h * 1.05);
    for (final (i, col) in [ChachaColors.red, ChachaColors.yellow, ChachaColors.sky].indexed) {
      canvas.drawCircle(
        c,
        _h * (0.78 - i * 0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _h * 0.045
          ..color = col.withValues(alpha: 0.3 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _drawWarning(Canvas canvas, _Jet j) {
    final pulse = 0.55 + 0.45 * math.sin(j.warn * 22);
    final at = Offset(_w - 34 * _unit, j.y);
    canvas.drawCircle(at, 22 * _unit, Paint()..color = Color.fromRGBO(206, 16, 33, 0.35 * pulse));
    final tri = Path()
      ..moveTo(at.dx - 14 * _unit, at.dy)
      ..lineTo(at.dx + 6 * _unit, at.dy - 12 * _unit)
      ..lineTo(at.dx + 6 * _unit, at.dy + 12 * _unit)
      ..close();
    canvas.drawPath(tri, Paint()..color = Color.fromRGBO(255, 122, 122, pulse));
  }

  /// Silhouette noire d'avion de chasse, nez à gauche, sans aucune marque.
  void _drawJet(Canvas canvas, _Jet j) {
    final l = _jetLength;
    canvas.save();
    canvas.translate(j.x, j.y);
    canvas.rotate(math.atan2(-j.drift, j.speed) * 0.5);
    final bounds = Rect.fromLTRB(-l / 2, -l * 0.25, l / 2, l * 0.2);
    final dark = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A404C), Color(0xFF14171D), Color(0xFF050608)],
      ).createShader(bounds);

    // Postcombustion
    final flicker = 0.8 + 0.2 * math.sin(t * 60 + j.y);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(l * 0.56, 0), width: l * 0.22 * flicker, height: l * 0.07),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF1B0), Color(0xFFFF8A1E), Color(0x00FF3B00)],
        ).createShader(Rect.fromCenter(center: Offset(l * 0.56, 0), width: l * 0.24, height: l * 0.08))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Aile lointaine, dérive, fuselage, aile proche
    canvas.drawPath(
      Path()
        ..moveTo(-0.02 * l, -0.01 * l)
        ..lineTo(0.34 * l, -0.01 * l)
        ..lineTo(0.4 * l, -0.11 * l)
        ..lineTo(0.3 * l, -0.11 * l)
        ..close(),
      Paint()..color = const Color(0xFF0B0D11),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0.26 * l, -0.035 * l)
        ..lineTo(0.38 * l, -0.24 * l)
        ..lineTo(0.46 * l, -0.24 * l)
        ..lineTo(0.49 * l, -0.035 * l)
        ..close(),
      dark,
    );
    final body = Path()
      ..moveTo(-0.5 * l, 0.01 * l)
      ..quadraticBezierTo(-0.36 * l, -0.05 * l, -0.18 * l, -0.05 * l)
      ..lineTo(0.47 * l, -0.04 * l)
      ..lineTo(0.5 * l, -0.025 * l)
      ..lineTo(0.5 * l, 0.03 * l)
      ..lineTo(0.44 * l, 0.045 * l)
      ..lineTo(-0.28 * l, 0.04 * l)
      ..close();
    canvas.drawPath(body, dark);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x40FFFFFF),
    );
    // Verrière
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-0.24 * l, -0.055 * l), width: 0.17 * l, height: 0.055 * l),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6E7C92), Color(0xFF1C222C)],
        ).createShader(Rect.fromCenter(center: Offset(-0.24 * l, -0.06 * l), width: 0.17 * l, height: 0.06 * l)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-0.1 * l, 0.02 * l)
        ..lineTo(0.3 * l, 0.02 * l)
        ..lineTo(0.42 * l, 0.17 * l)
        ..lineTo(0.3 * l, 0.17 * l)
        ..close(),
      dark,
    );
    // Feu clignotant rouge
    if ((t * 2 + j.y) % 1 < 0.3) {
      Scenery.glow(canvas, Offset(0.44 * l, -0.24 * l), 2 * _unit, const Color(0xFFFF3B3B));
    }
    canvas.restore();
  }

  void _drawPlane(Canvas canvas) {
    if (invulnerable > 0 && (t * 10).floor().isEven) return;
    final len = planeLength;
    canvas.save();
    if (_wrecked) {
      // L'avion accidenté : noirci, fumant.
      canvas.saveLayer(null, Paint()..colorFilter = const ColorFilter.mode(Color(0x99201410), BlendMode.srcATop));
    }
    canvas.translate(planeX, planeY);
    canvas.rotate(pitch);
    final f = _facing;
    if (f != 1) canvas.scale(f.abs() < 0.08 ? 0.08 * f.sign : f, 1);
    canvas.translate(-len / 2, -len / 4);
    AircraftPainter.paint(
      canvas,
      Size(len, len / 2),
      type,
      _airline.livery,
      propPhase: t * 40,
      gear: gear,
      landingLight:
          phase == FlightPhase.rolling || phase == FlightPhase.ready || (phase == FlightPhase.climbing && climb < 0.5),
      blink: t,
    );
    if (_wrecked) canvas.restore();
    canvas.restore();
  }
}
