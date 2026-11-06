import 'dart:math' as math;
import 'dart:ui' as ui;

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
import '../data/traffic.dart';
import '../data/war_zones.dart';
import '../painting/aircraft_painter.dart';
import '../theme/chacha_colors.dart';
import 'checkpoint.dart';
import 'scenery.dart';
import 'telemetry.dart';
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
    this.planeLow = false,
    this.planeHigh = false,
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

  /// L'avion passe derrière le tableau de bord (en bas) ou derrière l'année (en haut) :
  /// le panneau s'efface pour qu'on voie toujours l'avion.
  final bool planeLow, planeHigh;
}

/// Une conversation dans la cabine : deux ou trois répliques, en lingala et en français.
class CabinTalk {
  const CabinTalk(this.lines, {this.at});

  final List<TalkLine> lines;

  /// Où placer les bulles : sur notre avion par défaut, sur l'autre avion quand son pilote parle.
  final Offset Function()? at;
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
  const RadioCall(this.speaker, this.lingala, this.french, {this.offer, this.fuelPrice});

  final String speaker;
  final String lingala;
  final String french;

  /// Une escale proposée : le nom de l'aéroport sur le bouton « Descendre ».
  final String? offer;

  /// Kérosène en alerte : le prix du plein en vol, sur le bouton « Acheter ».
  final String? fuelPrice;
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
  const StoryCard(this.event, {this.caught = true, this.label});

  final HistoryEvent event;
  final bool caught;

  /// Une étiquette à la place de « Moment marquant » (« Escale », « Nouvelle monnaie »).
  final String? label;
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
  const ZoneHud(this.zone, this.wave, this.waves, this.jets, this.active, this.progress);

  final WarZone zone;

  /// La vague en cours (ou la prochaine, entre deux vagues), sur [waves] vagues, avec [jets] avions.
  final int wave, waves, jets;
  final bool active;
  final double progress;
}

/// Un avion de chasse noir : il arrive de face, annoncé par un signal rouge au bord de l'écran.
class _Jet {
  _Jet(this.x, this.y, this.wait, this.speed, this.drift, {this.missile = false});

  double x, y;

  /// Un missile : petit, rapide, il file vers l'avion.
  final bool missile;

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

/// Un avion d'une autre compagnie qui croise le nôtre, plus loin dans le ciel.
class _Traffic {
  _Traffic(this.airline, this.type, this.x, this.y, this.to, this.scale);

  final ForeignAirline airline;
  final AircraftType type;
  double x, y;
  final String to;
  final double scale;
  bool talked = false;
}

/// Un oiseau d'une volée : il bat des ailes et passe à côté de l'avion.
class _Bird {
  _Bird(this.x, this.y, this.phase);

  double x, y;
  final double phase;
  bool hit = false;
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

/// Un passage de la régie : un seul message à l'écran, puis un temps de silence avant le suivant.
class _Cue {
  _Cue(this.show, this.seconds, {this.hide, this.done, this.hold = false});

  final VoidCallback show;
  final VoidCallback? hide;
  final double seconds;

  /// Le message s'en va plus tôt dès que c'est fini (une escale acceptée, un repas servi).
  final bool Function()? done;

  /// Un moment qui attend le joueur : la régie patiente jusqu'à [done].
  final bool hold;
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

  /// Le kérosène d'avion coûte cher : 30 par pourcent du réservoir, 3 000 pour un plein complet.
  static const fuelPrice = 30;

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

  /// L'argent qui restait au crash : à la reprise, on ne retrouve pas ce qu'on a dépensé.
  int? startMoney;

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
  double _hudTimer = 0;
  int _nextEvent = 0;
  late AirlineEra _airline;
  late FlagEra _flag;

  final _clouds = <_Cloud>[];
  final _pickups = <_Pickup>[];
  final _particles = <_Particle>[];
  final _trail = <Offset>[];
  final _jets = <_Jet>[];

  // Zones de turbulence
  WarZone? _zone;
  String _failWhy = '';
  bool _startSent = false;
  int _yearSent = 0;
  int _nextZone = 0, _wave = 0, _wavesCleared = 0, _decade = 0;
  bool _waveActive = false;
  double _waveDelay = 0, _zoneFade = 0, _peace = 0;

  // Escales
  double condition = 100;
  double _runwayOrigin = 0, _offerAt = 0, _nextOffer = 0, _nextKit = 6;
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
  double _nextMission = 0, _nextQuiz = 50, _quizWait = 0, _boil = 0;
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
  double _nextTalk = 0, _nextComfort = 0, _nextChat = 40;

  /// Plus le pays avance, plus le ciel est dur : de 0 en 1960 à 1 en 2027.
  double get _level => ((year - 1960) / 67).clamp(0.0, 1.0);

  /// On ne garde jamais plus de cinq vies : un crash reste toujours possible.
  static const _maxLives = 5;

  /// Après une épreuve, le ciel se calme : pas d'orage isolé jusqu'à [_calmUntil].
  double _calmUntil = 0, _nextSquall = 30, _dance = 0;

  // Le ciel vivant : autres avions, oiseaux, éclairs
  final _traffic = <_Traffic>[];
  final _birds = <_Bird>[];
  double _nextTraffic = 40, _nextBirds = 25, _bolt = 0, _boltX = 0;
  int _banterIndex = 0, _warnedZone = 0;
  double _nextFuelAlert = 0, _nextBuzz = 0;
  bool _halfFuelSaid = false, _refuelSaid = false, _wornSaid = false;
  int _fuelCans = 0;
  bool _impact = false;

  /// Une vibration : durée en millisecondes, force de 1 à 255.
  void Function(int ms, int amplitude)? onBuzz;

  /// Le crash est fini (l'avion a touché le sol) : le bilan peut s'afficher.
  bool get crashShown => phase != FlightPhase.crashed || _wrecked || phaseTime > 2.8;

  /// Les visages des médaillons, chargés une fois au départ.
  final _portraits = <String, ui.Image>{};

  Future<void> _loadPortraits() async {
    final keys = {
      for (final e in historyEvents)
        if (e.photo != null && (e.kind == EventKind.life || e.kind == EventKind.glory)) e.photo!,
    };
    for (final k in keys) {
      final p = archivePhotos[k];
      if (p == null || !p.isPortrait) continue;
      try {
        final data = await rootBundle.load(p.asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 180);
        _portraits[k] = (await codec.getNextFrame()).image;
      } catch (_) {
        // Le fichier n'est pas là (il reste chez l'auteur) : le médaillon garde son année.
      }
    }
  }

  TextPainter? _fuelLabel;

  /// Pour les sons : « medaille », « kerosene », « kit », « etoile », « ceinture ».
  void Function(String sound)? onSound;

  /// Reprise après un crash : on repart d'un aéroport, et il faut d'abord faire le plein.
  bool resumed = false;

  /// Un moment d'histoire arrive bientôt : on lui laisse la place.
  bool get _eventSoon => _nextEvent < historyEvents.length && historyEvents[_nextEvent].year < year + 10 / _yearSeconds;

  // Le pilote automatique de la démo n'est pas parfait : il réagit avec un temps de retard
  // et se laisse parfois surprendre, comme un vrai pilote.
  double _apNext = 0, _apBlind = 0;
  Offset? _apTarget;

  static const _runwayStart = -400.0;
  static const _runwayEnd = 3600.0;
  // Dix-huit secondes par année : le joueur a le temps de lire, et des moments sans rien laissent respirer le vol.
  static const _yearSeconds = 18.0;
  static const _endYear = 2027.5;
  // L'approche prend son temps : la ville et la piste montent peu à peu, le train sort.
  static const _approachTime = 13.0;

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
    _loadPortraits();
    if (startYear != null && resumed && !autopilot) {
      // Après un crash, on repart d'un aéroport, le réservoir presque vide : d'abord le plein.
      year = startYear!;
      _takeoffs = 1;
      score = startScore;
      medals = startMedals;
      _airport = _nearestAirport();
      fuel = 18;
      if (startMoney != null) money = startMoney!;
      _queueBanner(
        FlightBanner(
          'Reprise en ${year.floor()}',
          'À ${_airport!.cityAt(year)} · fais le plein, puis TURBO pour décoller',
        ),
      );
      while (_nextEvent < historyEvents.length && historyEvents[_nextEvent].year < year) {
        _nextEvent++;
      }
    } else if (startYear != null) {
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
      case 'trafic':
        // Pour les captures : un avion étranger déjà dans le ciel, qui va parler.
        _clearStage();
        _nextTraffic = t;
        _calmUntil = 0;
        _nextEvent = historyEvents.indexWhere((e) => e.year > year + 1);
        _spawnSkyLife();
        if (_traffic.isNotEmpty) _traffic.last.x = _w * 0.84;
      case 'portrait':
        // Pour les captures : un médaillon avec un visage, juste devant l'avion.
        autopilot = false;
        final e = historyEvents.firstWhere((e) => e.photo == 'ldk');
        _pickups.add(
          _Pickup(_PickupKind.medal, _w * 2.5, _h * 0.7, event: e, label: _label('${e.yearLabel}', 15 * _unit)),
        );
      case 'atterrir':
        _clearStage();
        requestLanding();
      case 'repas':
        _offerMeal();
      case 'ceintures':
        _askBelts('Zone de turbulences droit devant');
      case 'service':
        _clearStage();
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

  void _report(String kind, [String detail = '']) {
    if (autopilot) return;
    Telemetry.send(kind, year: year, score: score, stage: _zone?.name ?? _airline.name, detail: detail);
  }

  void _setPhase(FlightPhase p) {
    if (p == FlightPhase.rolling && !_startSent) {
      _startSent = true;
      _yearSent = year.floor();
      _report('start');
    }
    if (p == FlightPhase.crashed && phase != p) _report('crash', _failWhy.isEmpty ? 'Plus de vies' : _failWhy);
    if (p == FlightPhase.finished && phase != p) _report('win');
    if (p == FlightPhase.crashed && phase != p) {
      onBuzz?.call(700, 255);
      _impact = false;
      if (!autopilot) {
        saveFlight(FlightRecord(DateTime.now(), score, medals, money, currencyAt(year), false, year));
        // On reprendra au dernier point de reprise, mais avec l'argent qui reste maintenant.
        final cp = checkpoint.value;
        if (cp != null) {
          cp.money = money;
          cp.save();
        }
      }
    }
    phase = p;
    phaseTime = 0;
    _pushHud();
  }

  // ---------------------------------------------------------------- régie

  // Tout ce qui s'affiche passe par la régie, comme à la télévision : un message à la fois,
  // le temps de le lire, puis un silence. Rien ne s'empile sur l'avion.
  final _cues = <_Cue>[];
  _Cue? _onStage;
  double _cueLeft = 0, _cueGap = 0;

  /// Le silence entre deux messages : le vol respire.
  static const _breath = 1.8;

  void _cue(
    VoidCallback show,
    double seconds, {
    VoidCallback? hide,
    bool Function()? done,
    bool hold = false,
    bool first = false,
  }) {
    final c = _Cue(show, seconds, hide: hide, done: done, hold: hold);
    first ? _cues.insert(0, c) : _cues.add(c);
    // Quand l'histoire s'emballe, on garde les messages les plus récents.
    while (_cues.length > 8) {
      _cues.removeAt(0);
    }
  }

  /// Un message qui ne peut pas attendre (approche, atterrissage) : il passe tout de suite.
  void _cueNow(VoidCallback show, double seconds, {VoidCallback? hide}) {
    _onStage?.hide?.call();
    final c = _onStage = _Cue(show, seconds, hide: hide);
    _cueLeft = seconds;
    c.show();
  }

  /// Rien à l'écran, rien qui attend : on peut lancer un nouveau moment.
  bool get _quiet => _onStage == null && _cues.isEmpty && _cueGap <= 0;

  void _runStage(double dt) {
    final c = _onStage;
    if (c != null) {
      _cueLeft -= dt;
      final finished = c.done?.call() ?? false;
      if (!finished && (_cueLeft > 0 || c.hold)) return;
      c.hide?.call();
      _onStage = null;
      _cueGap = _breath;
    }
    _cueGap -= dt;
    if (_cueGap > 0 || _cues.isEmpty) return;
    final next = _onStage = _cues.removeAt(0);
    _cueLeft = next.seconds;
    next.show();
  }

  void _clearStage() {
    _onStage?.hide?.call();
    _onStage = null;
    _cues.clear();
    _cueGap = 0;
  }

  void _queueBanner(FlightBanner b, {bool first = false}) =>
      _cue(() => banner.value = b, 4, hide: () => banner.value = null, first: first);

  void _showCard(HistoryEvent e, {bool caught = true, String? label}) {
    if (e.big && caught) {
      // Grand tournant : le ciel bout, le drapeau change, la fiche suit.
      _cue(
        () {
          if (e.song != null && e.kind != EventKind.memory) onSong?.call(e.song!);
          _boil = 4.5;
          slowMo = math.max(slowMo, 3.5);
          shake = 0.3;
          turningPoint.value = TurningPoint(e, flagAt(e.year - 0.02).style, flagAt(e.year + 0.12).style);
          HapticFeedback.heavyImpact();
        },
        4.6,
        hide: () => turningPoint.value = null,
      );
    }
    _cue(
      () {
        if (e.song != null && e.kind != EventKind.memory && !(e.big && caught)) onSong?.call(e.song!);
        card.value = StoryCard(e, caught: caught, label: label);
      },
      e.kind == EventKind.memory ? 7 : 6,
      hide: () => card.value = null,
    );
  }

  void _loseLife([String why = 'Touché en vol']) {
    if (invulnerable > 0 || phase != FlightPhase.cruising || _finaleT >= 0) return;
    _failWhy = why;
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
    onBuzz?.call(320, 230);
    _burst(planeX, planeY, 26, const [Color(0xFFFFB04A), Color(0xFFFF3B3B), Colors.white]);
    if (lives > 0) _talk(lives == 1 ? TalkMoment.danger : TalkMoment.hit, force: lives == 1);
    if (lives <= 0) {
      lives = 0;
      _clearStage();
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

    switch (phase) {
      case FlightPhase.ready:
        if (boost && fuel < 50) {
          // Réservoir presque vide : pas de décollage sans le plein.
          if (!_refuelSaid) {
            _refuelSaid = true;
            _say(
              'Tour de ${_airport?.cityAt(year) ?? 'contrôle'}',
              Lingala.mafuta,
              'Réservoir vide : fais d\'abord le plein.',
            );
          }
        } else if (boost) {
          _setPhase(FlightPhase.rolling);
        }
        if (!boost) _refuelSaid = false;
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
          // L'avion pique du nez, tombe en fumant, puis s'écrase en bas de l'écran.
          vy += _h * 0.9 * dt;
          planeY += vy * dt;
          pitch = math.min(0.75, pitch + dt * 0.5);
          worldX += groundSpeed * dt * 0.6;
          _smoke(dt);
          if (!_impact && planeY > _h * 0.92) {
            _impact = true;
            shake = 0.8;
            flash = 0.6;
            onBuzz?.call(600, 255);
            HapticFeedback.heavyImpact();
            _burst(
              planeX,
              _h * 0.95,
              60,
              const [Color(0xFFFFB04A), Color(0xFFFF3B3B), Colors.white],
              speed: 380,
              size: 6,
            );
          }
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

    // Dans les turbulences, le téléphone vibre doucement, lentement.
    final rough = _zone != null || _turbulence > 0 || year < stormUntil;
    if (rough && phase == FlightPhase.cruising && t >= _nextBuzz) {
      _nextBuzz = t + (_zone != null ? 1.1 : 1.6) + _rng.nextDouble() * 0.5;
      _zone != null ? onBuzz?.call(160, 170) : onBuzz?.call(90, 110);
    }

    _runStage(dt);
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
    if (_finaleT < 0) {
      if (t < _apNext && _apTarget != null) {
        touchTarget = _apTarget;
        return;
      }
      _apNext = t + 0.22 + _level * 0.25;
      if (_apBlind <= t && _rng.nextDouble() < 0.025 + _level * 0.06) _apBlind = t + 0.9 + _level;
    }
    final blind = t < _apBlind;
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
      if (blind || !c.storm || c.x < planeX - c.r || c.x > planeX + 420 * _unit) continue;
      if ((y - c.y).abs() < c.r * 2.4) y = c.y + (planeY > c.y ? 1 : -1) * c.r * 2.6;
    }
    // Les avions de chasse : choisir la hauteur la plus éloignée de ceux qui arrivent.
    final threats = [
      for (final j in _jets)
        if (j.x > planeX - _jetLength * 0.5 && j.wait < 0.5) Offset(j.x, j.y),
      for (final b in _bombs)
        if (b.x > planeX - 40 * _unit && b.x < planeX + 500 * _unit) Offset(b.x, b.y + b.vy * 0.4),
    ];
    if (!blind && threats.any((j) => (j.dy - y).abs() < _h * 0.16)) {
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
    touchTarget = _apTarget = Offset(_w * 0.26, y.clamp(_h * 0.14, _h * 0.86));
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
        // Le premier vol commence par la mission, puis la tour explique les commandes, une chose à la fois.
        _queueBanner(
          const FlightBanner('Ta mission : le 30 juin 2027', 'Ramène le Congo jusqu\'à ses 67 ans d\'indépendance'),
        );
        _say(
          'Tour de Léopoldville',
          Lingala.elonga,
          tilt.available
              ? 'Bravo ! Pour monter, appuie sur ▲, ou incline le téléphone. Pour descendre, ▼.'
              : 'Bravo ! Pour monter, appuie sur ▲ ou glisse le doigt vers le haut. Pour descendre, ▼.',
          seconds: 7,
        );
        _say('Tour de Léopoldville', Lingala.kitaMalembe, 'Lâche tout : l\'avion vole tout droit.', seconds: 5);
        _say(
          'Tour de Léopoldville',
          'Keba !',
          'Un orage ou un avion devant toi ? Monte ou descends pour passer au-dessus ou en dessous.',
          seconds: 7,
        );
        _say(
          'Tour de Léopoldville',
          Lingala.tokende,
          'Attrape les médaillons : chacun raconte un moment du pays. TURBO fait passer les années plus vite.',
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
    if (_dance > 0) {
      // L'avion danse : il balance ses ailes au rythme de la joie.
      _dance = math.max(0, _dance - dt);
      pitch += math.sin(t * 11) * 0.1 * math.min(1, _dance);
      if (phaseTime % 0.5 < dt) {
        _burst(planeX, planeY, 6, const [ChachaColors.yellow, ChachaColors.red, ChachaColors.sky], speed: 120, size: 3);
      }
    }
    _spawnSkyLife();
    if (_zone == null && t >= _nextChat && _quiet && !_eventSoon) {
      _nextChat = t + 40 + _rng.nextDouble() * 30;
      _talk(TalkMoment.chat);
    }

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
    condition = math.max(0, condition - dt * ts * 0.15);
    if (fuel < 25 && !_lowFuelSaid) {
      _lowFuelSaid = true;
      _say('Tour de contrôle', Lingala.mafuta, 'Le kérosène va finir. Attrape un bidon ou fais escale.');
    }
    if (fuel > 40) _lowFuelSaid = false;
    if (fuel > 70) _halfFuelSaid = false;
    // Trop de chocs : la tour demande l'entretien ; à zéro, l'avion ne tient plus et tombe.
    if (condition < 35 && !_wornSaid) {
      _wornSaid = true;
      _say(
        'Tour de contrôle',
        Lingala.keba,
        _zone == null
            ? 'Ton avion est très abîmé (${condition.round()} %). Atterris pour l\'entretien, ou attrape un kit.'
            : 'Ton avion est très abîmé (${condition.round()} %). Attrape un kit, et atterris dès la fin de la zone.',
        first: true,
      );
      _nextKit = math.min(_nextKit, t + 3);
    }
    if (condition > 60) _wornSaid = false;
    if (condition <= 0 && _finaleT < 0) {
      _queueBanner(
        const FlightBanner('L\'avion ne tient plus', 'Trop de chocs sans entretien', color: ChachaColors.red),
        first: true,
      );
      lives = 0;
      _failWhy = 'Avion usé, sans entretien';
      _clearStage();
      _setPhase(FlightPhase.crashed);
      return;
    }
    if (_zone == null && !_offerPending && _quiet && t >= _nextOffer && (fuel < 35 || condition < 30)) _offerStopover();
    _checkMission();
    _updateCabin(dt);
    if (fuel < 50 && !_halfFuelSaid) {
      _halfFuelSaid = true;
      _say(
        'Tour de contrôle',
        Lingala.mafuta,
        'Kérosène à 50 % : regarde la jauge en bas à gauche. Attrape les bidons rouges marqués KÉROSÈNE.',
      );
    }
    if (fuel < 22 && t >= _nextFuelAlert && !_offerPending) _fuelAlert();
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
      _loseLife('Panne sèche');
    }
    if (year.floor() > _yearSent && _startSent) {
      _yearSent = year.floor();
      _report('year');
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
    _clearStage();
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
    // Chaque conversation passe une fois avant de revenir : on n'entend pas deux fois la même.
    final bag = _talkBags[m] ??= [];
    if (bag.isEmpty) bag.addAll(List.generate(options.length, (i) => i)..shuffle(_rng));
    final lines = options[bag.removeLast()];
    if (lines.length > 3) {
      // Une longue conversation : chacun parle à son tour, avec un temps entre deux répliques.
      for (final l in lines) {
        _cue(() => talk.value = CabinTalk([l]), 3.4, hide: () => talk.value = null);
      }
    } else {
      _cue(() => talk.value = CabinTalk(lines), seconds ?? 2.5 + lines.length * 1.8, hide: () => talk.value = null);
    }
    _nextTalk = t + 20;
  }

  final _talkBags = <TalkMoment, List<int>>{};

  /// Un moment difficile : une louange douce réconforte, sans revenir trop souvent.
  void _comfort() {
    if (t < _nextComfort || _finaleT >= 0) return;
    _nextComfort = t + 75;
    onSong?.call('louange');
  }

  /// Le ciel n'est pas vide : un avion étranger qui salue, une volée d'oiseaux.
  void _spawnSkyLife() {
    if (_zone == null && t >= _nextTraffic && t >= _calmUntil - 10 && _quiet && !_eventSoon) {
      _nextTraffic = t + 60 + _rng.nextDouble() * 40;
      final open = [
        for (final a in foreignAirlines)
          if (year >= a.from && year <= a.to) a,
      ];
      final types = [
        for (final ty in aircraftTypes)
          if (ty.fliesIn(year)) ty,
      ];
      if (open.isNotEmpty && types.isNotEmpty) {
        final a = open[_rng.nextInt(open.length)];
        // Loin dans le ciel, au-dessus ou au-dessous de nous, il vient en face.
        final high = planeY > _h * 0.45;
        _traffic.add(
          _Traffic(
            a,
            types[_rng.nextInt(types.length)],
            _w + 200 * _unit,
            _h * (high ? 0.24 + _rng.nextDouble() * 0.06 : 0.52 + _rng.nextDouble() * 0.06),
            a.destinations[_rng.nextInt(a.destinations.length)],
            0.5 + _rng.nextDouble() * 0.12,
          ),
        );
      }
    }
    if (t >= _nextBirds && year >= stormUntil) {
      _nextBirds = t + 30 + _rng.nextDouble() * 25 - 10 * _level;
      final y0 = (planeY + (_rng.nextDouble() - 0.5) * _h * 0.5).clamp(_h * 0.15, _h * 0.85);
      final n = 4 + _rng.nextInt(5);
      for (var i = 0; i < n; i++) {
        _birds.add(
          _Bird(_w + (40 + i * 26) * _unit, y0 + ((i % 3) - 1) * 16 * _unit + i * 3 * _unit, _rng.nextDouble() * 6),
        );
      }
    }
  }

  /// Le pilote de l'autre avion parle d'abord, sa bulle sur son avion ; notre commandant répond ensuite.
  void _banter(_Traffic tr) {
    tr.talked = true;
    if (!_quiet) return;
    final b = pilotBanter[_banterIndex++ % pilotBanter.length];
    _cue(
      () => talk.value = CabinTalk([
        TalkLine('${tr.airline.name} · vers ${tr.to}', b.theirLingala, b.theirs),
      ], at: () => Offset(tr.x, tr.y)),
      4.5,
      hide: () => talk.value = null,
    );
    _cue(
      () => talk.value = CabinTalk([
        TalkLine('Commandant', b.oursLingala, b.ours.replaceAll('{to}', tr.to)),
        const TalkLine('Passagers', 'Ha ha ha !', 'Ha ha ha !'),
      ]),
      6.5,
      hide: () => talk.value = null,
    );
    _nextTalk = t + 20;
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
    final d = _level;
    if (year < stormUntil && t >= _nextStorm) {
      // Les orages se resserrent au fil des années, et viennent parfois à deux.
      _nextStorm = t + (1.0 - 0.45 * d) + _rng.nextDouble() * (0.8 - 0.3 * d);
      for (var i = 0; i < (_rng.nextDouble() < d * 0.8 ? 2 : 1); i++) {
        final y = (planeY + (_rng.nextDouble() - 0.5) * _h * 0.7).clamp(_h * 0.15, _h * 0.85);
        _clouds.add(
          _Cloud(_w + (120 + i * 160) * _unit, y, _unit * (34 + _rng.nextDouble() * 20 + d * 10), 1, storm: true),
        );
      }
    }
    // Hors des grands moments, un orage isolé surgit de temps en temps, de plus en plus souvent.
    if (year >= 1963 && _zone == null && t >= _nextSquall && t >= _calmUntil && year >= stormUntil) {
      _nextSquall = t + 22 - 13 * d + _rng.nextDouble() * 8;
      final n = 1 + (d * 3 * _rng.nextDouble()).floor();
      for (var i = 0; i < n; i++) {
        final y = (planeY + (_rng.nextDouble() - 0.5) * _h * 0.5).clamp(_h * 0.15, _h * 0.85);
        _clouds.add(_Cloud(_w + (120 + i * 140) * _unit, y, _unit * (30 + _rng.nextDouble() * 18), 1, storm: true));
      }
      if (n > 1) _talk(TalkMoment.storm);
    }
    if (t >= _nextStar) {
      _nextStar = t + 1.3 + _rng.nextDouble();
      _pickups.add(_Pickup(_PickupKind.star, _w + 40, _h * (0.15 + _rng.nextDouble() * 0.7)));
    }
    if (t >= _nextFuel) {
      _nextFuel = t + 7 + _rng.nextDouble() * 4;
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

  void _say(
    String speaker,
    String lingala,
    String french, {
    String? offer,
    String? fuelPrice,
    double seconds = 5.5,
    bool first = false,
  }) {
    void show() => radio.value = RadioCall(speaker, lingala, french, offer: offer, fuelPrice: fuelPrice);
    void hide() {
      radio.value = null;
      if (offer != null && _offerPending) {
        // Sans réponse, on continue et la tour rappellera.
        _offerPending = false;
        _nextOffer = t + 12;
      }
    }

    // À l'approche et au sol, la tour guide en direct : son message passe tout de suite.
    if (phase != FlightPhase.cruising && phase != FlightPhase.climbing) return _cueNow(show, seconds, hide: hide);
    _cue(show, seconds, hide: hide, done: offer == null ? null : () => !_offerPending, first: first);
  }

  /// Le prix du plein en vol, dans la monnaie du moment.
  int get fuelBill => ((100 - fuel).clamp(0, 100) * fuelPrice).round();

  Airport _nearestAirport() {
    final open = [
      for (final a in airports)
        if (a.openAt(year)) a,
    ];
    return open[_airportIndex++ % open.length];
  }

  /// Kérosène en alerte : la tour propose d'acheter le plein en vol, ou d'atterrir.
  void _fuelAlert() {
    _nextFuelAlert = t + 30;
    if (_offerPending || phase != FlightPhase.cruising || _finaleT >= 0) return;
    _airport = _nearestAirport();
    _stopPurpose = 0;
    _gusty = false;
    _offerPending = true;
    _offerAt = t;
    _clearStage();
    _say(
      'Tour de contrôle',
      Lingala.mafuta,
      'Kérosène en alerte : ${fuel.clamp(0, 100).round()} %. Achète le plein en vol, ou atterris à ${_airport!.cityAt(year)}.',
      offer: _airport!.cityAt(year),
      fuelPrice: '${_fmt(fuelBill)} ${currencyAt(year)}',
      seconds: 20,
    );
    HapticFeedback.heavyImpact();
  }

  /// Acheter le plein : avec l'argent d'abord, puis en convertissant des points.
  void buyFuel() {
    final price = fuelBill;
    if (price <= 0) return;
    final cur = currencyAt(year);
    var pay = price;
    if (money < price) {
      final missing = price - money;
      final converted = math.min(missing, score);
      if (converted > 0) {
        score -= converted;
        money += converted;
        _queueBanner(
          FlightBanner(
            'Points convertis',
            '${_fmt(converted)} points → ${_fmt(converted)} $cur',
            color: ChachaColors.yellow,
          ),
        );
      }
      // Pas assez pour tout le plein : on achète ce qu'on peut payer.
      pay = math.min(price, money);
      if (pay < fuelPrice * 5) {
        _say(
          'Tour de contrôle',
          Lingala.zelaMoke,
          'Plus d\'argent ni de points pour le kérosène. Attrape les bidons rouges, ou recommence.',
        );
        return;
      }
    }
    money -= pay;
    fuel = math.min(100, fuel + pay / fuelPrice);
    _offerPending = false;
    _lowFuelSaid = _halfFuelSaid = false;
    onSound?.call('kerosene');
    HapticFeedback.mediumImpact();
    _queueBanner(
      FlightBanner('Kérosène acheté', 'Réservoir à ${fuel.round()} % · −${_fmt(pay)} $cur', color: _peaceGreen),
    );
    _pushHud();
  }

  /// Le pilote demande lui-même à atterrir : là où l'attendent ses passagers, sinon au plus proche.
  void requestLanding() {
    if (phase != FlightPhase.cruising || _zone != null || _finaleT >= 0) return;
    if (!_offerPending) {
      final m = mission.value;
      if (m != null) {
        _airport = m.boarded ? m.to : m.from;
        _stopPurpose = m.boarded ? 2 : 1;
        _gusty = m.boarded && m.why.isNotEmpty;
      } else {
        _airport = _nearestAirport();
        _stopPurpose = 0;
        _gusty = false;
      }
      _offerPending = true;
    }
    acceptStopover();
  }

  /// On peut demander l'atterrissage : en vol, hors des guerres et de la dernière ligne droite.
  bool get canLand => phase == FlightPhase.cruising && _zone == null && _finaleT < 0;

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
    _queueBanner(FlightBanner('Préparation de l\'atterrissage', _airport!.titleAt(year)));
    _say(
      'Tour de ${_airport!.cityAt(year)}',
      Lingala.kitaMalembe,
      _gusty
          ? 'Vent fort ! Fais descendre l\'avion avec ton doigt ou ▼, doucement, en suivant le couloir jaune.'
          : 'Fais descendre l\'avion avec ton doigt ou ▼, doucement, en suivant le couloir jaune.',
      seconds: 7,
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
        label: 'ESCALE',
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
    _failWhy = why;
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
      // Le changement de billets : la fiche montre le nouveau billet.
      _showCard(
        HistoryEvent(
          year,
          EventKind.life,
          '${year.floor()}',
          'Banque centrale',
          'Place aux ${currencyName(cur)} ($cur)',
          'Ton portefeuille passe en ${currencyName(cur)} : les anciens billets sont échangés contre les nouveaux.',
          photo: switch (cur) {
            'NZ' => 'billetnz',
            'FC' => 'billet1f',
            _ => null,
          },
        ),
        label: 'NOUVELLE MONNAIE',
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

    final free =
        _quiet && cabin.value == null && quiz.value == null && _zone == null && !_offerPending && passengers > 0;
    if (free && t >= _nextBelts) {
      _askBelts('Zone de turbulences droit devant');
    } else if (free && t >= _nextMeal && _turbulence <= 0) {
      _offerMeal();
    }
  }

  /// La tour annonce des turbulences : le pilote doit allumer le signal des ceintures.
  void _askBelts(String why) {
    if (cabin.value?.mode == CabinMode.beltsAsk || passengers == 0) return;
    _nextBelts = t + 100 + _rng.nextDouble() * 50;
    _cue(
      () {
        _cabinT = 0;
        _beltsDeadline = t + 9;
        cabin.value = CabinHud(CabinMode.beltsAsk, 0, passengers, 'Attachez vos ceintures', why);
        HapticFeedback.selectionClick();
      },
      0,
      hold: true,
      done: () => cabin.value == null,
    );
  }

  void fastenBelts() {
    final c = cabin.value;
    if (c == null || c.mode != CabinMode.beltsAsk) return;
    onSound?.call('ceinture');
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
    _nextMeal = t + 140 + _rng.nextDouble() * 50;
    _cue(
      () {
        _mealWait = 0;
        meal.value = MealOffer(passengers);
        _pushHud();
      },
      0,
      hold: true,
      done: () => meal.value == null,
    );
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
    _talk(TalkMoment.serving, force: true);
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
    _cue(
      () => planeCard.value = PlaneCard(type, _airline.name, passengers, title),
      5,
      hide: () => planeCard.value = null,
    );
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
    if (_zone != null || _offerPending || !_quiet) return;
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
    _say('Tour de $city', lingala, french, offer: city, seconds: 18);
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
    final q = Quiz(question, options, options.indexOf(byYear ? '${e.yearLabel}' : e.title), e);
    // Le kérosène ne peut pas attendre : la question passe juste après le message en cours.
    _cue(
      () {
        _quizWait = 0;
        quiz.value = q;
        _pushHud();
      },
      0,
      hold: true,
      done: () => quiz.value == null,
      first: true,
    );
    _say('Tour de contrôle', Lingala.mafuta, 'Plus de kérosène ! Réponds juste et un ravitaillement arrive.');
    final say = _cues.removeLast();
    _cues.insert(0, say);
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
      _nextFuelAlert = 0;
    }
    _pushHud();
  }

  // ------------------------------------------------------ zones de turbulence

  void _saveCheckpoint(double y) {
    final cp = Checkpoint(y, score, medals, money: money);
    checkpoint.value = cp;
    if (!autopilot) cp.save();
  }

  void _checkDecade() {
    final d = (year / 10).floor();
    if (d == _decade) return;
    _decade = d;
    _saveCheckpoint(year);
  }

  /// Une zone compte trois fois plus de vagues que son nombre d'avions au plus fort :
  /// on la traverse longtemps, un ou deux avions d'abord, puis de plus en plus.
  int _wavesOf(WarZone z) => z.waves * 3;

  /// Combien d'avions de chasse dans la vague [k] (de 1 au total).
  int _jetsIn(WarZone z, int k) => 1 + ((k - 1) * (z.waves + 1) / _wavesOf(z)).floor();

  void _checkZone() {
    if (_zone != null || _nextZone >= warZones.length) return;
    final ahead = warZones[_nextZone];
    // La tour prévient de loin : la zone se voit venir, les ceintures s'attachent avant d'y entrer.
    if (_warnedZone < _nextZone + 1 && year >= ahead.from - 0.7 && year < ahead.from) {
      _warnedZone = _nextZone + 1;
      // L'annonce passe avant tout le reste : elle doit arriver avant la zone.
      _queueBanner(
        FlightBanner('Zone de turbulence devant', '${ahead.name} · ${ahead.place}', color: _warRed),
        first: true,
      );
      _talk(TalkMoment.war, force: true);
      if (passengers > 0) _askBelts('Zone de guerre droit devant');
    }
    if (year < ahead.from) return;
    final z = warZones[_nextZone++];
    _zone = z;
    final waves = _wavesOf(z);
    final span = (z.to - z.from) / waves;
    // En reprenant au milieu d'une zone, les vagues déjà passées comptent.
    _wavesCleared = _wave = ((year - z.from) / span).floor().clamp(0, waves - 1);
    year = math.max(year, z.from);
    _waveActive = false;
    _waveDelay = 4;
    _saveCheckpoint(z.from + span * _wavesCleared);
    shake = 0.35;
    HapticFeedback.heavyImpact();
    // Repris au milieu d'une zone, ou arrivé sans prévenir : on prévient maintenant.
    if (_warnedZone < _nextZone) {
      _warnedZone = _nextZone;
      if (passengers > 0) _askBelts('Zone de guerre droit devant');
    }
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
    final waves = _wavesOf(z);
    final span = (z.to - z.from) / waves;
    final target = _wavesCleared >= waves ? z.to : z.from + span * (_wavesCleared + (_waveActive ? 0.7 : 0));
    year = math.min(target, year + dt * span / 3.2);

    if (_waveActive) {
      if (_jets.isEmpty) {
        _waveActive = false;
        _wavesCleared++;
        score += 100 * _wavesCleared;
        _waveDelay = 2.2;
      }
    } else {
      _waveDelay -= dt;
      // Les avions de chasse attendent que les messages soient lus : on ne se bat pas en lisant.
      if (_waveDelay > 0 || _onStage != null || _cues.isNotEmpty) return;
      if (_wavesCleared < waves) {
        _launchWave();
      } else if (year >= z.to) {
        _exitZone();
      }
    }
  }

  void _launchWave() {
    _wave = _wavesCleared + 1;
    _waveActive = true;
    final jets = _jetsIn(_zone!, _wave);
    // Six couloirs : deux avions qui se suivent ne prennent jamais le même.
    final lanes = [for (var i = 0; i < 6; i++) _h * (0.17 + i * 0.13)];
    var last = -1, before = -1;
    for (var i = 0; i < jets; i++) {
      int lane;
      do {
        lane = _rng.nextInt(lanes.length);
      } while (lane == last || lane == before);
      before = last;
      last = lane;
      // Dès la troisième vague, certains avions dérivent vers toi.
      final drift = jets >= (_level > 0.5 ? 2 : 3) && _rng.nextBool()
          ? ((planeY - lanes[lane]) * 0.22).clamp(-_h * 0.12, _h * 0.12)
          : 0.0;
      // Les trois premiers arrivent presque ensemble ; les suivants derrière.
      final wait = i < 3 ? i * 0.12 : 0.9 + (i - 3) * 0.7;
      _jets.add(_Jet(_w + _jetLength, lanes[lane], wait, _unit * (480 + 60 * jets + 140 * _level), drift));
    }
    // Dès la deuxième vague, des missiles filent vers l'avion entre les avions de chasse.
    if (_wave >= 2) {
      final missiles = 1 + _wave % 2 + (_level > 0.5 ? 1 : 0);
      for (var i = 0; i < missiles; i++) {
        final y = _h * (0.18 + _rng.nextDouble() * 0.64);
        _jets.add(
          _Jet(
            _w + _jetLength,
            y,
            0.5 + i * 1.1 + _rng.nextDouble() * 0.4,
            _unit * (820 + 220 * _level),
            ((planeY - y) * 0.35).clamp(-_h * 0.2, _h * 0.2),
            missile: true,
          ),
        );
      }
    }
    if (_wave > 1) HapticFeedback.selectionClick();
    _pushHud();
  }

  void _exitZone() {
    final z = _zone!;
    _zone = null;
    _waveActive = false;
    lives = math.min(_maxLives, lives + 1);
    score += 500;
    _calmUntil = t + 16;
    _dance = 4;
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
        if (phase == FlightPhase.cruising && _hits(c.x, c.y, c.r * 1.2)) _loseLife('Orage');
      }
    }
    _clouds.removeWhere((c) => c.x < -c.r * 4);

    for (final tr in _traffic) {
      // Il croise lentement : on a le temps de le voir, de lire la blague, et de s'écarter.
      tr.x -= move * 0.06 + _unit * 32 * dt;
      if (!tr.talked && tr.x < _w * 0.8 && phase == FlightPhase.cruising) _banter(tr);
    }
    _traffic.removeWhere((tr) => tr.x < -planeLength);

    for (final b in _birds) {
      b.x -= move + _unit * 90 * dt;
      b.y += math.sin(t * 3 + b.phase) * _unit * 12 * dt;
      if (!b.hit && phase == FlightPhase.cruising && _hits(b.x, b.y, 6 * _unit)) {
        // Un oiseau dans le moteur : l'avion s'abîme, sans perdre de vie.
        b.hit = true;
        condition = math.max(0, condition - 8);
        shake = math.max(shake, 0.2);
        _burst(b.x, b.y, 10, const [Colors.white, Color(0xFF8A7B6A)], speed: 120, size: 3);
        HapticFeedback.lightImpact();
      }
    }
    _birds.removeWhere((b) => b.x < -40 || b.hit);

    // La foudre tombe dans les orages et les zones de turbulence.
    _bolt = math.max(0, _bolt - dt * 4);
    final stormy = (year < stormUntil && phase == FlightPhase.cruising) || _zone != null;
    if (stormy && _bolt == 0 && _rng.nextDouble() < dt * 0.35) {
      _bolt = 1;
      _boltX = _w * (0.35 + _rng.nextDouble() * 0.6);
      flash = math.max(flash, 0.25);
    }

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
      if (!j.hit && phase == FlightPhase.cruising && _hits(j.x, j.y, _jetLength * (j.missile ? 0.09 : 0.16))) {
        j.hit = true;
        _loseLife(j.missile ? 'Missile' : 'Avion de chasse');
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
        _loseLife('Bombe');
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
        onSound?.call('medaille');
        lives = math.min(_maxLives, lives + 1);
        // Chaque vie rapporte aussi un peu de kérosène ; un visage du pays en apporte un bidon entier.
        fuel = math.min(100, fuel + (_portraits.containsKey(e.photo) ? 32 : 15));
        score += glory ? 300 : 150;
        medals++;
        money += 150;
        caught.add(e.title);
        _showCard(e);
        _burst(p.x, p.y, 30, const [ChachaColors.yellow, Colors.white, Color(0xFFFFE9A0)], speed: 300);
        if (glory) {
          _confetti();
          _dance = 3;
          _calmUntil = math.max(_calmUntil, t + 8);
          _talk(_rng.nextBool() ? TalkMoment.glory : TalkMoment.dance);
        }
        HapticFeedback.lightImpact();
      case _PickupKind.star:
        score += 10;
        onSound?.call('etoile');
        _burst(p.x, p.y, 8, const [ChachaColors.yellow, Colors.white], speed: 140, size: 3);
      case _PickupKind.fuel:
        fuel = math.min(100, fuel + 32);
        score += 20;
        onSound?.call('kerosene');
        // Le premier bidon s'explique ; les suivants se voient sur la jauge.
        if (_fuelCans++ == 0) {
          _queueBanner(
            FlightBanner(
              'Kérosène +32 %',
              'Le bidon rouge remplit le réservoir · regarde la jauge',
              color: _peaceGreen,
            ),
          );
        }
        _burst(p.x, p.y, 10, const [ChachaColors.red, Colors.white], speed: 160, size: 3);
      case _PickupKind.repair:
        fuel = 100;
        condition = 100;
        score += 80;
        _burst(p.x, p.y, 24, const [Color(0xFF7CF0A6), Colors.white], speed: 220, size: 4);
        onSound?.call('kit');
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
      planeLow: planeY > _h * 0.6 && planeX < _w * 0.42,
      planeHigh: planeY < _h * 0.3 && planeX < _w * 0.42,
    );
    final z = _zone;
    zoneHud.value = z == null
        ? null
        : ZoneHud(
            z,
            _waveActive ? _wave : math.min(_wavesOf(z), _wavesCleared + 1),
            _wavesOf(z),
            _waveActive ? _jetsIn(z, _wave) : 0,
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

    for (final tr in _traffic) {
      _drawTraffic(canvas, tr);
    }
    final rain = math.max(stormy, _zoneFade);
    if (rain > 0.2 && phase != FlightPhase.ground) _drawRain(canvas, s, rain);
    if (_bolt > 0) _drawBolt(canvas, s);

    for (final c in _clouds.where((c) => c.storm)) {
      Scenery.cloud(canvas, Offset(c.x, c.y), c.r, storm: true, flash: c.flash);
    }
    for (final b in _birds) {
      _drawBird(canvas, b);
    }

    for (final p in _pickups) {
      final at = Offset(p.x, p.y);
      switch (p.kind) {
        case _PickupKind.medal:
          final face = _portraits[p.event!.photo];
          face == null
              ? Scenery.medal(canvas, at, p.radius * _unit, t, p.label!, glory: p.event!.kind == EventKind.glory)
              : _drawPortraitMedal(canvas, at, p.radius * _unit, face, p.label!);
        case _PickupKind.star:
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(t * 2 + p.y);
          Scenery.glow(canvas, Offset.zero, 2 * _unit, ChachaColors.yellow);
          canvas.drawPath(_star(p.radius * _unit), Paint()..color = ChachaColors.yellow);
          canvas.restore();
        case _PickupKind.fuel:
          Scenery.fuelCan(canvas, at, p.radius * _unit);
          final label = _fuelLabel ??= TextPainter(
            text: TextSpan(
              text: 'KÉROSÈNE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9 * _unit,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          label.paint(canvas, at + Offset(-label.width / 2, p.radius * _unit + 3 * _unit));
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

  /// Un médaillon avec un visage : la photo dans un rond doré, l'année dessous,
  /// et le bidon de kérosène que la personne t'apporte.
  void _drawPortraitMedal(Canvas canvas, Offset at, double r, ui.Image face, TextPainter label) {
    final pulse = 1 + 0.06 * math.sin(t * 5);
    canvas.drawCircle(
      at,
      r * 1.9 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFD34D).withValues(alpha: 0.55), const Color(0x00FFD34D)],
        ).createShader(Rect.fromCircle(center: at, radius: r * 1.9 * pulse)),
    );
    final circle = Rect.fromCircle(center: at, radius: r);
    final side = math.min(face.width, face.height).toDouble();
    // Le visage est souvent en haut de la photo : on cadre un peu plus haut que le centre.
    final src = Rect.fromLTWH((face.width - side) / 2, math.max(0, (face.height - side) * 0.25), side, side);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawImageRect(face, src, circle, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * _unit
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1A8), Color(0xFFE0A100), Color(0xFFFFD34D)],
        ).createShader(circle),
    );
    // L'année, sur une petite plaque dorée sous le visage.
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: at + Offset(0, r * 0.98),
        width: label.width + 12 * _unit,
        height: label.height + 2 * _unit,
      ),
      Radius.circular(8 * _unit),
    );
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFFFD34D));
    label.paint(canvas, plate.center - Offset(label.width / 2, label.height / 2));
    Scenery.fuelCan(canvas, at + Offset(r * 0.95, -r * 0.55), r * 0.36);
  }

  /// Un missile gris à pointe rouge, avec sa traînée de feu.
  void _drawMissile(Canvas canvas, _Jet j) {
    final l = _jetLength * 0.42;
    canvas.save();
    canvas.translate(j.x, j.y);
    canvas.rotate(math.atan2(-j.drift, j.speed));
    final flicker = 0.75 + 0.25 * math.sin(t * 70 + j.y);
    canvas.drawOval(
      Rect.fromLTWH(l * 0.42, -l * 0.07, l * 0.7 * flicker, l * 0.14),
      Paint()
        ..color = const Color(0xCCFFA24A)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * _unit),
    );
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(-l * 0.4, -l * 0.06, l * 0.85, l * 0.12), Radius.circular(l));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFD5D9E0));
    canvas.drawPath(
      Path()
        ..moveTo(-l * 0.5, 0)
        ..lineTo(-l * 0.36, -l * 0.06)
        ..lineTo(-l * 0.36, l * 0.06)
        ..close(),
      Paint()..color = const Color(0xFFCE1021),
    );
    final fin = Paint()..color = const Color(0xFF6B7280);
    for (final sgn in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(l * 0.28, sgn * l * 0.05)
          ..lineTo(l * 0.45, sgn * l * 0.16)
          ..lineTo(l * 0.45, sgn * l * 0.05)
          ..close(),
        fin,
      );
    }
    canvas.restore();
  }

  /// Silhouette noire d'avion de chasse, nez à gauche, sans aucune marque.
  void _drawJet(Canvas canvas, _Jet j) {
    if (j.missile) return _drawMissile(canvas, j);
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

  void _drawTraffic(Canvas canvas, _Traffic tr) {
    final len = planeLength * tr.scale;
    canvas.save();
    canvas.translate(tr.x, tr.y);
    // Il vient en face : on le dessine tourné vers la gauche, un peu voilé par la distance.
    canvas.scale(-1, 1);
    canvas.translate(-len / 2, -len / 4);
    canvas.saveLayer(null, Paint()..color = const Color(0xD9FFFFFF));
    AircraftPainter.paint(canvas, Size(len, len / 2), tr.type, tr.airline.livery, propPhase: t * 40, blink: t);
    canvas.restore();
    canvas.restore();
    final label = TextPainter(
      text: TextSpan(
        text: tr.airline.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 11 * _unit,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(tr.x - label.width / 2, tr.y + len * 0.2));
  }

  void _drawBird(Canvas canvas, _Bird b) {
    final flap = math.sin(t * 14 + b.phase) * 5 * _unit;
    final w = 9 * _unit;
    final path = Path()
      ..moveTo(b.x - w, b.y - flap)
      ..quadraticBezierTo(b.x - w * 0.4, b.y - flap * 0.2, b.x, b.y)
      ..quadraticBezierTo(b.x + w * 0.4, b.y - flap * 0.2, b.x + w, b.y - flap);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * _unit
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A2A35),
    );
  }

  /// La pluie tombe en bas, sous les nuages d'orage.
  /// L'avion vole au-dessus des nuages : la pluie tombe sous lui, depuis la couche grise d'en bas.
  double get _rainTop => math.max(_h * 0.62, planeY + planeLength * 0.3);

  void _drawRain(Canvas canvas, Size s, double amount) {
    final top = _rainTop;
    // La couche de nuages gris d'où tombe la pluie.
    final deck = Paint()
      ..color = Color.fromRGBO(70, 80, 105, 0.55 * amount)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * _unit);
    for (var i = 0; i < 9; i++) {
      final x = ((i * 150 * _unit - worldX * 0.5) % (_w + 300 * _unit)) - 150 * _unit;
      canvas.drawCircle(Offset(x, top + (i % 3) * 8 * _unit), (60 + (i * 23) % 30) * _unit, deck);
    }
    final paint = Paint()
      ..strokeWidth = 1.4 * _unit
      ..color = Color.fromRGBO(200, 215, 240, 0.4 * amount);
    final n = (60 * amount).round();
    final fall = _h - top + 20 * _unit;
    for (var i = 0; i < n; i++) {
      final seed = i * 97.31;
      final x = ((seed * 13.7 + worldX * 0.6) % (_w + 60)) - 30;
      final y = top + 20 * _unit + ((seed * 7.9 + t * 900 * _unit) % fall);
      canvas.drawLine(Offset(x, y), Offset(x - 6 * _unit, y + 18 * _unit), paint);
    }
  }

  void _drawBolt(Canvas canvas, Size s) {
    final r = math.Random((_boltX * 1000).round());
    final path = Path()..moveTo(_boltX, _rainTop);
    var x = _boltX, y = _rainTop;
    while (y < _h) {
      y += _h * (0.04 + r.nextDouble() * 0.04);
      x += (r.nextDouble() - 0.5) * 40 * _unit;
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * _unit
        ..color = Color.fromRGBO(170, 200, 255, 0.35 * _bolt)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * _unit
        ..color = Color.fromRGBO(255, 255, 255, _bolt),
    );
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
