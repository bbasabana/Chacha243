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
    this.refuel = 0,
    this.reserve = 0,
    this.flightSeconds = 0,
    this.stageSeconds = 0,
    this.stageName = '',
    this.nextStage = '',
    this.armor = 0,
    this.boost = false,
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

  /// Le plein au sol : 0 aucun, 1 le camion arrive, 2 il remplit, 3 il repart.
  final int refuel;

  /// Le kérosène en réserve (0 à 100) : ce qui déborde du réservoir plein.
  final double reserve;

  /// Le temps passé en vol, et dans l'étape en cours (une zone de guerre, ou le ciel de paix).
  final double flightSeconds, stageSeconds;
  final String stageName;

  /// « Sortie en 1963 dans 1:20 », « Prochaine étape : Rébellions (1964) dans 2:30 ».
  final String nextStage;

  /// Le blindage des kits, de 0 à 0,5.
  final double armor;

  /// TURBO maintenu.
  final bool boost;
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
enum CabinMode { beltsAsk, beltsPay, beltsFastening, beltsDone, serving, served }

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
  _Jet(
    this.x,
    this.y,
    this.wait,
    this.speed,
    this.drift, {
    this.missile = false,
    this.part = false,
    this.heli = false,
    this.shots = 0,
    this.stopX = 0,
    this.aimed = false,
  });

  /// Un missile tiré par un chasseur qui vole avec toi : il avance à sa seule vitesse, on a le temps de l'esquiver.
  final bool aimed;

  /// Un hélicoptère de combat : lent, il se tient au-dessus de toi et tire.
  final bool heli;

  /// Un chasseur qui s'arrête devant toi (ou un hélicoptère) : il cherche ta hauteur,
  /// tire ses missiles l'un après l'autre, puis s'en va.
  bool get hunter => shots > 0 || stopX > 0;
  int shots;
  final double stopX;
  double fireT = 1.2, age = 0, vy = 0;
  bool leaving = false;

  /// Un avion de la crise dans la crise (le Sud-Kasaï) : bleu, avec une bande jaune.
  final bool part;

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
  _Pickup(this.kind, this.x, this.y, {this.event, this.label, this.slow = false});

  /// Lumumba et Kasa-Vubu passent lentement : on a le temps de les voir et de les attraper.
  final bool slow;

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
  TextPainter? label;
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
  _Cue(
    this.show,
    this.seconds, {
    this.hide,
    this.done,
    this.hold = false,
    this.urgent = false,
    this.still,
    this.story,
    this.at = 0,
  });

  /// L'année d'une fiche d'histoire : elle doit passer dans son année, avant les conseils ordinaires.
  final double? story;

  /// Le moment où le message a été mis dans la file.
  final double at;

  /// Encore vrai au moment de passer ? Un message périmé (« le kérosène va finir » après un plein) est sauté.
  final bool Function()? still;

  /// Passé devant les autres (une zone, l'Indépendance) : jamais jeté quand la file déborde.
  final bool urgent;

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
  void Function(String song, {double? level, bool loop})? onSong;

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

  /// Après un crash, l'avion se répare avant de reprendre : 1 500 dans la monnaie du moment.
  /// Sans assez d'argent ni de points, on ne peut pas reprendre : on recommence en 1960 pour récolter.
  static const repairFee = 1500;
  String repairBill = '';

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

  /// TURBO bloqué : un appui court l'allume et il reste allumé ; un autre appui l'arrête.
  /// Garder le pouce dessus marche toujours : il s'arrête quand on lâche.
  bool turboLock = false;
  DateTime? _turboDownAt;
  bool _turboStopping = false;

  void turboPress(bool down) {
    if (down) {
      _turboDownAt = DateTime.now();
      _turboStopping = turboLock;
      boost = true;
    } else {
      final quick =
          _turboDownAt != null && DateTime.now().difference(_turboDownAt!) < const Duration(milliseconds: 300);
      if (_turboStopping) {
        turboLock = false;
        boost = false;
      } else if (quick && phase == FlightPhase.cruising) {
        // On ne bloque le TURBO qu'en vol : sur la piste, on le garde appuyé pour décoller.
        turboLock = true;
      } else {
        boost = false;
      }
    }
    _pushHud();
  }

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

  /// Le temps de vol déjà fait avant la reprise.
  double startSeconds = 0;

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
  TextPainter? _truckLabel;
  final _trail = <Offset>[];
  final _jets = <_Jet>[];

  // Zones de turbulence
  WarZone? _zone;
  String _failWhy = '';

  // L'entretien en vol : un anneau bleu parcourt l'avion, l'état remonte jusqu'à 100 %.
  double _maintT = -1, _maintFrom = 100;
  static const _maintTime = 3.2;

  // La ligne droite : la tour demande le TURBO dans un ciel dégagé, l'avion file sans obstacle.
  double _straightT = -1, _straightHeld = 0, _nextStraight = 70;
  static const _straightTime = 9.0;

  // Les ceintures oubliées : un signal d'alarme, puis la faute se paie dans les turbulences.
  bool _beltsWarned = false, _beltPenalty = false;

  /// Après une faute de ceintures, le signal revient jusqu'à ce que les passagers soient attachés.
  double _beltsAgain = -1;

  /// Le blindage gagné avec les kits : chaque kit retire 10 % des dégâts, jusqu'à 50 %.
  double armor = 0;
  double _hurt(double d) => d * (1 - armor);

  /// Traverser un nuage noir secoue et abîme l'avion, sans coûter une vie : on le voit tout de suite.
  /// Seul un avion à 0 % d'état finit par tomber.
  void _stormHit() {
    if (invulnerable > 0 || _finaleT >= 0) return;
    final d = _hurt(10);
    condition = math.max(0, condition - d);
    invulnerable = 1.5;
    shake = math.max(shake, 0.35);
    _turbulence = math.max(_turbulence, 1.2);
    onBuzz?.call(160, 160);
    _wearArmor();
    _float('Orage · −${d.round()} % état', planeX, planeY - 40 * _unit, const Color(0xFFFFB04A));
    _pushHud();
  }

  /// La protection des kits s'use : chaque choc en retire 5 points.
  void _wearArmor() {
    if (armor <= 0) return;
    armor = math.max(0, armor - 0.05);
    _float('Protection ${(armor * 100).round()} %', planeX, planeY + planeLength * 0.35, const Color(0xFF8FD0FF));
  }

  /// Les petits textes qui montent d'un objet attrapé (« +16 % en réserve »).
  final _floats = <(TextPainter, double, double, double)>[];

  /// L'argent dépensé est perdu pour de bon : le point de reprise garde ce qui reste.
  void _keepMoney() {
    if (autopilot) return;
    final cp = checkpoint.value;
    if (cp == null) return;
    cp.money = money;
    cp.seconds = _flightT;
    cp.save();
  }

  int _flownMoney = 0;
  double _nextEarnFloat = 45;

  /// De l'argent gagné : il entre dans le portefeuille et s'affiche en vert au-dessus de l'avion.
  void _earn(int amount, String why) {
    if (amount <= 0) return;
    money += amount;
    _earnFloat(amount, why);
  }

  void _earnFloat(int amount, String why) {
    final y = math.max(_h * 0.2 + 22 * _unit, planeY - planeLength * 0.6);
    _float('+${_fmt(amount)} ${currencyAt(year)} · argent gagné ($why)', planeX, y, const Color(0xFF7CF29A));
  }

  void _float(String text, double x, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 15 * _unit,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Jamais hors de l'écran ni sous les panneaux du haut.
    _floats.add((tp, x.clamp(tp.width / 2 + 8, _w - tp.width / 2 - 8), y.clamp(_h * 0.2, _h * 0.8), 1.6));
  }

  void Function()? onHush;

  /// Le réservoir de secours : ce qui déborde du plein y va, on le verse quand le kérosène manque.
  double reserve = 0;
  bool _reserveSaid = false;

  /// Le temps en vol depuis le décollage, celui de l'étape en cours, celui depuis le dernier décollage.
  double _flightT = 0, _stageT = 0, _airT = 0, _zoneWarnT = -99;

  /// Le moment de l'Indépendance au premier vol : 0 pas encore, 1 en cours, 2 passé.
  int _indep = 0;
  double _indepT = 0, _indepShown = 1e9;

  /// Les pénuries : pendant ces mois-là, aucun bidon ne vient. Il faut tenir avec ses réserves.
  static const _shortages = [
    (1973.8, 1974.6, 'Choc pétrolier', 'Le prix du pétrole explose dans le monde'),
    (1991.7, 1992.3, 'Pillages de Kinshasa', 'Les dépôts de carburant sont vides'),
  ];
  int _shortageSaid = 0;
  (double, double, String, String)? get _shortage {
    for (final x in _shortages) {
      if (year >= x.$1 && year < x.$2) return x;
    }
    return null;
  }

  // Le camion-citerne au sol : il arrive, branche le tuyau, remplit, puis repart.
  double _truckT = -1, _fuelFrom = 0, _fuelTo = 0;
  static const _truckIn = 3.2, _truckPlug = 1.0, _truckOut = 3.0;
  double get _truckFill => math.max(2.5, (_fuelTo - _fuelFrom) / 100 * 9);
  int get _truckStep => _truckT < _truckIn + _truckPlug
      ? 1
      : _truckT < _truckIn + _truckPlug + _truckFill
      ? 2
      : 3;
  bool _startSent = false;
  int _yearSent = 0;
  bool _eightiesSaid = false;
  int _nextZone = 0, _wave = 0, _wavesCleared = 0, _decade = 0;

  /// Le temps passé dans la zone en cours, et le temps qu'elle dure : jamais plus de cinq minutes.
  double _zoneT = 0;
  bool _exitSaid = false;
  double _zoneBudget(WarZone z) => math.min(300, 180 + z.waves * 20).toDouble();
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
  bool _comfortOnStorm = false;
  bool _impact = false;

  /// Une vibration : durée en millisecondes, force de 1 à 255.
  void Function(int ms, int amplitude)? onBuzz;

  /// Arrête net toute vibration (le crash est fini).
  VoidCallback? onStill;
  bool _stilled = false;

  /// Le crash est fini (l'avion a touché le sol) : le bilan peut s'afficher.
  bool get crashShown => phase != FlightPhase.crashed || _wrecked || phaseTime > 2.8;

  /// Les visages des médaillons, chargés une fois au départ.
  final _portraits = <String, ui.Image>{};

  Future<void> _loadPortraits() async {
    final keys = {
      for (final e in independenceFaces) e.photo!,
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
      _flightT = startSeconds;
      checkpoint.value = Checkpoint(year, score, medals, money: money, seconds: _flightT);
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
      _indep = 2;
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
      case 'crash' || 'fauche':
        // Pour les captures : le bilan d'un crash, avec ou sans de quoi payer la réparation.
        autopilot = false;
        if (showcase == 'fauche') money = 200;
        _failWhy = 'Missile';
        lives = 0;
        _clearStage();
        _setPhase(FlightPhase.crashed);
        for (var i = 0; i < 4 * 60; i++) {
          _tick(_step);
        }
      case 'plein':
        // Pour les captures : le camion-citerne au milieu du plein.
        buyFuel();
        if (_truckT >= 0) _truckT = _truckIn + _truckPlug;
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
  }

  static String _clock(double s) {
    final m = s ~/ 60, r = (s % 60).floor();
    return m > 0 ? '$m min ${r.toString().padLeft(2, '0')} s' : '$r s';
  }

  void _report(String kind, [String detail = '']) {
    if (autopilot) return;
    Telemetry.send(
      kind,
      year: year,
      score: score,
      stage: _zone?.name ?? _airline.name,
      detail: detail,
      seconds: _flightT,
    );
  }

  void _setPhase(FlightPhase p) {
    // Un TURBO bloqué s'arrête dès qu'on quitte le vol (approche, sol, crash).
    if (turboLock && p != FlightPhase.cruising) {
      turboLock = false;
      boost = false;
    }
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
        // On reprendra au dernier point de reprise, avec l'argent qui reste maintenant,
        // moins la réparation de l'avion : l'argent d'abord, puis les points du point de reprise.
        final cp = checkpoint.value;
        if (cp != null) {
          var owe = repairFee;
          final cash = math.min(math.max(0, money), owe);
          owe -= cash;
          final pts = math.min(cp.score, owe);
          owe -= pts;
          cp.score -= pts;
          money -= cash + owe;
          repairBill = [
            'Réparation de l\'avion : ${_fmt(repairFee)} ${currencyAt(year)}',
            if (cash > 0) '${_fmt(cash)} payés',
            if (pts > 0) '${_fmt(pts)} points',
            if (owe > 0) 'il manque ${_fmt(owe)}',
          ].join(' · ');
          cp.money = money;
          cp.seconds = _flightT;
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
  static const _breath = 3.6;

  void _cue(
    VoidCallback show,
    double seconds, {
    VoidCallback? hide,
    bool Function()? done,
    bool hold = false,
    bool first = false,
    bool Function()? still,
    double? story,
  }) {
    final c = _Cue(show, seconds, hide: hide, done: done, hold: hold, urgent: first, still: still, story: story, at: t);
    if (first) {
      // Derrière les autres messages urgents déjà en tête, pour garder leur ordre.
      final at = _cues.indexWhere((x) => !x.urgent);
      _cues.insert(at < 0 ? _cues.length : at, c);
    } else if (story != null) {
      // Une fiche d'histoire passe avant les conseils ordinaires, derrière les fiches déjà en attente.
      final at = _cues.indexWhere((x) => !x.urgent && x.story == null);
      _cues.insert(at < 0 ? _cues.length : at, c);
    } else {
      _cues.add(c);
    }
    // Quand l'histoire s'emballe, on jette les messages ordinaires les plus anciens, jamais les urgents ni l'histoire.
    while (_cues.length > 12) {
      final old = _cues.indexWhere((x) => !x.urgent && x.story == null);
      if (old < 0) break;
      _cues.removeAt(old);
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
    // Les messages qui ne sont plus vrais s'en vont sans s'afficher.
    // Un conseil ordinaire qui attend depuis trop longtemps ne parle plus de ce qui se passe : il s'en va aussi.
    bool stale(_Cue c) => !(c.still?.call() ?? true) || (!c.urgent && !c.hold && c.story == null && t - c.at > 45);
    while (_cues.isNotEmpty && stale(_cues.first)) {
      _cues.removeAt(0);
    }
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
      _cue(() => banner.value = b, 5.5, hide: () => banner.value = null, first: first);

  void _showCard(HistoryEvent e, {bool caught = true, String? label}) {
    if (e.big && caught) {
      // Grand tournant : le ciel bout, le drapeau change, la fiche suit.
      _cue(
        () {
          if (e.song != null && e.kind != EventKind.memory) _song(e.song!);
          _boil = 4.5;
          slowMo = math.max(slowMo, 3.5);
          shake = 0.3;
          turningPoint.value = TurningPoint(e, flagAt(e.year - 0.02).style, flagAt(e.year + 0.12).style);
        },
        7,
        hide: () => turningPoint.value = null,
        story: e.year,
      );
    }
    _cue(
      () {
        if (e.song != null && e.kind != EventKind.memory && !(e.big && caught)) _song(e.song!);
        card.value = StoryCard(e, caught: caught, label: label);
      },
      _readTime(e),
      hide: () => card.value = null,
      story: e.year,
      // Lumumba et Kasa-Vubu : leur fiche suit tout de suite le médaillon, avant les conseils de la tour.
      first: independenceFaces.contains(e),
    );
  }

  /// Quand l'histoire parle (une fiche, un grand tournant, des messages qui attendent), les années ralentissent :
  /// on lit, on apprend, puis le temps reprend.
  double get _storyPace {
    // Une fiche attend alors que son année est passée : le calendrier l'attend, pour qu'elle passe dans son année.
    if (_cues.any((c) => c.story != null && c.story! < year - 0.2)) return 0;
    if (turningPoint.value != null || card.value != null) return 0.3;
    final waiting = _cues.where((c) => !c.hold).length;
    return waiting >= 3 ? 0.5 : 1;
  }

  /// Le temps de lire une fiche : environ trois mots par seconde, jamais moins de 9 secondes, au plus 18.
  double _readTime(HistoryEvent e) {
    final words = '${e.title} ${e.date} ${e.city} ${e.text}'.split(' ').length;
    // Un grand tournant ou une photo à regarder : on laisse le temps de lire et de voir.
    final least = e.big ? 15.0 : (e.kind == EventKind.memory || e.photo != null ? 12.0 : 9.0);
    return (3 + words / 3).clamp(least, e.big ? 20.0 : 18.0);
  }

  void _loseLife([String why = 'Touché en vol']) {
    if (invulnerable > 0 || phase != FlightPhase.cruising || _finaleT >= 0) return;
    _failWhy = why;
    lives -= 1;
    condition = math.max(0, condition - _hurt(20));
    _wearArmor();
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

  /// Mesure du temps passé par image (vol de test lancé avec --dart-define=BENCH=…).
  static const bench = String.fromEnvironment('BENCH');
  final _sw = Stopwatch();
  int _benchFrames = 0, _benchUpdate = 0, _benchRender = 0;
  double _benchT = 0;

  @override
  // ignore: must_call_super
  void update(double dt) {
    if (bench.isEmpty) return _update(dt);
    _sw
      ..reset()
      ..start();
    _update(dt);
    _benchUpdate += _sw.elapsedMicroseconds;
    _benchFrames++;
    _benchT += dt;
    if (_benchT >= 3) {
      debugPrint(
        'BENCH y=${year.toStringAsFixed(2)} fps=${(_benchFrames / _benchT).toStringAsFixed(0)} '
        'update=${_benchUpdate ~/ _benchFrames}µs render=${_benchRender ~/ _benchFrames}µs '
        'clouds=${_clouds.length} parts=${_particles.length} jets=${_jets.length} pick=${_pickups.length} '
        'storm=${year < stormUntil} zone=${_zone?.name}',
      );
      _benchFrames = _benchUpdate = _benchRender = 0;
      _benchT = 0;
    }
  }

  @override
  // ignore: must_call_super
  void render(Canvas canvas) {
    if (bench.isEmpty) return _render(canvas);
    _sw
      ..reset()
      ..start();
    _render(canvas);
    _benchRender += _sw.elapsedMicroseconds;
  }

  void _update(double dt) {
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
    for (var i = _floats.length - 1; i >= 0; i--) {
      final f = _floats[i];
      final life = f.$4 - dt;
      life <= 0 ? _floats.removeAt(i) : _floats[i] = (f.$1, f.$2, f.$3 - 34 * _unit * dt, life);
    }
    if (phase == FlightPhase.cruising) {
      _updateMaint(dt);
      _updateStraight(dt);
    }
    magnetTime = math.max(0, magnetTime - dt);
    magnetCooldown = math.max(0, magnetCooldown - dt);
    _boil = math.max(0, _boil - dt);

    switch (phase) {
      case FlightPhase.ready:
        _updateTruck(dt);
        if (boost && _truckT >= 0) {
          if (!_refuelSaid) {
            _refuelSaid = true;
            _say('Tour de ${_airport?.cityAt(year) ?? 'contrôle'}', Lingala.zelaMoke, 'Attends la fin du plein.');
          }
        } else if (boost && fuel < 50) {
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
          if (_impact && !_stilled && phaseTime > 2.6) {
            _stilled = true;
            onStill?.call();
          }
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
    // Seulement quand l'avion est vraiment secoué : pas pendant toute une époque d'orages.
    if (_turbulence > 0 && phase == FlightPhase.cruising && t >= _nextBuzz) {
      _nextBuzz = t + 2.4 + _rng.nextDouble() * 0.8;
      onBuzz?.call(80, 90);
    }

    _runStage(dt);
    _hudTimer -= dt;
    if (_hudTimer <= 0) {
      // Le tableau de bord se met à jour 5 fois par seconde : assez pour l'œil, bien moins de travail.
      _hudTimer = 0.2;
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
      // Un chasseur arrêté qui vise n'est pas sur ton chemin : ce sont ses missiles qu'il faut éviter.
      // Pour ce qui file vers toi, on regarde aussi où il passera quand il arrivera à ta hauteur.
      for (final j in _jets)
        if (j.x > planeX - _jetLength * 0.5 && j.wait < 0.5 && !(j.hunter && !j.leaving)) ...[
          Offset(j.x, j.y),
          Offset(j.x, j.y + j.drift * ((j.x - planeX) / (j.speed + (j.aimed ? 0 : _scroll))).clamp(0.0, 3.0)),
        ],
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
      _airT = 0;
      _setPhase(FlightPhase.cruising);
      _nextOffer = t + 20;
      // La cabine parle juste après le décollage, derrière les messages de la tour et de l'Indépendance.
      if (passengers > 0) _talk(TalkMoment.takeoff, force: true);
      if (_takeoffs++ == 0) {
        if (_indep == 0 && year < 1960.6) _startIndependence();
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
    _flightT += dt;
    _stageT += dt;
    _airT += dt;
    if (_zone == null) {
      // Juste après le décollage, le ciel est calme : l'histoire reprend après quelques secondes.
      year +=
          dt *
          ts /
          _yearSeconds *
          (boost ? 1.6 : 1) *
          _storyPace *
          (_indep == 1 || _maintT >= 0 ? 0 : (_airT < 14 ? 0.06 : 1));
      _checkDecade();
    } else {
      _updateZone(dt * ts);
    }
    if (_indep == 1) _updateIndependence();
    if (_airT >= 10 && _indep != 1) _checkZone();
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
      // Une fois sur trois, dans le calme, le commandant rappelle le but du voyage.
      if (_chats++ % 3 == 0) {
        _goalTalk();
      } else {
        _talk(TalkMoment.chat);
      }
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
    // Pendant l'entretien, les commandes sont bloquées : l'avion tient sa ligne le temps de la réparation.
    if (_maintT >= 0) targetVy = targetVx = 0;
    vy += (targetVy - vy) * math.min(1, dt * 8);
    vx += (targetVx - vx) * math.min(1, dt * 6);
    planeY = (planeY + vy * dt).clamp(_h * 0.12, _h * 0.88);
    planeX = (planeX + vx * dt).clamp(_w * 0.1, _w * 0.45);
    // En guerre, le kérosène part bien plus vite.
    fuel -= dt * ts * (1.15 + (boost ? 1.3 : 0)) * (1.35 - type.tank * 0.6) * (_zone != null ? 1.8 : 1);
    condition = math.max(0, condition - _hurt(dt * ts * 0.15));
    if (fuel < 25 && !_lowFuelSaid) {
      _lowFuelSaid = true;
      _say(
        'Tour de contrôle',
        Lingala.mafuta,
        reserve >= 5
            ? 'Kérosène à 25 %. Ta réserve (${reserve.round()} %) sera versée toute seule dans le réservoir à 12 %.'
            : 'Kérosène à 25 % et pas de réserve. Attrape un bidon rouge ou fais escale.',
        still: () => fuel < 30,
      );
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
            ? 'Ton avion est abîmé à ${condition.round()} %. Que faire : attrape le rond BLEU avec une clé qui arrive '
                  'dans quelques secondes, il répare l\'avion. Ou touche ATTERRIR : à l\'aéroport, l\'entretien le remet à 100 %.'
            : 'Ton avion est abîmé à ${condition.round()} %. Que faire : attrape le rond BLEU avec une clé qui arrive '
                  'dans quelques secondes. Dès la fin de la zone, touche ATTERRIR pour l\'entretien.',
        first: true,
        still: () => condition < 40 && _maintT < 0,
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
        still: () => fuel < 55,
      );
    }
    // L'alerte ne vient que si la réserve ne suffit pas à tenir.
    if (fuel < 22 && fuel + reserve < 30 && t >= _nextFuelAlert && !_offerPending) _fuelAlert();
    if (fuel < 14 && _quizCount < 3 && t >= _nextQuiz || quizNow) {
      quizNow = false;
      _askQuiz();
    }
    // Le kit attend que la fiche d'histoire soit lue : on n'apprend pas en esquivant.
    if (t >= _nextKit && (fuel < 55 || condition < 55) && card.value == null && turningPoint.value == null) _spawnKit();
    // La réserve se verse toute seule quand le réservoir descend à 12 %.
    if (fuel < 12 && reserve >= 1) {
      useReserve(auto: true);
    } else if (fuel <= 0) {
      fuel = 45;
      _queueBanner(
        const FlightBanner('Panne sèche !', "Ravitaillement d'urgence : une vie en moins", color: ChachaColors.red),
      );
      _loseLife('Panne sèche');
    }
    if (year.floor() > _yearSent && _startSent) {
      _yearSent = year.floor();
      _report('year');
      // Chaque nouvelle année hors d'une guerre devient le point de reprise : après un crash en 1994,
      // on reprend en 1994, pas au début de la décennie.
      if (_zone == null && phase == FlightPhase.cruising && _finaleT < 0) _saveCheckpoint(year);
    }
    // On quitte les années 1970 : Zaïko Langa Langa ouvre les années 1980, dans un ciel sans obstacle.
    if (!_eightiesSaid && year >= 1980 && year < 1981 && _zone == null && phase == FlightPhase.cruising) {
      _eightiesSaid = true;
      _calmUntil = math.max(_calmUntil, t + 40);
      _queueBanner(
        const FlightBanner(
          'Bienvenue dans les années 1980',
          '♪ Zaïko Langa Langa · Ngwasuma · ciel calme, profite',
          color: ChachaColors.yellow,
        ),
        first: true,
      );
      _song('ngwasuma');
    }

    _spawnHistory();
    _spawnAmbient();
    _checkEras();
    // Une reprise entre 1997 et 2001 retrouve « Franc congolais ».
    if (year >= 1997.38 && year < 2001 && phase == FlightPhase.cruising && _finaleT < 0) _startFranc();

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
    // Pendant l'entretien, les commandes sont bloquées : l'avion tient sa ligne le temps de la réparation.
    if (_maintT >= 0) targetVy = targetVx = 0;
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
    boost = turboLock = false;
    mission.value = null;
    cabin.value = null;
    _offerPending = false;
    _clearStage();
    if (passengers == 0) passengers = (type.seats * 0.8).round();
    _song('moloto');
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
        _finaleStep++;
      case 3 when _finaleT >= 18:
        _stormWall();
        flash = 0.5;
        _finaleStep++;
      case 4 when _finaleT >= 20.5:
        slowMo = 1.4;
        shake = 0.45;
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
    // Chacun parle à son tour : une seule bulle à l'écran, on la lit, elle s'en va, puis la réponse vient.
    for (final l in lines) {
      final each = seconds != null ? seconds / lines.length : _lineTime(l);
      _cue(() => talk.value = CabinTalk([l]), each, hide: () => talk.value = null);
    }
    _nextTalk = t + 20;
  }

  final _talkBags = <TalkMoment, List<int>>{};
  int _chats = 0;

  /// La part du voyage qui reste jusqu'au 30 juin 2027, en pour cent.
  int get tripLeft => ((2027.5 - year) / (2027.5 - 1960.5) * 100).clamp(0, 100).ceil();

  void _goalTalk() {
    final left = tripLeft;
    _cue(
      () => talk.value = CabinTalk([
        TalkLine(
          'Commandant',
          'Mokano na biso : kokoma na 30 juin 2027. Tokokoma !',
          'Notre objectif : arriver le 30 juin 2027. Nous y arriverons ! Il reste $left % du voyage.',
        ),
      ]),
      7,
      hide: () => talk.value = null,
    );
    _nextTalk = t + 20;
  }

  /// Le temps de lire une réplique, en lingala puis en français.
  double _lineTime(TalkLine l) => (2.5 + '${l.lingala} ${l.french}'.split(' ').length / 3.2).clamp(4.0, 8.0);

  /// Un moment difficile : une louange douce réconforte, sans revenir trop souvent.
  void _comfort() {
    if (t < _nextComfort || _finaleT >= 0) return;
    _nextComfort = t + 75;
    _song('louange');
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
      () => talk.value = CabinTalk([TalkLine('Commandant', b.oursLingala, b.ours.replaceAll('{to}', tr.to))]),
      5,
      hide: () => talk.value = null,
    );
    _cue(
      () => talk.value = const CabinTalk([TalkLine('Passagers', 'Ha ha ha !', 'Ha ha ha !')]),
      2.5,
      hide: () => talk.value = null,
    );
    _nextTalk = t + 20;
  }

  void _spawnHistory() {
    final secondsToPlane = (_w + 60 - planeX) / _scroll;
    final lead = secondsToPlane / _yearSeconds * (boost ? 1.6 : 1);
    while (_nextEvent < historyEvents.length && historyEvents[_nextEvent].year <= year + lead) {
      final e = historyEvents[_nextEvent++];
      // La mort de Mzee arrête « Franc congolais » ; Indépendance Cha Cha prend la suite.
      if (e.year >= 2001 && _francOn) {
        _francOn = false;
        _francDone = true;
      }
      switch (e.kind) {
        case EventKind.life:
        case EventKind.glory:
          // Un visage (Mobutu, Abala…) passe au milieu de l'écran, lentement, et on l'annonce avant.
          final face = e.intro != null || (e.photo != null && (archivePhotos[e.photo]?.isPortrait ?? false));
          final y = face ? _h * (0.46 + _rng.nextDouble() * 0.08) : _h * (0.18 + _rng.nextDouble() * 0.64);
          if (face) {
            _cue(
              () => banner.value = FlightBanner(
                e.medal ?? e.title,
                '${e.intro ?? e.date} · son médaillon arrive au milieu, attrape-le',
                color: ChachaColors.yellow,
              ),
              5,
              hide: () => banner.value = null,
              first: true,
            );
          }
          _pickups.add(
            _Pickup(
              _PickupKind.medal,
              _w + 60,
              y,
              event: e,
              label: _label(e.medal ?? '${e.yearLabel}', 15 * _unit),
              slow: face,
            ),
          );
        case EventKind.obstacle:
          // Les guerres se traversent en vagues d'avions de chasse, les autres épreuves en orages.
          if (!e.war) {
            stormUntil = math.max(stormUntil, e.year + lead + 0.9);
            _nextStorm = t + secondsToPlane * 0.2;
            _talk(e.volcano ? TalkMoment.volcano : TalkMoment.storm);
            _comfortOnStorm = true;
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
          // Le souvenir arrive avec un bidon : on garde de quoi continuer le voyage.
          if (_shortage == null) {
            _pickups.add(_Pickup(_PickupKind.fuel, _w + 160 * _unit, _h * (0.3 + _rng.nextDouble() * 0.4)));
          }
          if (e.song != null) _song(e.song!);
      }
    }
  }

  void _spawnAmbient() {
    final d = _level;
    if (year < stormUntil && t >= _nextStorm && _straightT < 0) {
      if (_comfortOnStorm) {
        // La louange vient avec le premier nuage d'orage, quand l'obstacle est là.
        _comfortOnStorm = false;
        _comfort();
      }
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
    final short = _shortage;
    if (short != null && _shortageSaid < _shortages.indexOf(short) + 1) {
      _shortageSaid = _shortages.indexOf(short) + 1;
      // C'est le pays qui manque de carburant, pas ton avion : on le dit, avec ce qu'il te reste.
      _cue(
        () => banner.value = FlightBanner(
          'Pénurie dans le pays · ${short.$3} (${short.$1.floor()})',
          '${short.$4} : pas de bidon en vol un moment · ton avion : ${fuel.round()} %'
              '${reserve >= 1 ? ' + ${reserve.round()} % de réserve' : ''}',
          color: const Color(0xFFFFB04A),
        ),
        8,
        hide: () => banner.value = null,
        first: true,
      );
    }
    if (t >= _nextFuel && short == null) {
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
    bool Function()? still,
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
    _cue(show, seconds, hide: hide, done: offer == null ? null : () => !_offerPending, first: first, still: still);
  }

  /// Plus assez d'argent ni de points pour le kérosène en vol : la tour fait descendre l'avion.
  /// Au sol, le plein est fait à crédit ; la dette se rembourse avec l'argent gagné ensuite.
  void _mustLand() {
    if (_zone != null || !canLand || _offerPending) return;
    _airport = _nearestAirport();
    _stopPurpose = 0;
    _gusty = false;
    _offerPending = true;
    final city = _airport!.cityAt(year);
    _cue(
      () => radio.value = RadioCall(
        'Tour de $city',
        Lingala.kitaMalembe,
        'Tu n\'as plus assez d\'argent pour le kérosène (${_fmt(math.max(0, money))} ${currencyAt(year)}). '
            'Tu dois descendre à $city : le plein te sera fait à crédit.',
      ),
      6,
      hide: () {
        radio.value = null;
        if (_offerPending && phase == FlightPhase.cruising && canLand) {
          _startApproach();
          _queueBanner(FlightBanner('Descente obligatoire', '${_airport!.titleAt(year)} · plein à crédit'));
        } else {
          _offerPending = false;
        }
      },
      first: true,
    );
  }

  /// En dette, l'argent gagné rembourse d'abord ce qui est dû ; on le voit une fois, quand c'est fini.
  bool _inDebt = false;
  void _watchDebt() {
    if (money < 0) {
      _inDebt = true;
    } else if (_inDebt) {
      _inDebt = false;
      _queueBanner(
        const FlightBanner('Dette remboursée', 'L\'argent gagné reste maintenant à toi', color: _peaceGreen),
      );
    }
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
    // Pas de quoi payer même un peu de kérosène en vol : il faut descendre, l'aéroport fait crédit.
    if (money + score < fuelPrice * 10) return _mustLand();
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
      still: () => fuel < 30,
    );
    HapticFeedback.heavyImpact();
  }

  /// Acheter le plein : avec l'argent d'abord, puis en convertissant des points.
  /// Ajoute du kérosène ; au-delà du plein, il part en réserve.
  /// Le 30 juin 1960 : la fête d'abord, puis Lumumba et Kasa-Vubu passent devant l'avion.
  /// Les années et les zones attendent que les deux médaillons soient passés.
  void _startIndependence() {
    _indep = 1;
    _indepT = t;
    // La fête du 30 juin remplace le médaillon de l'Indépendance : « Indépendance Cha Cha » joue doucement
    // dès le décollage, et se tait quand la sécession du Katanga approche.
    _pickups.removeWhere((p) => p.event != null && p.event!.year <= 1960.5);
    while (_nextEvent < historyEvents.length && historyEvents[_nextEvent].year <= 1960.5) {
      _nextEvent++;
    }
    _song('chacha', level: 0.35, loop: true);
    // Le roulage a pu faire passer quelques jours : on revient au 30 juin, avant la sécession.
    year = math.min(year, 1960.51);
    _cue(
      () {
        banner.value = const FlightBanner(
          'Indépendance · 30 juin 1960',
          'Lumumba et Kasa-Vubu arrivent · attrape leurs médaillons : kérosène, réserve et argent',
          color: ChachaColors.yellow,
        );
        for (var i = 0; i < independenceFaces.length; i++) {
          final e = independenceFaces[i];
          _pickups.add(
            _Pickup(
              _PickupKind.medal,
              _w + 60 + i * _w * 0.75,
              _h * (i.isEven ? 0.38 : 0.55),
              event: e,
              label: _label(e.medal!, 15 * _unit),
              slow: true,
            ),
          );
        }
        _indepShown = t;
      },
      9,
      hide: () => banner.value = null,
      // Le message reste tant que Lumumba et Kasa-Vubu sont à l'écran.
      hold: true,
      done: () => t > _indepShown + 9 && !_pickups.any((p) => independenceFaces.contains(p.event)),
      first: true,
    );
  }

  /// Le ciel est libre : la tour rappelle qu'on peut maintenir TURBO pour avancer plus vite.
  void _freeSky() => _queueBanner(
    const FlightBanner(
      'Tu es dans une zone libre',
      'Pas de guerre devant · maintiens TURBO pour accélérer et avancer plus vite',
      color: _peaceGreen,
    ),
  );

  void _updateIndependence() {
    final waiting = _pickups.any((p) => independenceFaces.contains(p.event));
    // Les deux médaillons sont passés (ou un message les a retardés trop longtemps) : l'histoire reprend.
    if ((!waiting && t > _indepShown + 9) || t > _indepT + 90) {
      _indep = 2;
      _airT = 0;
      if (_nextZone < warZones.length && warZones[_nextZone].from - year > 0.3) _freeSky();
    }
  }

  void _addFuel(double amount) {
    final room = 100 - fuel;
    if (amount <= room) {
      fuel += amount;
      return;
    }
    fuel = 100;
    final before = reserve;
    // La réserve se remplit moins vite que le réservoir, et ne dépasse pas 60 %.
    reserve = math.min(60, reserve + (amount - room) * 0.5);
    if (reserve > before) {
      _float(
        'Plein · +${(reserve - before).round()} % en RÉSERVE',
        planeX,
        planeY - planeLength * 0.25,
        ChachaColors.yellow,
      );
    } else if (reserve >= 60) {
      _float('Plein · réserve pleine', planeX, planeY - planeLength * 0.25, Colors.white);
    }
    if (reserve > before && !_reserveSaid) {
      _reserveSaid = true;
      _queueBanner(
        FlightBanner(
          'Réservoir plein',
          'Le reste part en réserve : ${reserve.round()} % · touche RÉSERVE quand il manquera',
          color: _peaceGreen,
        ),
      );
    }
  }

  /// Ce qui a fait tomber l'avion, et le temps de vol : le panneau du crash les affiche.
  String get failWhy => _failWhy;

  /// L'argent gagné (ou perdu) pendant ce vol, depuis le décollage ou la reprise.
  int get moneyEarned => money - (startMoney ?? 3000);
  double get flightSeconds => _flightT;

  bool get canUseReserve => reserve >= 1 && fuel < 90 && phase == FlightPhase.cruising;

  /// Verse la réserve dans le réservoir.
  void useReserve({bool auto = false}) {
    if (reserve < 1 || fuel >= 99) return;
    final put = math.min(reserve, 100 - fuel);
    reserve -= put;
    fuel += put;
    if (fuel >= 25) _lowFuelSaid = false;
    onSound?.call('kerosene');
    _queueBanner(
      FlightBanner(
        auto ? 'Ta réserve est utilisée' : 'Réserve versée',
        'Réservoir à ${fuel.round()} % · il reste ${reserve.round()} % en réserve',
        color: _peaceGreen,
      ),
      first: true,
    );
    _pushHud();
  }

  void buyFuel() {
    final price = fuelBill;
    if (price <= 0 || _truckT >= 0) return;
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
        if (phase == FlightPhase.cruising) _mustLand();
        return;
      }
    }
    money -= pay;
    _keepMoney();
    _float('−${_fmt(pay)} ${currencyAt(year)}', _w * 0.5, _h * 0.42, const Color(0xFFFF8A8A));
    if (phase == FlightPhase.ready) {
      // Au sol, le kérosène arrive par le camion-citerne : le réservoir se remplit sous les yeux.
      if (_truckT >= 0) return;
      _fuelFrom = fuel;
      _fuelTo = math.min(100, fuel + pay / fuelPrice);
      _truckT = 0;
      _pushHud();
      return;
    }
    fuel = math.min(100, fuel + pay / fuelPrice);
    _offerPending = false;
    _lowFuelSaid = _halfFuelSaid = false;
    onSound?.call('kerosene');
    _queueBanner(
      FlightBanner('Kérosène acheté', 'Réservoir à ${fuel.round()} % · −${_fmt(pay)} $cur', color: _peaceGreen),
    );
    _pushHud();
  }

  void _updateTruck(double dt) {
    if (_truckT < 0) return;
    _truckT += dt;
    final f0 = _truckIn + _truckPlug;
    if (_truckT >= f0) fuel = _fuelFrom + (_fuelTo - _fuelFrom) * ((_truckT - f0) / _truckFill).clamp(0.0, 1.0);
    if (_truckT >= f0 + _truckFill && fuel != _fuelTo) fuel = _fuelTo;
    if (_truckT >= f0 + _truckFill + _truckOut) {
      _truckT = -1;
      fuel = _fuelTo;
      _lowFuelSaid = _halfFuelSaid = false;
      onSound?.call('kerosene');
      _queueBanner(
        FlightBanner(
          fuel >= 50 ? 'Prêt à décoller' : 'Plein partiel',
          'Réservoir à ${fuel.round()} % · maintiens TURBO',
          color: _peaceGreen,
        ),
        first: true,
      );
      _pushHud();
    }
  }

  /// Le camion-citerne, rouge et blanc, avec son tuyau branché sous l'aile pendant le plein.
  void _drawTruck(Canvas canvas) {
    if (_truckT < 0 || phase != FlightPhase.ready) return;
    final u = _unit, len = planeLength * 0.42, h = len * 0.42;
    final stop = planeX + planeLength * 0.42;
    final f0 = _truckIn + _truckPlug, out0 = f0 + _truckFill;
    double ease(double x) => 1 - math.pow(1 - x.clamp(0.0, 1.0), 3).toDouble();
    final double x;
    if (_truckT < _truckIn) {
      x = _w + len - (_w + len - stop) * ease(_truckT / _truckIn);
    } else if (_truckT < out0) {
      x = stop;
    } else {
      final k = ((_truckT - out0) / _truckOut).clamp(0.0, 1.0);
      x = stop + (_w + len * 2 - stop) * k * k;
    }
    final base = groundY + 26 * u;
    final moving = _truckT < _truckIn || _truckT > out0;
    // tuyau
    if (_truckT >= _truckIn && _truckT < out0 + 0.4) {
      final plug = ((_truckT - _truckIn) / _truckPlug).clamp(0.0, 1.0);
      final a = Offset(x - len * 0.42, base - h * 0.55);
      final b = Offset(planeX + planeLength * 0.05, planeY + planeLength * 0.04);
      final end = Offset.lerp(a, b, plug)!;
      final mid = Offset((a.dx + end.dx) / 2, math.max(a.dy, end.dy) + 16 * u);
      final hose = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
      canvas.drawPath(
        hose,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4 * u
          ..color = const Color(0xFF1C1C1C),
      );
      if (_truckStep == 2) {
        // le kérosène coule : des points lumineux suivent le tuyau
        for (final m in hose.computeMetrics()) {
          for (var i = 0; i < 4; i++) {
            final p = m.getTangentForOffset(m.length * ((t * 0.9 + i / 4) % 1))?.position;
            if (p != null) canvas.drawCircle(p, 2 * u, Paint()..color = const Color(0xFFF7D618));
          }
        }
      }
    }
    canvas.save();
    canvas.translate(x, base);
    // ombre
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 2 * u), width: len * 1.05, height: 7 * u),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final wheelR = h * 0.17;
    final chassis = RRect.fromRectAndRadius(
      Rect.fromLTRB(-len / 2, -wheelR * 1.6, len / 2, -wheelR * 0.6),
      Radius.circular(2 * u),
    );
    canvas.drawRRect(chassis, Paint()..color = const Color(0xFF2A2A2E));
    // citerne
    final tank = RRect.fromRectAndRadius(
      Rect.fromLTRB(-len * 0.2, -h * 0.92, len / 2, -wheelR * 1.5),
      Radius.circular(h * 0.3),
    );
    canvas.drawRRect(
      tank,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFD9DEE6)],
        ).createShader(tank.outerRect),
    );
    canvas.drawRect(Rect.fromLTRB(-len * 0.2, -h * 0.62, len / 2, -h * 0.5), Paint()..color = ChachaColors.red);
    final label = _truckLabel ??= TextPainter(
      text: TextSpan(
        text: 'KÉROSÈNE',
        style: TextStyle(color: ChachaColors.red, fontSize: h * 0.16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(len * 0.15 - label.width / 2, -h * 0.86));
    // cabine (vers la gauche, le sens d'arrivée)
    final cab = Path()
      ..moveTo(-len / 2, -wheelR * 1.5)
      ..lineTo(-len / 2, -h * 0.62)
      ..lineTo(-len * 0.4, -h * 0.82)
      ..lineTo(-len * 0.24, -h * 0.82)
      ..lineTo(-len * 0.24, -wheelR * 1.5)
      ..close();
    canvas.drawPath(cab, Paint()..color = ChachaColors.red);
    canvas.drawPath(
      Path()
        ..moveTo(-len * 0.47, -h * 0.6)
        ..lineTo(-len * 0.39, -h * 0.76)
        ..lineTo(-len * 0.28, -h * 0.76)
        ..lineTo(-len * 0.28, -h * 0.6)
        ..close(),
      Paint()..color = const Color(0xFF9FD3FF),
    );
    // gyrophare
    final blink = (t * 3).floor().isEven;
    canvas.drawCircle(
      Offset(-len * 0.33, -h * 0.86),
      2.6 * u,
      Paint()..color = blink ? const Color(0xFFFFB020) : const Color(0xFF7A5200),
    );
    // roues
    final spin = moving ? t * 12 : 0.0;
    for (final wx in [-len * 0.36, len * 0.18, len * 0.36]) {
      canvas.drawCircle(Offset(wx, -wheelR), wheelR, Paint()..color = const Color(0xFF141414));
      canvas.drawCircle(Offset(wx, -wheelR), wheelR * 0.45, Paint()..color = const Color(0xFF9AA0A8));
      canvas.drawLine(
        Offset(wx, -wheelR) + Offset(math.cos(spin), math.sin(spin)) * wheelR * 0.45,
        Offset(wx, -wheelR) - Offset(math.cos(spin), math.sin(spin)) * wheelR * 0.45,
        Paint()
          ..color = const Color(0xFF3A3A3A)
          ..strokeWidth = 1.4 * u,
      );
    }
    canvas.restore();
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
  }

  /// Le joueur accepte l'escale : on commence l'approche.
  void acceptStopover() {
    if (!_offerPending || phase != FlightPhase.cruising) return;
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

  /// La louange de la paix : un extrait, puis l'autre la fois suivante.
  /// De la fin de la guerre de l'AFDL (1997) à la mort de Mzee (2001), seule « Franc congolais » joue.
  bool _francOn = false, _francDone = false;

  void _song(String key, {double? level, bool loop = false}) {
    if (_francOn && key != 'franc') return;
    onSong?.call(key, level: level, loop: loop);
  }

  void _startFranc() {
    if (_francOn || _francDone) return;
    _francOn = true;
    _song('franc', loop: true);
  }

  int _peaceSongs = 0;
  void _peaceSong() => _song((_peaceSongs++).isEven ? 'paix1' : 'paix2');

  /// On ne vole jamais sans musique : après 12 secondes de silence, « Indépendance Cha Cha » revient doucement
  /// (sauf si le joueur a coupé la musique : elle joue alors à volume zéro).
  bool Function()? songBusy;
  double _silentFor = 0;
  void _fillSilence(double dt) {
    if (_finaleT >= 0 || phase != FlightPhase.cruising || (songBusy?.call() ?? true)) {
      _silentFor = 0;
      return;
    }
    _silentFor += dt;
    if (_silentFor < 12) return;
    _silentFor = 0;
    _song('fond');
  }

  void _startApproach() {
    // On descend vers l'aéroport avec la louange de la paix.
    _peaceSong();
    _offerPending = false;
    cabin.value = null;
    _approachT = 0;
    _approachY0 = planeY;
    _approachSpeed = _unit * 420;
    _prevShift = _groundShift;
    _cueGear = _cueRunway = _earlySaid = false;
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
    final kit = _Pickup(_PickupKind.repair, _w + 300 * _unit, _h * (0.25 + _rng.nextDouble() * 0.5));
    _pickups.add(kit);
    // Un seul message, et seulement tant que le kit est encore devant l'avion.
    _cue(
      () => banner.value = FlightBanner(
        'Kit d\'entretien en approche',
        'Le rond BLEU avec une clé : il répare l\'avion et refait le plein · avion à ${condition.round()} %',
        color: const Color(0xFF8FD0FF),
      ),
      5.5,
      hide: () => banner.value = null,
      first: true,
      still: () => !kit.taken && kit.x > planeX,
    );
  }

  /// Hauteur cible sur le couloir d'approche, [k] secondes après le début.
  double _glide(double k) {
    final f = (k / _approachTime).clamp(0.0, 1.0);
    return _approachY0 + (_planeOnGroundY - _approachY0) * (f * f * (3 - 2 * f));
  }

  bool _earlySaid = false;

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
    // L'arrondi : près du sol, l'avion freine sa descente tout seul, même si on pique un peu trop.
    final aboveGround = _planeOnGroundY + _groundShift - planeY;
    if (aboveGround < _h * 0.18) targetVy = math.min(targetVy, _h * (0.12 + aboveGround / _h * 1.4));
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
      final early = planeX <= _runwayStart * _unit - gx;
      if (_homeApproach) {
        planeY = groundOnPlane;
        _arriveHome();
      } else if (early) {
        // Trop tôt, avant la piste : l'avion rase le sol et attend qu'elle arrive, sans s'écraser.
        planeY = groundOnPlane - 2;
        vy = math.min(vy, 0);
        if (!_earlySaid) {
          _earlySaid = true;
          _say(
            'Tour de ${_airport!.cityAt(year)}',
            Lingala.kitaMalembe,
            'Pas encore ! Tiens-toi au-dessus du sol, la piste arrive.',
          );
        }
      } else if (!onRunway) {
        // Piste dépassée : on remet les gaz et on refait l'approche.
        planeY = groundOnPlane - 2;
        _approachT = _approachTime + 5;
      } else if (closing > _h * 0.95) {
        planeY = groundOnPlane;
        _crashLanding('Descente trop rapide');
      } else {
        planeY = groundOnPlane;
        _land();
      }
    }
    if (phase == FlightPhase.approach && _approachT > _approachTime + 4) {
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
      _earn(m.count * 40, 'passagers déposés');
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
    // L'aéroport fait toujours le plein. On paie avec l'argent, puis avec les points ;
    // ce qui manque devient une dette, remboursée ensuite avec l'argent gagné en volant.
    final want = ((100 - fuel) * fuelPrice).round();
    var left = landingFee + want;
    final cash = math.min(math.max(0, money), left);
    money -= cash;
    left -= cash;
    final pts = math.min(score, left);
    score -= pts;
    left -= pts;
    money -= left;
    _fuelTarget = 100;
    _bill = [
      'Droits ${_fmt(landingFee)} $cur · kérosène ${_fmt(want)} $cur',
      if (pts > 0) '${_fmt(pts)} points convertis',
      if (left > 0) 'dette ${_fmt(left)} $cur',
    ].join(' · ');
    _keepMoney();
  }

  void _updateCabin(double dt) {
    // On gagne de l'argent en volant : un peu pour l'avion, un peu par passager.
    _moneyAcc += dt * (6 + passengers / 6);
    if (_moneyAcc >= 1) {
      money += _moneyAcc.floor();
      _flownMoney += _moneyAcc.floor();
      _moneyAcc -= _moneyAcc.floor();
    }
    _watchDebt();
    _fillSilence(dt);
    // Toutes les 45 secondes, on voit ce que le vol a rapporté.
    if (_flownMoney >= 200 && t >= _nextEarnFloat && phase == FlightPhase.cruising) {
      _nextEarnFloat = t + 45;
      _earnFloat(_flownMoney, 'gagnés en vol');
      _flownMoney = 0;
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

    if (_beltsAgain >= 0 && t > _beltsAgain && cabin.value == null && phase == FlightPhase.cruising) {
      _beltsAgain = -1;
      if (passengers > 0) {
        _cue(
          () {
            _cabinT = 0;
            _beltsDeadline = t + 9;
            cabin.value = CabinHud(
              CabinMode.beltsAsk,
              0,
              passengers,
              'Serrez vos ceintures',
              'Les ceintures ne sont toujours pas attachées · touche le signal',
            );
            onSound?.call('ceinture');
          },
          0,
          hold: true,
          done: () => cabin.value == null,
          first: true,
        );
      }
    }
    final c = cabin.value;
    if (c != null) {
      _cabinT += dt;
      switch (c.mode) {
        case CabinMode.beltsAsk:
          if (autopilot && showcase != 'ceintures' && _cabinT > 1) fastenBelts();
          if (t > _beltsDeadline && !_beltsWarned && showcase != 'ceintures') {
            // D'abord l'alarme : les ceintures ne sont pas mises, il reste quelques secondes.
            _beltsWarned = true;
            _beltsDeadline = t + 6;
            onBuzz?.call(250, 200);
            onSound?.call('ceinture');
            _float('⚠ UN PASSAGER RISQUE DE TOMBER', _w * 0.5, _h * 0.36, const Color(0xFFFF7A7A));
            cabin.value = CabinHud(
              CabinMode.beltsAsk,
              0,
              passengers,
              '⚠ Attention : un passager risque de tomber !',
              'Touche le signal des ceintures, vite',
            );
          } else if (t > _beltsDeadline && showcase != 'ceintures') {
            _passengerFalls();
          }
        case CabinMode.beltsPay:
          // Sans réponse, on paie avec l'argent, sinon avec les points ; sans les deux, c'est le crash.
          if (autopilot && _cabinT > 1) payBelts(true);
          if (t > _beltsDeadline) {
            if (!payBelts(true) && !payBelts(false)) _beltsCrash();
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
            _earn(_sales, 'repas et boissons vendus');
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
      },
      0,
      hold: true,
      done: () => cabin.value == null,
    );
  }

  void fastenBelts() {
    final c = cabin.value;
    if (c == null || c.mode != CabinMode.beltsAsk) return;
    _beltsWarned = false;
    _beltsAgain = -1;
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
  }

  static const beltsMoney = 600, beltsPoints = 400;

  /// Les ceintures n'ont pas été mises : un passager tombe, l'avion est secoué,
  /// et il faut payer (argent ou points) pour le soigner et boucler tout le monde.
  void _passengerFalls() {
    _beltsWarned = false;
    _beltsAgain = -1;
    if (passengers > 0) passengers -= 1;
    _turbulence = math.max(_turbulence, 6);
    shake = 0.8;
    condition = math.max(0, condition - _hurt(8));
    onBuzz?.call(500, 255);
    HapticFeedback.heavyImpact();
    _float('Un passager est tombé !', _w * 0.5, _h * 0.36, const Color(0xFFFF7A7A));
    _cabinT = 0;
    _beltsDeadline = t + 10;
    cabin.value = CabinHud(
      CabinMode.beltsPay,
      0,
      passengers,
      'Un passager est tombé !',
      'Paie ses soins et boucle les ceintures : ${_fmt(beltsMoney)} ${currencyAt(year)} ou $beltsPoints points',
    );
  }

  /// Payer avec l'argent ([withMoney]) ou avec les points ; faux s'il n'y en a pas assez.
  bool payBelts(bool withMoney) {
    final c = cabin.value;
    if (c == null || c.mode != CabinMode.beltsPay) return false;
    if (withMoney) {
      if (money < beltsMoney) return false;
      money -= beltsMoney;
      _keepMoney();
      _float('−${_fmt(beltsMoney)} ${currencyAt(year)}', planeX, planeY - planeLength * 0.3, const Color(0xFFFF8A8A));
    } else {
      if (score < beltsPoints) return false;
      score -= beltsPoints;
      _float('−$beltsPoints points', planeX, planeY - planeLength * 0.3, const Color(0xFFFF8A8A));
    }
    onSound?.call('ceinture');
    _cabinT = 0;
    cabin.value = CabinHud(
      CabinMode.beltsFastening,
      0,
      c.seats,
      'Ceintures bouclées',
      'Le passager est soigné · clic, clic… tout le monde est attaché',
    );
    _pushHud();
    return true;
  }

  void _beltsCrash() {
    cabin.value = null;
    lives = 0;
    _failWhy = 'Passager tombé : ceintures non attachées';
    _clearStage();
    _setPhase(FlightPhase.crashed);
  }

  /// Ceintures pas mises dans les turbulences : des passagers blessés quittent le vol, on les rembourse,
  /// et l'erreur de pilotage coûte aussi du kérosène.
  void _payBelts() {
    if (!_beltPenalty) return;
    _beltPenalty = false;
    final hurt = passengers == 0 ? 0 : math.max(1, math.min(passengers, (passengers * 0.12).round()));
    final refund = math.min(money, hurt * 180);
    passengers -= hurt;
    money -= refund;
    fuel = math.max(3, fuel - 15);
    condition = math.max(0, condition - 10);
    shake = 0.7;
    onBuzz?.call(500, 255);
    HapticFeedback.heavyImpact();
    _keepMoney();
    final cur = currencyAt(year);
    _float('−${_fmt(refund)} $cur · −15 % kérosène', planeX, planeY - planeLength * 0.3, const Color(0xFFFF8A8A));
    _queueBanner(
      FlightBanner(
        'Erreur de pilotage : ceintures non attachées',
        '$hurt passager${hurt > 1 ? 's' : ''} blessé${hurt > 1 ? 's quittent' : ' quitte'} le vol · remboursé ${_fmt(refund)} $cur · kérosène −15 %',
        color: const Color(0xFFFF7A7A),
      ),
      first: true,
    );
  }

  void _updateMaint(double dt) {
    if (_maintT < 0) return;
    _maintT += dt;
    condition = _maintFrom + (100 - _maintFrom) * math.min(1.0, _maintT / _maintTime);
    if (_maintT >= _maintTime) {
      _maintT = -1;
      condition = 100;
      _float('✓ Entretien fait · avion à 100 %', planeX, planeY - planeLength * 0.3, const Color(0xFF8FD0FF));
      _queueBanner(
        FlightBanner(
          'Avion entretenu et renforcé pour ta sécurité',
          'État 100 %, réservoir plein · protection ${(armor * 100).round()} % · chaque choc l\'use un peu',
          color: const Color(0xFF8FD0FF),
        ),
        first: true,
      );
    }
  }

  /// La tour demande le TURBO dans un ciel dégagé : pas d'obstacle, l'avion file droit.
  void _updateStraight(double dt) {
    if (_straightT < 0) {
      if (_takeoffs > 0 &&
          t >= _nextStraight &&
          _airT > 25 &&
          _zone == null &&
          year >= stormUntil &&
          t > _volcanoUntil &&
          _finaleT < 0 &&
          _cues.length < 2) {
        _straightT = 0;
        _straightHeld = 0;
        _queueBanner(
          const FlightBanner(
            'Ligne droite : TURBO !',
            'Ciel dégagé · maintiens TURBO et garde l\'avion bien droit',
            color: ChachaColors.yellow,
          ),
          first: true,
        );
      }
      return;
    }
    _straightT += dt;
    if (boost && vy.abs() < _h * 0.3) _straightHeld += dt;
    if (_straightT < _straightTime) return;
    _straightT = -1;
    _nextStraight = t + 110 + _rng.nextDouble() * 40;
    if (_straightHeld >= 5) {
      score += 400;
      _confetti();
      _float('+400 points', planeX, planeY - planeLength * 0.3, ChachaColors.yellow);
      _queueBanner(
        const FlightBanner('Ligne droite parfaite', 'TURBO tenu, avion droit · +400 points', color: _peaceGreen),
      );
    } else {
      _queueBanner(
        const FlightBanner('Ligne droite manquée', 'Quand la tour le demande, maintiens TURBO et file droit'),
      );
    }
  }

  /// Une ligne droite est demandée : le bouton TURBO s'allume.
  bool get turboCall => _straightT >= 0;

  void _drawMaint(Canvas canvas) {
    if (_maintT < 0) return;
    final len = planeLength, k = _maintT / _maintTime;
    // Deux passages d'un anneau bleu, de la queue au nez.
    final x = planeX - len * 0.5 + len * ((k * 2) % 1);
    final glow = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0x005AB4FF), Color(0xAA5AB4FF), Color(0x005AB4FF)],
      ).createShader(Rect.fromLTWH(x - 18 * _unit, planeY - len * 0.2, 36 * _unit, len * 0.4));
    canvas.drawRect(Rect.fromLTWH(x - 18 * _unit, planeY - len * 0.2, 36 * _unit, len * 0.4), glow);
    canvas.drawLine(
      Offset(x, planeY - len * 0.17),
      Offset(x, planeY + len * 0.17),
      Paint()
        ..color = const Color(0xFFBFE4FF)
        ..strokeWidth = 2 * _unit,
    );
    // Des étincelles de clé autour de l'avion
    for (var i = 0; i < 5; i++) {
      final a = t * 4 + i * 1.256;
      final p = Offset(planeX + math.cos(a) * len * 0.42, planeY + math.sin(a) * len * 0.14);
      canvas.drawCircle(p, 2.6 * _unit, Paint()..color = const Color(0xFF8FD0FF));
    }
  }

  void _drawFloats(Canvas canvas) {
    for (final f in _floats) {
      final a = (f.$4 / 0.5).clamp(0.0, 1.0);
      final at = Offset(f.$2 - f.$1.width / 2, f.$3);
      if (a >= 1) {
        f.$1.paint(canvas, at);
        continue;
      }
      canvas.saveLayer((at & f.$1.size).inflate(6), Paint()..color = Color.fromRGBO(0, 0, 0, a));
      f.$1.paint(canvas, at);
      canvas.restore();
    }
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

  /// L'avion de la compagnie s'il vole encore cette année-là, sinon celui de l'époque le plus proche en taille.
  AircraftType _planeFor(AirlineEra a) {
    final flag = aircraftById(a.flagship);
    if (flag.fliesIn(year)) return flag;
    final open = aircraftTypes.where((x) => x.fliesIn(year)).toList();
    if (open.isEmpty) return type;
    open.sort((x, y) => (x.seats - type.seats).abs().compareTo((y.seats - type.seats).abs()));
    return open.first;
  }

  void _changeAircraft(AircraftType t) {
    type = t;
    passengers = math.min(passengers, t.seats);
    flash = 0.5;
    // Un seul message, qu'on a le temps de lire : l'année, la compagnie, l'avion et ses places.
    _cue(
      () => banner.value = FlightBanner(
        'Nouvel avion · ${t.maker} ${t.name}',
        'En ${year.floor()}, ${_airline.name} vole en ${t.maker} ${t.name} · ${t.seats} places',
        color: ChachaColors.skyLight,
      ),
      8,
      hide: () => banner.value = null,
    );
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
      _addFuel(55);
      score += 150;
      _confetti();
      _song(q.event.song ?? 'chacha');
      _say('Tour de contrôle', Lingala.elonga, 'Bonne réponse ! Ravitaillement en vol : +55 % de kérosène.');
    } else {
      _addFuel(15);
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
    final cp = Checkpoint(y, score, medals, money: money, seconds: _flightT);
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
  /// La crise monte, culmine au milieu de la zone, puis retombe : peu d'avions au début et à la fin.
  int _jetsIn(WarZone z, int k) => 1 + (z.waves * math.sin(math.pi * k / (_wavesOf(z) + 1))).round();

  /// Le cœur de la crise : le tiers du milieu des vagues.
  bool _peakWave(WarZone z, int k) => k > _wavesOf(z) / 3 && k <= _wavesOf(z) * 2 / 3 + 0.5;

  void _checkZone() {
    if (_zone != null || _nextZone >= warZones.length) return;
    final ahead = warZones[_nextZone];
    // La tour prévient de loin : la zone se voit venir, les ceintures s'attachent avant d'y entrer.
    if (_warnedZone < _nextZone + 1 && year >= ahead.from - 0.7 && year < ahead.to) {
      _warnedZone = _nextZone + 1;
      _zoneWarnT = t;
      // L'annonce passe avant tout le reste : elle doit arriver avant la zone. La musique se tait.
      onHush?.call();
      _queueBanner(
        FlightBanner('Zone de turbulence devant', '${ahead.name} · ${ahead.place}', color: _warRed),
        first: true,
      );
      _talk(TalkMoment.war, force: true);
      if (passengers > 0) _askBelts('Zone de guerre droit devant');
    }
    // On entre dans la zone quelques secondes après l'annonce, le temps d'attacher les ceintures.
    if (year < ahead.from || t < _zoneWarnT + 9) return;
    final z = warZones[_nextZone++];
    _zone = z;
    final waves = _wavesOf(z);
    final span = (z.to - z.from) / waves;
    // En reprenant au milieu d'une zone, les vagues déjà passées comptent.
    _wavesCleared = _wave = ((year - z.from) / span).floor().clamp(0, waves - 1);
    year = math.max(year, z.from);
    _zoneT = (year - z.from) / (z.to - z.from) * _zoneBudget(z);
    _exitSaid = false;
    _waveActive = false;
    // La première vague part quand « La guerre arrive » s'affiche (au plus tard 20 s après l'entrée).
    _waveDelay = 20;
    _saveCheckpoint(z.from + span * _wavesCleared);
    shake = 0.35;
    // Repris au milieu d'une zone, ou arrivé sans prévenir : on prévient maintenant.
    if (_warnedZone < _nextZone) {
      _warnedZone = _nextZone;
      if (passengers > 0) _askBelts('Zone de guerre droit devant');
    }
    _stageT = 0;
    onHush?.call();
    _payBelts();
    _queueBanner(FlightBanner('La RDC entre dans la zone', '${z.name} · ${z.place}', color: _warRed), first: true);
    _cue(
      () {
        banner.value = FlightBanner(
          'La guerre arrive',
          'Les avions de chasse sont les jours durs de « ${z.name} » · évite-les pour continuer',
          color: _warRed,
        );
        // On lit l'annonce, on se prépare : les premiers avions arrivent quelques secondes après.
        _waveDelay = math.min(_waveDelay, 5.5);
      },
      7,
      hide: () => banner.value = null,
      first: true,
    );
    // La fiche de la crise suit : la photo et le texte qui l'expliquent.
    if (_nextEvent < historyEvents.length) {
      final e = historyEvents[_nextEvent];
      if (e.war && z.contains(e.year)) {
        _nextEvent++;
        _showCard(e);
      }
    }
  }

  void _updateZone(double dt) {
    final z = _zone!;
    final waves = _wavesOf(z);
    // Les années avancent avec le temps, pas avec les vagues : une zone dure au plus cinq minutes.
    final budget = _zoneBudget(z);
    _zoneT += dt * (boost ? 1.6 : 1);
    year = math.max(year, z.from + (z.to - z.from) * math.min(1, _zoneT / budget));
    if (!_exitSaid && budget - _zoneT < 30) {
      _exitSaid = true;
      _queueBanner(
        FlightBanner('Bientôt ${z.to.floor()}', 'La sortie de la zone approche · encore un effort', color: _peaceGreen),
        first: true,
      );
    }

    if (_waveActive) {
      if (_jets.isEmpty) {
        _waveActive = false;
        _wavesCleared++;
        score += 100 * _wavesCleared;
        _waveDelay = 2.2;
        // Une vague passée : la cabine respire et remercie Dieu (pas à chaque fois).
        if (_wavesCleared.isOdd || _wavesCleared == waves) _talk(TalkMoment.escape, force: _wavesCleared == 1);
        final sub = z.part;
        if (sub != null && _wavesCleared == sub.to) {
          score += 300;
          _confetti();
          _queueBanner(
            FlightBanner(
              '${sub.name} : c\'est fini',
              '${sub.end} · la sécession du Katanga continue, tiens bon',
              color: _peaceGreen,
            ),
            first: true,
          );
        }
      }
    } else {
      _waveDelay -= dt;
      if (_zoneT >= budget) return _exitZone();
      // Les avions de chasse viennent avec « La guerre arrive » ; seul un moment qui attend le joueur
      // (une question, les ceintures) les retient.
      if (_waveDelay > 0 || (_onStage?.hold ?? false)) return;
      // Chaque vague a son moment dans la zone ; les dernières secondes restent calmes.
      if (_wavesCleared < waves && _zoneT >= budget * 0.85 * _wavesCleared / waves) _launchWave();
    }
  }

  void _launchWave() {
    _wave = _wavesCleared + 1;
    _waveActive = true;
    // La louange vient avec les premiers avions de chasse, pas avant.
    if (_wave == _wavesCleared + 1 && _wavesCleared == 0) _comfort();
    final jets = _jetsIn(_zone!, _wave);
    final sub = _zone!.part;
    final part = sub != null && _wave >= sub.from && _wave <= sub.to;
    if (sub != null && _wave == sub.from) {
      _cue(
        () => banner.value = FlightBanner(
          'Sud-Kasaï · ${sub.place}',
          'Les avions bleus sont ceux du Sud-Kasaï · passe-les tous et il reviendra',
          color: const Color(0xFF7FB2FF),
        ),
        6,
        hide: () => banner.value = null,
        first: true,
      );
    }
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
      // Certains foncent, d'autres traînent : on ne devine pas le rythme d'avance.
      final pace = const [0.6, 0.8, 1.0, 1.0, 1.15, 1.3][_rng.nextInt(6)];
      _jets.add(
        _Jet(_w + _jetLength, lanes[lane], wait, _unit * (480 + 60 * jets + 140 * _level) * pace, drift, part: part),
      );
    }
    // Dès la deuxième vague, un chasseur s'arrête devant toi et tire ; au cœur de la crise,
    // un hélicoptère de combat se tient au-dessus et tire aussi.
    final lastWait = jets < 3 ? 0.4 : 0.9 + (jets - 3) * 0.7;
    if (_wave >= 2 && !part && (_wave.isEven || _rng.nextDouble() < 0.4)) {
      _jets.add(
        _Jet(
          _w + _jetLength,
          lanes[_rng.nextInt(lanes.length)],
          lastWait + 1.2,
          _unit * 520,
          0,
          shots: 1 + (_wave >= 4 ? _rng.nextInt(_level > 0.5 ? 3 : 2) : 0),
          stopX: _w * (0.68 + _rng.nextDouble() * 0.12),
        ),
      );
    }
    if ((_peakWave(_zone!, _wave) || (_wave >= 3 && _rng.nextDouble() < 0.4)) && !part) {
      _jets.add(
        _Jet(
          _w + _jetLength,
          _h * 0.14,
          lastWait + 2.6,
          _unit * 300,
          0,
          heli: true,
          shots: 1 + _rng.nextInt(2),
          stopX: _w * (0.55 + _rng.nextDouble() * 0.15),
        ),
      );
    }
    // Dès la deuxième vague, des missiles filent vers l'avion entre les avions de chasse.
    if (_wave == (_wavesOf(_zone!) / 3).floor() + 1) {
      _queueBanner(
        const FlightBanner('Le cœur de la crise', 'Les combats redoublent · tiens bon', color: _warRed),
        first: true,
      );
    } else if (_wave == (_wavesOf(_zone!) * 2 / 3).floor() + 1) {
      _queueBanner(
        const FlightBanner(
          'La crise faiblit',
          'Moins d\'avions de chasse · la sortie approche',
          color: ChachaColors.yellow,
        ),
        first: true,
      );
    }
    if (_peakWave(_zone!, _wave)) {
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
    _pushHud();
  }

  void _exitZone() {
    final z = _zone!;
    year = math.max(year, z.to);
    _report('stage', '${z.name} · ${_clock(_stageT)}');
    _stageT = 0;
    _zone = null;
    _waveActive = false;
    lives = math.min(_maxLives, lives + 1);
    score += 500;
    _calmUntil = t + 16;
    _dance = 4;
    flash = 0.5;
    _peace = 7;
    _confetti();
    _saveCheckpoint(z.to);
    _queueBanner(
      FlightBanner(
        '${Lingala.kimia} · ${z.peaceTitle}',
        '« La paix est revenue » · ${z.peaceText}',
        color: _peaceGreen,
      ),
    );
    _talk(TalkMoment.peace, force: true);
    // La guerre finie, la louange laisse la place : « Franc congolais » pour le nouveau Congo, sinon Indépendance.
    if (z.to > 1997 && z.to < 1998) {
      _startFranc();
    } else {
      _song('fond');
    }
    _queueBanner(
      const FlightBanner('Étape de paix', '+1 vie · +500 points · la réconciliation continue', color: _peaceGreen),
    );
    _freeSky();
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
      final next = _planeFor(a);
      if (next != type && phase == FlightPhase.cruising) _changeAircraft(next);
    }
    // L'avion n'est plus en service : on passe une seule fois à un avion de l'époque (jamais au même).
    if (!type.fliesIn(year) && phase == FlightPhase.cruising) {
      final next = _planeFor(a);
      if (next != type) _changeAircraft(next);
    }
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
        if (phase == FlightPhase.cruising && _hits(c.x, c.y, c.r * 0.85)) _stormHit();
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
        condition = math.max(0, condition - _hurt(8));
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

    final fired = <_Jet>[];
    for (final j in _jets) {
      if (j.wait > 0) {
        j.wait -= dt;
        continue;
      }
      if (j.warn > 0) {
        j.warn -= dt;
        continue;
      }
      if (j.hunter) {
        _huntStep(j, dt, move, fired);
      } else {
        j.x -= (j.aimed ? 0 : move) + j.speed * dt;
        j.y += j.drift * dt;
      }
      final reach = _jetLength * (j.missile ? 0.09 : (j.heli ? 0.2 : 0.16));
      if (!j.hit && phase == FlightPhase.cruising && _hits(j.x, j.y, reach)) {
        j.hit = true;
        // Le choc perce le réservoir et coûte des points : on le voit tout de suite, au-dessus de l'avion.
        if (invulnerable <= 0 && _finaleT < 0) {
          final leak = j.missile ? 12.0 : 8.0, cost = j.missile ? 150 : 100;
          fuel = math.max(fuel > 5 ? 5 : fuel, fuel - leak);
          score = math.max(0, score - cost);
          _float(
            '−${leak.round()} % kérosène · −$cost points${j.aimed ? ' · −15 % état' : ''}',
            planeX,
            planeY - 40 * _unit,
            const Color(0xFFFF8A65),
          );
        }
        if (j.aimed) {
          // Le missile d'un chasseur qui te vise abîme l'avion sans te coûter une vie.
          if (invulnerable <= 0 && _finaleT < 0) {
            condition = math.max(0, condition - _hurt(15));
            _wearArmor();
            invulnerable = 1.2;
            shake = 0.4;
            HapticFeedback.mediumImpact();
            _burst(planeX, planeY, 18, const [Color(0xFFFFB04A), Color(0xFFFF3B3B), Colors.white]);
            _pushHud();
          }
        } else {
          _loseLife(j.missile ? 'Missile' : 'Avion de chasse');
        }
      }
    }
    _jets
      ..addAll(fired)
      ..removeWhere((j) => j.x < -_jetLength || j.y < -_h * 0.4);
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
      // Un médaillon d'histoire garde sa vitesse même en TURBO : il faut le temps de le voir et de l'attraper.
      final calm = p.event != null && boost ? move / 1.6 : move;
      p.x -= p.slow ? calm * (p.event != null && !independenceFaces.contains(p.event) ? 0.25 : 0.38) : calm;
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
    // Jamais plus de 260 éclats ou fumées à la fois : au-delà, le téléphone peine pour rien.
    if (_particles.length > 260) _particles.removeRange(0, _particles.length - 260);

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
        final fuelWas = fuel, reserveWas = reserve;
        _addFuel(_portraits.containsKey(e.photo) ? 32 : 15);
        // Lumumba et Kasa-Vubu font aussi un petit entretien de l'avion.
        if (independenceFaces.contains(e)) condition = math.min(100, condition + 15);
        final gain = (fuel - fuelWas).round(), extra = (reserve - reserveWas).round();
        _float(
          [if (gain > 0) '+$gain % kérosène', if (extra > 0) '+$extra % réserve', '+150 FC'].join(' · '),
          planeX,
          math.max(_h * 0.2 + 22 * _unit, planeY - planeLength * 0.5),
          const Color(0xFFFFE27A),
        );
        if (reserve > 0) {
          _float(
            'Réserve : ${reserve.round()} %',
            planeX,
            math.max(_h * 0.2 + 22 * _unit, planeY - planeLength * 0.5) - 22 * _unit,
            Colors.white,
          );
        }
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
      case _PickupKind.star:
        score += 10;
        onSound?.call('etoile');
        _burst(p.x, p.y, 8, const [ChachaColors.yellow, Colors.white], speed: 140, size: 3);
      case _PickupKind.fuel:
        _addFuel(32);
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
        _addFuel(100);
        score += 80;
        _maintT = 0;
        _maintFrom = condition;
        // Chaque kit renforce aussi l'avion : 10 % de dégâts en moins, jusqu'à la moitié.
        armor = math.min(0.5, armor + 0.1);
        invulnerable = math.max(invulnerable, _maintTime + 0.4);
        _burst(p.x, p.y, 24, const [Color(0xFF5AB4FF), Colors.white], speed: 220, size: 4);
        onSound?.call('kit');
        _float(
          'Kit pris · entretien en cours, commandes bloquées un instant…',
          planeX,
          planeY - planeLength * 0.3,
          const Color(0xFF8FD0FF),
        );
    }
    _pushHud();
  }

  /// Ce qui vient ensuite, et dans combien de temps : la sortie de la zone, ou la prochaine étape.
  String _nextStageText() {
    final z = _zone;
    if (z != null) {
      final left = math.max(0, _zoneBudget(z) - _zoneT) / (boost ? 1.6 : 1);
      return 'Sortie en ${z.to.floor()} dans ${_clock(left)}';
    }
    if (_finaleT >= 0) return '';
    if (_nextZone < warZones.length) {
      final n = warZones[_nextZone];
      final left = math.max(0, n.from - year) * _yearSeconds / (boost ? 1.6 : 1);
      return left < 2
          ? 'Prochaine étape : ${n.name} · droit devant'
          : 'Prochaine étape : ${n.name} (${n.from.floor()}) dans ${_clock(left)}';
    }
    final left = math.max(0, _finaleFrom - year) * _yearSeconds / (boost ? 1.6 : 1);
    return 'Arrivée : 30 juin 2027 dans ${_clock(left)}';
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
        return r <= 1 ? r * 820 : 820 + (r - 1) * 520;
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
      refuel: _truckT < 0 ? 0 : _truckStep,
      reserve: reserve,
      flightSeconds: _flightT,
      stageSeconds: _stageT,
      stageName: _zone?.name ?? 'Ciel de paix',
      nextStage: _nextStageText(),
      armor: armor,
      boost: boost && phase == FlightPhase.cruising,
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

  void _render(Canvas canvas) {
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
    if (phase == FlightPhase.crashed || _wrecked) _drawPlaneFire(canvas);
    _drawMaint(canvas);
    _drawTruck(canvas);
    if (phase == FlightPhase.ground) _drawCrew(canvas, behind: false);
    for (final j in _jets) {
      if (j.wait > 0) continue;
      j.warn > 0 ? _drawWarning(canvas, j) : (j.heli ? _drawHeli(canvas, j) : _drawJet(canvas, j));
      // Le chasseur arrêté vise : un cercle rouge clignote sur son nez juste avant le tir.
      if (!j.heli && j.hunter && !j.leaving && j.shots > 0 && j.fireT < 0.6 && (t * 10).floor().isEven) {
        canvas.drawCircle(
          Offset(j.x - _jetLength * 0.45, j.y),
          _jetLength * 0.07,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * _unit
            ..color = const Color(0xFFFF3B3B),
        );
      }
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
          Paint()..color = p.color.withValues(alpha: a * 0.3),
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
    _drawFloats(canvas);
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
          ..strokeWidth = _h * 0.1
          ..color = Color.lerp(
            ChachaColors.red,
            ChachaColors.yellow,
            i / 6,
          )!.withValues(alpha: 0.18 * a * (1 - r / (_w * 0.9))),
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
          ..color = col.withValues(alpha: 0.3 * a),
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
  /// Le chasseur qui s'arrête, ou l'hélicoptère : il cherche ta hauteur, tire, puis s'en va.
  void _huntStep(_Jet j, double dt, double move, List<_Jet> fired) {
    j.age += dt;
    if (j.leaving) {
      // Ses tirs finis, il vire et remonte hors de l'écran : il ne fonce jamais sur toi.
      if (j.heli) {
        j.y -= _h * 0.45 * dt;
        j.x += _w * 0.05 * dt;
      } else {
        j.y -= _h * 0.7 * dt;
        j.x -= _w * 0.1 * dt;
      }
      return;
    }
    if (j.x > j.stopX) {
      j.x = math.max(j.stopX, j.x - (move + j.speed * dt));
    }
    // L'hélicoptère reste au-dessus de toi ; le chasseur se met à ta hauteur, sans jamais être exact.
    final aim = j.heli ? (planeY - _h * 0.3).clamp(_h * 0.1, _h * 0.42) : planeY.clamp(_h * 0.12, _h * 0.88);
    final speed = _h * (j.heli ? 0.18 : 0.3);
    j.vy = ((aim - j.y) * 2).clamp(-speed, speed);
    j.y += j.vy * dt;
    if (j.x > j.stopX + 1) return;
    j.fireT -= dt;
    if (j.fireT <= 0 && j.shots > 0) {
      j.shots--;
      j.fireT = j.heli ? 2.0 : 1.7;
      final from = Offset(j.x - _jetLength * 0.3, j.y + (j.heli ? _jetLength * 0.1 : 0));
      final speedM = _unit * (j.heli ? 320 : 400);
      // Le missile vise là où tu es au moment du tir : il faut bouger pour l'éviter.
      final arrive = math.max(0.6, (from.dx - planeX) / speedM);
      final drift = ((planeY - from.dy) / arrive).clamp(-_h * 0.5, _h * 0.5);
      fired.add(_Jet(from.dx, from.dy, 0, speedM, drift, missile: true, aimed: true)..warn = 0);
      _burst(from.dx, from.dy, 8, const [Color(0xFFFFE0A0), Color(0xFFB0B0B0)], speed: 90, size: 3);
    } else if (j.shots == 0 && j.fireT <= 0.4 || j.age > 14) {
      j.leaving = true;
    }
  }

  /// L'hélicoptère de combat, vu de côté, nez à gauche : le rotor tourne au-dessus.
  void _drawHeli(Canvas canvas, _Jet j) {
    final l = _jetLength * 0.9;
    canvas.save();
    canvas.translate(j.x, j.y);
    canvas.rotate(j.leaving ? -0.12 : 0.08);
    final body = Paint()..color = const Color(0xFF2E3A2A);
    final dark = Paint()..color = const Color(0xFF151C14);
    // Queue et rotor arrière
    canvas.drawRect(Rect.fromLTWH(l * 0.05, -l * 0.04, l * 0.5, l * 0.05), body);
    canvas.drawRect(Rect.fromLTWH(l * 0.52, -l * 0.14, l * 0.04, l * 0.14), dark);
    final spinTail = (math.sin(t * 50) * 0.5 + 0.5) * l * 0.12 + l * 0.02;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(l * 0.56, -l * 0.07), width: spinTail, height: l * 0.12),
      dark..color = const Color(0x88151C14),
    );
    // Cabine
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-l * 0.3, -l * 0.1, l * 0.42, l * 0.18), Radius.circular(l * 0.09)),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-l * 0.3, -l * 0.08, l * 0.13, l * 0.08), Radius.circular(l * 0.04)),
      Paint()..color = const Color(0xFF8FB4C8),
    );
    // Patins et lance-missiles
    final skid = Paint()
      ..color = const Color(0xFF151C14)
      ..strokeWidth = l * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-l * 0.26, l * 0.15), Offset(l * 0.1, l * 0.15), skid);
    canvas.drawLine(Offset(-l * 0.18, l * 0.08), Offset(-l * 0.18, l * 0.15), skid);
    canvas.drawLine(Offset(l * 0.02, l * 0.08), Offset(l * 0.02, l * 0.15), skid);
    canvas.drawRect(Rect.fromLTWH(-l * 0.2, l * 0.06, l * 0.22, l * 0.035), Paint()..color = const Color(0xFF59604F));
    // Mât et grand rotor qui tourne
    canvas.drawRect(Rect.fromLTWH(-l * 0.1, -l * 0.15, l * 0.04, l * 0.06), dark..color = const Color(0xFF151C14));
    final spin = (math.cos(t * 38) * 0.5 + 0.5) * 0.8 + 0.2;
    canvas.drawLine(
      Offset(-l * 0.08 - l * 0.55 * spin, -l * 0.15),
      Offset(-l * 0.08 + l * 0.55 * spin, -l * 0.15),
      Paint()
        ..color = const Color(0xCC151C14)
        ..strokeWidth = l * 0.025
        ..strokeCap = StrokeCap.round,
    );
    // Il vise : une petite lumière rouge clignote juste avant le tir.
    if (!j.leaving && j.shots > 0 && j.fireT < 0.6 && (t * 10).floor().isEven) {
      canvas.drawCircle(Offset(-l * 0.32, l * 0.02), l * 0.03, Paint()..color = const Color(0xFFFF3B3B));
    }
    canvas.restore();
  }

  void _drawMissile(Canvas canvas, _Jet j) {
    final l = _jetLength * 0.42;
    canvas.save();
    canvas.translate(j.x, j.y);
    canvas.rotate(math.atan2(-j.drift, j.speed));
    final flicker = 0.75 + 0.25 * math.sin(t * 70 + j.y);
    canvas.drawOval(
      Rect.fromLTWH(l * 0.42, -l * 0.07, l * 0.7 * flicker, l * 0.14),
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xDDFFC27A), Color(0xAAFFA24A), Color(0x00FFA24A)],
        ).createShader(Rect.fromLTWH(l * 0.42, -l * 0.07, l * 0.7 * flicker, l * 0.14)),
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
    // Un chasseur qui s'en va cabre le nez vers le haut.
    canvas.rotate(j.leaving ? 0.7 : math.atan2(-j.drift, j.speed) * 0.5);
    final bounds = Rect.fromLTRB(-l / 2, -l * 0.25, l / 2, l * 0.2);
    final dark = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: j.part
            ? const [Color(0xFF4F86C6), Color(0xFF1F4A7A), Color(0xFF0B1E36)]
            : const [Color(0xFF3A404C), Color(0xFF14171D), Color(0xFF050608)],
      ).createShader(bounds);

    // Postcombustion
    final flicker = 0.8 + 0.2 * math.sin(t * 60 + j.y);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(l * 0.56, 0), width: l * 0.22 * flicker, height: l * 0.07),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF1B0), Color(0xFFFF8A1E), Color(0x00FF3B00)],
        ).createShader(Rect.fromCenter(center: Offset(l * 0.56, 0), width: l * 0.24, height: l * 0.08)),
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
    if (j.part) {
      // La bande jaune des avions du Sud-Kasaï.
      canvas.drawRect(Rect.fromLTRB(-0.05 * l, -0.045 * l, 0.12 * l, 0.04 * l), Paint()..color = ChachaColors.yellow);
    }
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
    canvas.saveLayer(
      Rect.fromLTWH(-len * 0.1, -len * 0.1, len * 1.2, len * 0.7),
      Paint()..color = const Color(0xD9FFFFFF),
    );
    AircraftPainter.paint(canvas, Size(len, len / 2), tr.type, tr.airline.livery, propPhase: t * 40, blink: t);
    canvas.restore();
    canvas.restore();
    final label = tr.label ??= TextPainter(
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
    // Un dégradé doux plutôt qu'un flou : le même nuage, bien moins de travail pour le téléphone.
    final grey = Color.fromRGBO(70, 80, 105, 0.55 * amount);
    for (var i = 0; i < 9; i++) {
      final x = ((i * 150 * _unit - worldX * 0.5) % (_w + 300 * _unit)) - 150 * _unit;
      final c = Offset(x, top + (i % 3) * 8 * _unit);
      final r = (60 + (i * 23) % 30) * _unit * 1.25;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              grey,
              grey.withValues(alpha: grey.a * 0.6),
              grey.withValues(alpha: 0),
            ],
            stops: const [0, 0.6, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
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
        ..color = Color.fromRGBO(170, 200, 255, 0.35 * _bolt),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * _unit
        ..color = Color.fromRGBO(255, 255, 255, _bolt),
    );
  }

  /// Le feu de l'avion touché à mort : une flamme sur l'aile, une sur la queue,
  /// et le brasier au sol après l'impact. Des flammes dessinées, sans flou : c'est léger.
  void _drawPlaneFire(Canvas canvas) {
    final len = planeLength;
    final c = math.cos(pitch), s = math.sin(pitch);
    Offset along(double k) => Offset(planeX + c * len * k * _facing, planeY + s * len * k);
    final grow = phase == FlightPhase.crashed ? math.min(1.0, phaseTime * 1.5 + 0.3) : 0.7;
    _flame(canvas, along(0.02), len * 0.2 * grow, 0);
    _flame(canvas, along(-0.3), len * 0.14 * grow, 1.7);
    if (_impact || _wrecked) {
      _flame(canvas, Offset(planeX - len * 0.25, planeY + len * 0.12), len * 0.3, 3.1);
      _flame(canvas, Offset(planeX + len * 0.2, planeY + len * 0.14), len * 0.24, 4.4);
    }
  }

  void _flame(Canvas canvas, Offset at, double size, double seed) {
    const colors = [Color(0xE6D7261E), Color(0xF2FF7A1E), Color(0xFFFFD34D), Color(0xFFFFF5C8)];
    for (var i = 0; i < colors.length; i++) {
      final k = 1 - i * 0.22;
      final flick = 1 + 0.18 * math.sin(t * (13 + i * 3) + seed * 5) + 0.08 * math.sin(t * 31 + seed);
      final w = size * 0.55 * k, h = size * 1.25 * k * flick;
      final sway = math.sin(t * 7 + seed + i) * size * 0.12;
      final base = at.translate(0, size * 0.25 - i * size * 0.04);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - w / 2, base.dy)
          ..quadraticBezierTo(base.dx - w * 0.6, base.dy - h * 0.55, base.dx + sway, base.dy - h)
          ..quadraticBezierTo(base.dx + w * 0.6, base.dy - h * 0.55, base.dx + w / 2, base.dy)
          ..quadraticBezierTo(base.dx, base.dy + w * 0.35, base.dx - w / 2, base.dy)
          ..close(),
        Paint()..color = colors[i],
      );
    }
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
