import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/aircraft_types.dart';
import '../data/archive.dart';
import '../data/history_events.dart';
import '../data/war_zones.dart';
import '../game/chacha_game.dart';
import '../game/checkpoint.dart';
import '../game/duel.dart';
import '../game/music.dart';
import '../game/sfx.dart';
import '../game/telemetry.dart';
import 'guide.dart';
import '../painting/flag_painter.dart';
import '../theme/chacha_colors.dart';
import '../app_state.dart';
import 'cabin_camera.dart';
import 'cockpit_panel.dart';
import 'duel_overlay.dart';
import 'duel_screen.dart' show markGuideRead;
import 'finale.dart';
import 'glass.dart';
import 'timeline_screen.dart';
import 'window_view.dart';
import 'passenger_art.dart';

/// L'écran de vol : le jeu Flame, avec par-dessus le tableau de bord en verre.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.type, this.resume, this.duel});

  /// Un duel entre amis sur le Wi-Fi : le vol ne s'enregistre pas, et l'écran montre où en sont les autres.
  final DuelNet? duel;

  final AircraftType type;

  /// Reprendre le vol à ce point de reprise plutôt qu'au décollage de 1960.
  final Checkpoint? resume;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late ChachaGame _game = _newGame(widget.resume);

  /// Sur le web, `?demo=1&vitesse=3&annee=1974` lance le pilote automatique (bande-annonce, tests).
  ChachaGame _newGame(Checkpoint? from) {
    final q = ChachaGame.bench.isNotEmpty ? Uri.splitQueryString(ChachaGame.bench) : Uri.base.queryParameters;
    final d = widget.duel;
    final game = ChachaGame(widget.type)
      ..duel = d != null
      ..autopilot = q['demo'] == '1' && q['montrer'] != 'plein'
      ..timeScale = d != null ? 1 : double.tryParse(q['vitesse'] ?? '') ?? 1
      ..startYear = d != null
          ? (d.rules.start > 1960 ? d.rules.start.toDouble() : null)
          : from?.year ?? double.tryParse(q['annee'] ?? '')
      ..warmup = double.tryParse(q['avance'] ?? '') ?? 0
      ..startFuel = double.tryParse(q['kerosene'] ?? '')
      ..startScore = from?.score ?? 0
      ..startMedals = from?.medals ?? 0
      ..startMoney = from?.money
      ..startSeconds = from?.seconds ?? 0
      ..onBuzz = Sfx.instance.buzz
      ..onStill = Sfx.instance.still
      ..resumed = from != null || q['reprise'] == '1'
      ..onSound = Sfx.instance.play
      ..quizNow = q['quiz'] == '1'
      ..showcase = q['montrer']
      // « Indépendance Cha Cha » pour l'arrivée du 30 juin 2027, en boucle pendant la fête ;
      // les chansons des moments quand leur fichier est là.
      ..onFinale = (() => Music.instance.finale())
      ..onSong = ((key, {level, loop = false}) => Music.instance.play(key, level: level, loop: loop))
      ..onSwell = Music.instance.swell
      ..songBusy = (() => Music.instance.busy)
      ..onHush = Music.instance.stop
      ..onSuspense = Sfx.instance.suspense;
    if (d != null) game.duelSeed = d.seed;
    return game;
  }

  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Glass.cheap = true;
    // Au décollage, plus de musique : seulement le vol.
    Music.instance.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseTimer?.cancel();
    // Le duel reste ouvert un instant : le dernier état part avant la fermeture.
    final d = widget.duel;
    if (d != null) Timer(const Duration(milliseconds: 800), d.close);
    Glass.cheap = false;
    _focus.dispose();
    Music.instance.stop();
    Sfx.instance.suspense(false);
    super.dispose();
  }

  // Pour les captures : `?montrer=guide` ouvre le guide dès le départ.
  late bool _guide = Uri.base.queryParameters['montrer'] == 'guide';

  /// Le guide met le vol en pause le temps de le lire.
  void _showGuide(bool open) {
    if (open) markGuideRead();
    _budget(open || _paused);
    _game.paused = open || _paused;
    if (!_paused) open ? Music.instance.pause() : Music.instance.resume();
    if (!_paused) Sfx.instance.holdSuspense(open);
    setState(() => _guide = open);
  }

  late bool _paused = Uri.base.queryParameters['montrer'] == 'pause';

  /// Un appel, l'écran qui s'éteint : le vol se met en pause tout seul.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) && !_paused) _pause(true);
    // Au retour (écran déverrouillé), on redemande le jeu couché et en plein écran.
    if (state == AppLifecycleState.resumed) {
      lockLandscape();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// La pause : le vol s'arrête, on règle le son, puis on reprend là où on était.
  void _pause(bool on) {
    _budget(on || _guide);
    _game.paused = on;
    on ? Music.instance.pause() : Music.instance.resume();
    Sfx.instance.holdSuspense(on);
    if (on) Sfx.instance.still();
    setState(() => _paused = on);
  }

  // ---------------------------------------------------------- duel : la pause coûte du temps

  /// Le duel continue pendant que ton vol attend : une minute de pause en tout, puis le vol reprend tout seul.
  final _pauseLeft = ValueNotifier<int?>(null);
  Timer? _pauseTimer;
  int _pausedFor = 0;
  bool _holding = false;

  void _budget(bool on) {
    if (widget.duel == null || on == _holding) return;
    _holding = on;
    _pauseTimer?.cancel();
    if (!on) {
      _pauseLeft.value = null;
      return;
    }
    _pauseLeft.value = duelPauseBudget - _pausedFor;
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pausedFor++;
      final left = duelPauseBudget - _pausedFor;
      if (left <= 0) {
        _pauseTimer?.cancel();
        _holding = false;
        _pauseLeft.value = null;
        _guide = false;
        _pause(false);
        return;
      }
      _pauseLeft.value = left;
    });
  }

  /// On quitte le duel : s'il n'est pas fini, on s'y arrête, et le résultat part au tableau de bord.
  void _leaveDuel() {
    final d = widget.duel;
    if (d == null) return Navigator.of(context).pop();
    if (!d.me.out && d.outcome == null) {
      d.report(year: _game.hud.value?.year ?? d.me.year, lives: _game.hud.value?.lives ?? 0, state: Pilot.stopped);
    }
    if (d.outcome == null) Telemetry.sendDuel({'kind': 'result', ...d.result()});
    Navigator.of(context).pop();
  }

  void _restart(Checkpoint? from) {
    // Reprendre après un crash : la chanson qui jouait continue. Un nouveau vol repart en silence.
    if (from == null) Music.instance.stop();
    setState(() => _game = _newGame(from));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final down = e is! KeyUpEvent;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      _game.keyY = down ? -1 : 0;
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _game.keyY = down ? 1 : 0;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _game.keyX = down ? -1 : 0;
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _game.keyX = down ? 1 : 0;
    } else if (k == LogicalKeyboardKey.space) {
      _game.boost = down;
    } else if (k == LogicalKeyboardKey.keyP && e is KeyDownEvent) {
      _game.useMagnet();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onPanDown: (d) => _game.touchTarget = d.localPosition,
              onPanUpdate: (d) => _game.touchTarget = d.localPosition,
              onPanEnd: (_) => _game.touchTarget = null,
              onPanCancel: () => _game.touchTarget = null,
              // Le jeu se redessine à chaque image ; les panneaux par-dessus, seulement quand ils changent.
              child: RepaintBoundary(
                child: GameWidget(key: ObjectKey(_game), game: _game),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _game.hud,
              builder: (_, hud, _) => hud == null
                  ? const SizedBox.shrink()
                  : _Scaled(
                      child: _Hud(
                        game: _game,
                        hud: hud,
                        onRestart: _restart,
                        onGuide: () => _showGuide(true),
                        onPause: () => _pause(true),
                      ),
                    ),
            ),
            // Les bulles de la cabine passent devant le tableau de bord : on les lit toujours.
            IgnorePointer(
              child: TalkBubbles(key: ObjectKey(_game), game: _game),
            ),
            IgnorePointer(
              child: TauntBubble(key: ObjectKey(_game), game: _game),
            ),
            if (widget.duel case final d?)
              Positioned.fill(
                child: DuelOverlay(
                  key: ObjectKey(_game),
                  net: d,
                  game: _game,
                  pauseLeft: _pauseLeft,
                  onQuit: _leaveDuel,
                ),
              ),
            if (_paused && !_guide)
              Positioned.fill(
                child: _Scaled(
                  child: _PauseView(onResume: () => _pause(false), onGuide: () => _showGuide(true), onHome: _leaveDuel),
                ),
              ),
            if (_guide)
              Positioned.fill(
                child: _Scaled(child: GuideView(onClose: () => _showGuide(false))),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le tableau de bord garde les mêmes proportions sur un petit téléphone et sur une tablette :
/// tout est dessiné pour un écran de 430 points de haut, puis agrandi ou réduit d'un bloc.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Petit téléphone, grand téléphone ou tablette : le même tableau de bord, à la taille de l'écran.
    // Le tableau de bord est dessiné pour 844 × 390 : on garde au moins cette place, quelle que soit la forme de l'écran.
    final w = math.max(mq.size.width, mq.size.height), h = math.min(mq.size.width, mq.size.height);
    final k = math.min(w / 844, h / 390).clamp(0.6, 3.0);
    final size = mq.size / k;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: mq.copyWith(size: size, padding: mq.padding / k, viewPadding: mq.viewPadding / k),
          child: child,
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.game,
    required this.hud,
    required this.onRestart,
    required this.onGuide,
    required this.onPause,
  });

  final ChachaGame game;
  final HudState hud;
  final void Function(Checkpoint? from) onRestart;
  final VoidCallback onGuide, onPause;

  @override
  Widget build(BuildContext context) {
    final p = hud.phase;
    final flying = p == FlightPhase.cruising || p == FlightPhase.climbing || p == FlightPhase.approach;
    final ended = p == FlightPhase.crashed || p == FlightPhase.finished;
    // Le bilan attend que l'avion ait touché le sol : on voit le crash.
    final showEnd = ended && game.crashShown;
    // Pendant un repas ou une question, le vol attend : rien d'autre ne gêne le panneau.
    final modal = game.meal.value != null || game.quiz.value != null || game.stagePause.value != null;
    // On découvre le tableau de bord pas à pas : l'année au décollage, les points en montée,
    // les instruments une fois en vol.
    // Pendant le bilan, l'année se cache : le panneau du bilan ne passe jamais sur un autre.
    // Pendant une scène (la descente sur le boulevard), le tableau de bord s'efface : on regarde, on lit.
    final scene = hud.scene;
    final showYear = (p != FlightPhase.ready || !hud.firstFlight) && !showEnd && !scene;
    final showStatus = p != FlightPhase.ready && p != FlightPhase.rolling && !scene;
    final showCockpit =
        !modal &&
        !ended &&
        !scene &&
        (p == FlightPhase.cruising || p == FlightPhase.approach || p == FlightPhase.ground);
    return SafeArea(
      child: Padding(
        // Serré à gauche : le milieu de l'écran reste libre pour l'avion.
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassButton(
                        onTap: () => Navigator.of(context).pop(),
                        padding: const EdgeInsets.all(7),
                        radius: 14,
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: hud.quiet ? 0.45 : 1),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 5),
                      GlassButton(
                        onTap: onPause,
                        padding: const EdgeInsets.all(7),
                        radius: 14,
                        child: Icon(
                          Icons.pause_rounded,
                          color: Colors.white.withValues(alpha: hud.quiet ? 0.45 : 1),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 5),
                      GlassButton(
                        onTap: onGuide,
                        padding: const EdgeInsets.all(7),
                        radius: 14,
                        child: Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white.withValues(alpha: hud.quiet ? 0.45 : 1),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Reveal(
                        visible: showYear,
                        dim: hud.planeHigh,
                        faint: hud.quiet,
                        from: const Offset(-0.3, 0),
                        // Pas plus large qu'il ne faut : la prochaine étape se coupe plutôt que d'élargir le panneau.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: _YearPanel(hud: hud),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hud.finale)
              Align(
                alignment: const Alignment(0, -0.58),
                child: FinaleCountdown(hud: hud),
              ),
            Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Reveal(
                    visible: showStatus,
                    faint: hud.quiet,
                    from: const Offset(0.3, 0),
                    child: _StatusPanel(hud: hud),
                  ),
                  if (!ended && !hud.finale && !scene && hud.showMission)
                    ValueListenableBuilder(
                      valueListenable: game.mission,
                      builder: (_, m, _) => m == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _MissionChip(mission: m, hud: hud),
                            ),
                    ),
                  if (!ended && !modal && !scene && p != FlightPhase.ready)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      // La zone de guerre prend la place des annonces quand elles sont passées.
                      child: _StageSlot(game: game, zoneNext: flying ? hud.nextStage : null),
                    ),
                ],
              ),
            ),
            // Les répliques d'une scène : une bulle à la fois, en haut, au milieu.
            if (!ended && flying)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(left: 84, right: 12),
                  child: ValueListenableBuilder(
                    valueListenable: game.sceneLine,
                    builder: (_, line, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
                      ),
                      child: line == null ? const SizedBox.shrink() : _SceneBubble(key: ValueKey(line), line: line),
                    ),
                  ),
                ),
              ),
            if (!modal && !ended && flying)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 46),
                  child: ValueListenableBuilder(
                    valueListenable: game.cabinCamera,
                    builder: (_, shot, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: shot == null
                          ? const SizedBox.shrink()
                          : _SwipeAway(
                              onGone: game.closeCabinCamera,
                              tap: false,
                              child: CabinCameraView(
                                shot: shot,
                                fill: hud.seats == 0 ? 1 : hud.passengers / hud.seats,
                                onClose: game.closeCabinCamera,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            if (!modal && !ended && flying)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 46),
                  child: ValueListenableBuilder(
                    valueListenable: game.windowView,
                    builder: (_, animal, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: animal == null
                          ? const SizedBox.shrink()
                          : WindowView(
                              key: ValueKey(animal),
                              animal: animal,
                              onClose: () => game.windowView.value = null,
                            ),
                    ),
                  ),
                ),
              ),
            if (p == FlightPhase.ground)
              Align(
                alignment: const Alignment(0, -0.25),
                child: ValueListenableBuilder(
                  valueListenable: game.stopover,
                  builder: (_, st, _) => st == null ? const SizedBox.shrink() : _StopoverView(stop: st, game: game),
                ),
              ),
            // À droite : l'avion reste visible à gauche.
            Align(
              alignment: const Alignment(0.85, -0.45),
              child: ValueListenableBuilder(
                valueListenable: game.turningPoint,
                builder: (_, tp, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: _slide,
                  layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
                  child: tp == null ? const SizedBox.shrink() : _TurningPointView(key: ValueKey(tp), point: tp),
                ),
              ),
            ),
            Center(
              child: ValueListenableBuilder(
                valueListenable: game.quiz,
                builder: (_, q, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: _slide,
                  layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
                  child: q == null ? const SizedBox.shrink() : _QuizView(key: ValueKey(q), quiz: q, game: game),
                ),
              ),
            ),
            Center(
              child: ValueListenableBuilder(
                valueListenable: game.meal,
                builder: (_, m, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: _slide,
                  layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
                  child: m == null ? const SizedBox.shrink() : _MealView(key: ValueKey(m), offer: m, game: game),
                ),
              ),
            ),
            // Au sol : le panneau du décollage sous la barre du haut, et les messages juste dessous,
            // chacun à sa place, sans se couvrir.
            if (p == FlightPhase.ready)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 78),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Un message de la tour prend la place du panneau, le temps de le lire : jamais collés.
                      ListenableBuilder(
                        listenable: Listenable.merge([game.radio, game.banner]),
                        builder: (_, _) => game.radio.value != null || game.banner.value != null
                            ? const SizedBox.shrink()
                            : _TakeoffPanel(hud: hud, game: game, onRestart: () => onRestart(null)),
                      ),
                      if (!modal) ...[const SizedBox(height: 8), _StageSlot(game: game)],
                    ],
                  ),
                ),
              ),
            if (!modal &&
                !hud.finale &&
                !scene &&
                !game.stranded &&
                (flying || p == FlightPhase.ready || p == FlightPhase.rolling))
              Align(
                alignment: Alignment.bottomRight,
                child: AnimatedOpacity(
                  opacity: hud.quiet ? 0.6 : 1,
                  duration: const Duration(milliseconds: 400),
                  child: _Controls(game: game, hud: hud),
                ),
              ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _Reveal(
                visible: showCockpit,
                dim: hud.planeLow || hud.quiet,
                from: const Offset(0, 0.4),
                child: Transform.scale(
                  scale: 0.84,
                  alignment: Alignment.bottomLeft,
                  child: CockpitPanel(hud: hud),
                ),
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: game.stagePause,
                builder: (_, pause, _) => pause == null
                    ? const SizedBox.shrink()
                    : pause.tribute != null
                    ? _TributeView(key: ValueKey(pause), event: pause.tribute!, game: game)
                    : _StagePauseView(key: ValueKey(pause), pause: pause, game: game),
              ),
            ),
            if (showEnd && game.homecoming.value)
              Positioned.fill(
                child: FinaleView(
                  game: game,
                  bilan: (_) => Center(
                    child: _EndPanel(hud: hud, game: game, checkpoint: null, onRestart: onRestart),
                  ),
                ),
              )
            else if (showEnd)
              Center(
                child: _EndPanel(hud: hud, game: game, checkpoint: game.checkpoint.value, onRestart: onRestart),
              ),
          ],
        ),
      ),
    );
  }

  /// La fiche avion glisse depuis la droite, comme un avion qui entre dans le hangar.
  static Widget _fromSide(Widget child, Animation<double> a) => SlideTransition(
    position: Tween(
      begin: const Offset(1.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
    child: child,
  );

  // Pas de fondu : un flou de verre dans un fondu blanchit tout l'écran sur le web.
  static Widget _slide(Widget child, Animation<double> a) => ScaleTransition(
    scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, -0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _YearPanel extends StatelessWidget {
  const _YearPanel({required this.hud});

  final HudState hud;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.fromLTRB(9, 5, 12, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 30, height: 20, child: CustomPaint(painter: FlagPainter(hud.flag))),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${hud.year.floor()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  hud.airline,
                  style: const TextStyle(color: ChachaColors.yellow, fontSize: 10, fontWeight: FontWeight.w800),
                ),
                if (hud.phase != FlightPhase.ready)
                  const Text(
                    'Objectif : 30 juin 2027',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                if (hud.flightSeconds >= 1 && hud.phase != FlightPhase.ready) ...[
                  const SizedBox(height: 2),
                  // Le temps qui passe : tout le vol, et l'étape en cours.
                  Text(
                    '⏱ ${_clock(hud.flightSeconds)} · ${hud.inZone ? 'zone' : 'paix'} ${_clock(hud.stageSeconds)}'
                    ' · reste ${((2027.5 - hud.year) / 67 * 100).clamp(0, 100).ceil()} %',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: hud.inZone ? const Color(0xFFFF9A9A) : Colors.white.withValues(alpha: 0.8),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (hud.nextStage.isNotEmpty && !hud.inZone)
                    Text(
                      hud.nextStage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ChachaColors.yellow,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un panneau qui entre en glissant quand son moment vient, et s'efface quand l'avion passe derrière.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.visible, required this.from, required this.child, this.dim = false, this.faint = false});

  final bool visible, dim, faint;
  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : from,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: !visible ? 0 : (dim ? 0.3 : (faint ? 0.4 : 1)),
          duration: const Duration(milliseconds: 400),
          child: child,
        ),
      ),
    );
  }
}

/// La place unique des messages, sous les points : la tour, les bannières, les moments d'histoire,
/// la fiche de l'avion et la cabine y passent un par un, jamais ensemble.
/// Un message en vol : on le touche, ou on le glisse du doigt (de côté ou vers le haut), et il s'en va.
/// Il suit le doigt ; lâché trop tôt, il revient à sa place.
class _SwipeAway extends StatefulWidget {
  const _SwipeAway({super.key, required this.onGone, required this.child, this.tap = true});

  final VoidCallback onGone;
  final Widget child;

  /// Le toucher ferme aussi le message ; la caméra de la cabine garde ses propres boutons.
  final bool tap;

  @override
  State<_SwipeAway> createState() => _SwipeAwayState();
}

class _SwipeAwayState extends State<_SwipeAway> with SingleTickerProviderStateMixin {
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
    ..addListener(() => setState(() => _drag = _from * (1 - _back.value)));
  Offset _drag = Offset.zero, _from = Offset.zero;
  bool _gone = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _end(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (_drag.dx.abs() > 70 || _drag.dy < -40 || v.dx.abs() > 500 || v.dy < -500) {
      _gone = true;
      widget.onGone();
      return;
    }
    _from = _drag;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.tap ? widget.onGone : null,
      onPanStart: (_) => _back.stop(),
      onPanUpdate: (d) => setState(() => _drag = Offset(_drag.dx + d.delta.dx, math.min(0.0, _drag.dy + d.delta.dy))),
      onPanEnd: _end,
      child: Opacity(
        opacity: _gone ? 0 : (1 - _drag.distance / 260).clamp(0.25, 1.0),
        child: Transform.translate(offset: _drag, child: widget.child),
      ),
    );
  }
}

class _StageSlot extends StatelessWidget {
  const _StageSlot({required this.game, this.zoneNext});

  final ChachaGame game;

  /// En vol : la prochaine étape, pour le panneau de la zone de guerre quand aucune annonce n'est là.
  final String? zoneNext;

  @override
  Widget build(BuildContext context) {
    final g = game;
    return ListenableBuilder(
      listenable: Listenable.merge([g.cabin, g.radio, g.banner, g.card, g.planeCard, g.zoneHud]),
      builder: (_, _) {
        final Widget child;
        if (g.cabin.value case final c?) {
          child = _CabinView(key: ValueKey(c.mode), cabin: c, game: g);
        } else if (g.radio.value case final r?) {
          // Avec un choix (le plein, l'escale), la tour attend son bouton ; sinon on la touche et elle s'en va.
          child = r.offer != null
              ? _RadioView(key: ValueKey(r), call: r, game: g)
              : _SwipeAway(
                  key: ValueKey(r),
                  onGone: g.skipMessage,
                  child: _RadioView(call: r, game: g),
                );
        } else if (g.banner.value case final b?) {
          child = _SwipeAway(
            key: ValueKey(b),
            onGone: g.skipMessage,
            child: _BannerView(banner: b),
          );
        } else if (g.card.value case final c?) {
          child = _SwipeAway(
            key: ValueKey(c),
            onGone: g.finishReading,
            child: _StoryCardView(card: c),
          );
        } else if (g.planeCard.value case final pc?) {
          child = _SwipeAway(
            key: ValueKey(pc),
            onGone: g.skipMessage,
            child: _PlaneCardView(card: pc),
          );
        } else if ((g.zoneHud.value, zoneNext) case (final z?, final next?)) {
          child = _ZonePanel(key: ValueKey(z.zone), zone: z, next: next);
        } else {
          child = const SizedBox.shrink();
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: _Hud._fromSide,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topRight, children: [...previous, ?current]),
            child: child,
          ),
        );
      },
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.hud});

  final HudState hud;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < hud.lives.clamp(0, 9); i++)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.favorite_rounded, size: 14, color: ChachaColors.yellow),
            ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${hud.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'points',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0x44FFFFFF),
          ),
          _MiniNote(currency: hud.currency),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hud.money < 0 ? '−${_money(-hud.money)} ${hud.currency}' : '${_money(hud.money)} ${hud.currency}',
                style: TextStyle(
                  color: hud.money < 0 ? const Color(0xFFFF9A9A) : const Color(0xFF9CF0B8),
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              // La monnaie en toutes lettres : on comprend que Z veut dire zaïres. En dette, on le dit.
              Text(
                hud.money < 0 ? 'dette · remboursée en volant' : 'argent · ${currencyName(hud.currency)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// La tour de contrôle parle : lingala en grand, traduction dessous, et le choix de l'escale.
class _RadioView extends StatelessWidget {
  const _RadioView({super.key, required this.call, required this.game});

  final RadioCall call;
  final ChachaGame game;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Glass(
        tint: const Color(0x55001A40),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.headset_mic_rounded, color: ChachaColors.skyLight, size: 16),
                const SizedBox(width: 6),
                Text(
                  call.speaker.toUpperCase(),
                  style: const TextStyle(
                    color: ChachaColors.skyLight,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              call.lingala,
              style: const TextStyle(color: ChachaColors.yellow, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(call.french, style: const TextStyle(color: Colors.white, fontSize: 13)),
            if (call.offer != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (call.fuelPrice != null)
                    GlassButton(
                      onTap: game.buyFuel,
                      tint: const Color(0xDDD9822B),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text('Acheter du kérosène · ${call.fuelPrice}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  GlassButton(
                    onTap: game.acceptStopover,
                    // Descendre est le bon choix quand des passagers attendent : le bouton est rouge.
                    tint: const Color(0xDDCE1021),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flight_land_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('Descendre à ${call.offer}', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  GlassButton(
                    onTap: game.declineStopover,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: const Text('Continuer', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// L'escale : le plein, l'entretien et les contrôles, étape par étape.
class _StopoverView extends StatelessWidget {
  const _StopoverView({required this.stop, required this.game});

  final StopoverHud stop;
  final ChachaGame game;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, double v, Color color) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            v >= 1 ? Icons.check_circle_rounded : icon,
            size: 18,
            color: v >= 1 ? const Color(0xFF7CF0A6) : Colors.white,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
    return Glass(
      tint: const Color(0x55001A40),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESCALE · ${stop.airport.toUpperCase()}',
            style: const TextStyle(
              color: ChachaColors.yellow,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stop.step,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          row(Icons.local_gas_station_rounded, 'Kérosène', stop.fuel, ChachaColors.yellow),
          row(Icons.build_rounded, 'Entretien', stop.repair, const Color(0xFF7CF0A6)),
          row(Icons.fact_check_rounded, 'Contrôles', stop.checks, ChachaColors.skyLight),
          if (stop.boarding != null)
            row(Icons.groups_rounded, stop.boardingLabel, stop.boarding!, const Color(0xFFFFB86B)),
          if (stop.bill.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (noteFor(ChachaGame.landingFee, game.year) case final Banknote n) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.asset(
                      n.asset,
                      width: 44,
                      height: 22,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Icon(Icons.payments_rounded, size: 18, color: Color(0xFF9CF0B8)),
                  const SizedBox(width: 8),
                ],
                Text(
                  stop.bill,
                  style: const TextStyle(color: Color(0xFF9CF0B8), fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
          if (stop.fleet.length > 1 && !stop.rescue) ...[
            const SizedBox(height: 10),
            Text(
              'AVIONS DE L\'ÉPOQUE',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in stop.fleet)
                  GestureDetector(
                    onTap: () => game.changeAircraft(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: t == stop.current ? const Color(0x55F7D618) : const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t == stop.current ? ChachaColors.yellow : const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        '${t.name} · ${t.seats}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerView extends StatelessWidget {
  const _BannerView({required this.banner});

  final FlightBanner banner;

  @override
  Widget build(BuildContext context) {
    return Glass(
      tint: const Color(0x40001A40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            banner.title,
            textAlign: TextAlign.right,
            style: TextStyle(color: banner.color, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          if (banner.typed)
            _Typed(banner.subtitle, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3))
          else
            Text(
              banner.subtitle,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Une réplique d'une scène : la phrase en grand, sa traduction dessous. Pas de nom : la couleur de la bulle
/// et son petit signe disent qui parle (le commandant, la tour, la cabine).
class _SceneBubble extends StatelessWidget {
  const _SceneBubble({super.key, required this.line});

  final SceneLine line;

  @override
  Widget build(BuildContext context) {
    final (Color back, Color ink, Color edge, IconData sign) = switch (line.voice) {
      SceneVoice.pilot => (const Color(0xF20E2A5E), Colors.white, ChachaColors.yellow, Icons.headset_mic_rounded),
      SceneVoice.tower => (const Color(0xF20B3B33), Colors.white, const Color(0xFF6FE08A), Icons.cell_tower_rounded),
      SceneVoice.street => (const Color(0xF2E8A317), const Color(0xFF1B1405), Colors.white, Icons.two_wheeler_rounded),
      SceneVoice.bus => (const Color(0xF22E9BD6), Colors.white, const Color(0xFFF2C230), Icons.airport_shuttle_rounded),
      SceneVoice.police => (const Color(0xF21F2A44), Colors.white, const Color(0xFFFF7A1A), Icons.local_police_rounded),
      SceneVoice.cabin => (
        const Color(0xF7FFFFFF),
        const Color(0xFF14233F),
        const Color(0xFFE0262B),
        Icons.airline_seat_recline_normal_rounded,
      ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 470),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 16, 10),
        decoration: BoxDecoration(
          color: back,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: edge, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: edge, shape: BoxShape.circle),
              child: Icon(sign, size: 18, color: const Color(0xFF0B1B3A)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.text,
                    style: TextStyle(color: ink, fontSize: 17, height: 1.25, fontWeight: FontWeight.w800),
                  ),
                  if (line.french case final fr?)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        fr,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.78),
                          fontSize: 13.5,
                          height: 1.25,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une phrase qui s'écrit lettre après lettre, comme si quelqu'un la disait, derrière un curseur.
class _Typed extends StatefulWidget {
  const _Typed(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_Typed> createState() => _TypedState();
}

class _TypedState extends State<_Typed> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 45 * widget.text.length + 600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final n = (widget.text.length * _c.value).round().clamp(0, widget.text.length);
          final cursor = _c.value < 1 ? '▌' : '';
          // Le reste de la phrase est déjà là, invisible : le bloc garde sa taille pendant qu'elle s'écrit.
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: widget.text.substring(0, n)),
                TextSpan(
                  text: cursor,
                  style: const TextStyle(color: Color(0xFF7CC4F2)),
                ),
                TextSpan(
                  text: widget.text.substring(n),
                  style: const TextStyle(color: Color(0x00000000)),
                ),
              ],
            ),
            textAlign: TextAlign.left,
            style: widget.style,
          );
        },
      ),
    );
  }
}

class _StoryCardView extends StatelessWidget {
  const _StoryCardView({required this.card});

  final StoryCard card;

  @override
  Widget build(BuildContext context) {
    final e = card.event;
    final (label, color) = switch (e.kind) {
      EventKind.glory => ('MOMENT DE GLOIRE', ChachaColors.yellow),
      // « Boyebi ke… » : savez-vous que… Plus parlant que « moment marquant ».
      EventKind.life => (Lingala.boyebiKe, ChachaColors.yellow),
      EventKind.obstacle => ('MOMENT DIFFICILE', Color(0xFFFF7A7A)),
      EventKind.memory => ('RECUEILLEMENT', Colors.white),
    };
    final tag = e.tag ?? card.label ?? (card.caught ? label : 'MÉDAILLON MANQUÉ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Glass(
        tint: const Color(0x4D001433),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: color,
                      fontSize: tag == Lingala.boyebiKe ? 13 : 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${e.date} · ${e.city}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      // Une ligne pour comprendre ; elle remplace la ligne de la chanson, pour garder la fiche petite.
                      if (e.brief != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            e.brief!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.25),
                          ),
                        )
                      else if (e.song != null)
                        _SongLine(songKey: e.song!),
                    ],
                  ),
                ),
                if (archivePhotos[e.photo] case final ArchivePhoto p when p.visible) ...[
                  const SizedBox(width: 12),
                  if (archivePhotos[e.photo2] case final ArchivePhoto p2? when p2.visible)
                    _Slides(photos: [p, p2])
                  else
                    _Thumb(photo: p),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Un hommage : le ciel s'assombrit, la grande photo entre en scène et glisse lentement, l'autre photo lui succède
/// en fondu ; le nom, les années, puis quelques lignes arrivent l'une après l'autre. Il se referme seul, ou d'un toucher.
class _TributeView extends StatefulWidget {
  const _TributeView({super.key, required this.event, required this.game});

  final HistoryEvent event;
  final ChachaGame game;

  @override
  State<_TributeView> createState() => _TributeViewState();
}

class _TributeViewState extends State<_TributeView> with SingleTickerProviderStateMixin {
  static const _photoSeconds = 3.4;
  late final _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (ChachaGame.tributeSeconds * 1000).round()),
  )..forward().whenComplete(_close);
  bool _closing = false;

  List<ArchivePhoto> get _photos => [
    for (final key in [widget.event.photo, widget.event.photo2])
      if (archivePhotos[key] case final ArchivePhoto p when p.visible) p,
  ];

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    if (widget.game.stagePause.value?.tribute == widget.event) widget.game.closePause();
  }

  /// Une étape de l'entrée : 0 avant [from] secondes, 1 après [from] + [length].
  double _step(double from, double length) {
    final s = _clock.value * ChachaGame.tributeSeconds;
    return Curves.easeOutCubic.transform(((s - from) / length).clamp(0.0, 1.0));
  }

  /// La sortie : tout s'efface pendant la dernière demi-seconde.
  double get _out => ((ChachaGame.tributeSeconds - _clock.value * ChachaGame.tributeSeconds) / 0.5).clamp(0.0, 1.0);

  Widget _reveal(double k, Widget child, {double rise = 14}) => Opacity(
    opacity: k,
    child: Transform.translate(offset: Offset(0, rise * (1 - k)), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final photos = _photos;
    final wide = photos.isNotEmpty && photos.every((p) => p.wide);
    const gold = Color(0xFFE9C46A);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: LayoutBuilder(
        builder: (_, box) => AnimatedBuilder(
          animation: _clock,
          builder: (_, _) {
            final s = _clock.value * ChachaGame.tributeSeconds;
            final frameH = math.min(box.maxHeight * 0.8, 360.0);
            final frameW = math.min(frameH * (wide ? 1.35 : 0.78), box.maxWidth * 0.5);
            final shown = photos.isEmpty ? 0 : (s / _photoSeconds).floor() % photos.length;
            // Chaque photo glisse et grossit doucement pendant qu'on la regarde.
            final drift = (s % _photoSeconds) / _photoSeconds;
            final photoIn = _step(0, 0.7);
            return Opacity(
              opacity: _out,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (photos.isNotEmpty)
                        Opacity(
                          opacity: photoIn,
                          child: Transform.translate(
                            offset: Offset(-40 * (1 - photoIn), 0),
                            child: Transform.scale(
                              scale: 1.06 - 0.06 * photoIn,
                              child: Container(
                                width: frameW,
                                height: frameH,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: gold.withValues(alpha: 0.7), width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x99000000), blurRadius: 30, spreadRadius: 2),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 800),
                                  child: Transform.scale(
                                    key: ValueKey(shown),
                                    scale: 1.02 + 0.08 * drift,
                                    alignment: shown.isEven ? Alignment.topLeft : Alignment.bottomRight,
                                    child: Image.asset(
                                      photos[shown].asset,
                                      width: frameW,
                                      height: frameH,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      cacheWidth: (frameW * 2.5).round(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 26),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _reveal(
                                _step(0.6, 0.6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'HOMMAGE',
                                      style: TextStyle(
                                        color: gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(width: 60 * _step(0.8, 0.9), height: 1.5, color: gold),
                                  ],
                                ),
                                rise: 0,
                              ),
                              const SizedBox(height: 6),
                              _reveal(
                                _step(0.9, 0.6),
                                Text(
                                  e.title.replaceFirst(RegExp(r"^Mort (de |d')"), ''),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _reveal(
                                _step(1.25, 0.6),
                                Text(
                                  [?e.lifespan, e.date, e.city].join(' · '),
                                  style: const TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _reveal(
                                _step(1.7, 0.8),
                                Text(
                                  e.text,
                                  maxLines: 7,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _reveal(
                                _step(2.4, 0.6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Le temps qui reste : un fil doré qui se vide.
                                    Container(
                                      width: 120,
                                      height: 2,
                                      alignment: Alignment.centerLeft,
                                      color: Colors.white.withValues(alpha: 0.15),
                                      child: FractionallySizedBox(
                                        widthFactor: 1 - _clock.value,
                                        child: Container(color: gold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Toucher pour continuer',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                rise: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Une étape : le vol s'arrête, les visages, quelques lignes, et on repart.
class _StagePauseView extends StatefulWidget {
  const _StagePauseView({super.key, required this.pause, required this.game});

  final StagePause pause;
  final ChachaGame game;

  @override
  State<_StagePauseView> createState() => _StagePauseViewState();
}

/// L'étape entre en scène : les bords de l'écran s'allument, la fiche monte et se pose. Elle repart de même.
class _StagePauseViewState extends State<_StagePauseView> with TickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 560))..forward();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (widget.pause.war) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _in.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _in.animateBack(0, duration: const Duration(milliseconds: 260));
    if (widget.game.stagePause.value == widget.pause) widget.game.closePause();
  }

  @override
  Widget build(BuildContext context) {
    final pause = widget.pause;
    final color = pause.acclaim ? const Color(0xFF7CF0A6) : (pause.war ? const Color(0xFFFF5A5A) : ChachaColors.yellow);
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _pulse]),
      builder: (_, card) {
        final k = Curves.easeOutCubic.transform(_in.value);
        return Stack(
          children: [
            Opacity(
              opacity: k,
              child: Transform.translate(
                offset: Offset(0, 34 * (1 - k)),
                child: Transform.scale(scale: 0.9 + 0.1 * k, child: card),
              ),
            ),
          ],
        );
      },
      child: _card(color),
    );
  }

  Widget _card(Color color) {
    final pause = widget.pause;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: const Color(0xF20B1B3A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 28, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in pause.people)
              if (archivePhotos[e.photo] case final ArchivePhoto p when p.visible)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(child: Image.asset(p.asset, width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 228)),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 84,
                        child: Text(
                          e.medal ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: ChachaColors.yellow, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        pause.acclaim
                            ? Icons.celebration_rounded
                            : (pause.war ? Icons.warning_amber_rounded : Icons.flag_rounded),
                        color: color,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          pause.kicker,
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.3),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    pause.title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pause.text,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.25),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _close,
                    style: FilledButton.styleFrom(
                      backgroundColor: ChachaColors.yellow,
                      foregroundColor: const Color(0xFF0B1B3A),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeoffPanel extends StatelessWidget {
  const _TakeoffPanel({required this.hud, required this.game, required this.onRestart});

  final HudState hud;
  final ChachaGame game;
  final VoidCallback onRestart;

  /// Plus de quoi payer le kérosène : on montre pourquoi, et seulement le bouton pour recommencer.
  Widget _stranded() {
    const red = Color(0xFFFF9A9A);
    final need = (ChachaGame.fuelPrice * (50 - hud.fuel).clamp(5, 100)).round();
    final has = math.max(0, hud.money) + hud.score;
    return Glass(
      tint: const Color(0x55400008),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AÉROPORT · ${hud.airport.toUpperCase()}',
            style: const TextStyle(
              color: ChachaColors.yellow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${hud.year.floor()} · pas moyen de continuer',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TankGauge(fuel: hud.fuel, filling: false),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Kérosène : ${hud.fuel.round()} % · il en faut au moins 50 % pour décoller',
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Le kérosène manquant coûte ${_money(need)} ${hud.currency}',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Tu as ${_money(math.max(0, hud.money))} ${hud.currency} et ${_money(hud.score)} points · il manque ${_money(math.max(0, need - has))}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Sans argent pour le kérosène, l\'avion ne peut plus partir. Ton voyage s\'arrête en ${hud.year.floor()}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: red.withValues(alpha: 0.95), fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          GlassButton(
            onTap: onRestart,
            tint: const Color(0x55CE1021),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: const Text('Recommencer en 1960', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hud.firstFlight && game.stranded) return _stranded();
    if (game.boarding) {
      return Glass(
        tint: const Color(0x40001A40),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.airline_stops_rounded, color: ChachaColors.yellow, size: 18),
            const SizedBox(width: 8),
            Text(
              hud.firstFlight ? '30 juin 1960 · les passagers montent à bord' : 'Les passagers montent à bord',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }
    return Glass(
      tint: const Color(0x40001A40),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hud.firstFlight
                ? "RÉPUBLIQUE DU CONGO (EX-CONGO BELGE) · LÉOPOLDVILLE, N'DJILI"
                : 'AÉROPORT · ${hud.airport.toUpperCase()}',
            style: const TextStyle(
              color: ChachaColors.yellow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hud.firstFlight
                ? '30 juin 1960 · prêt au décollage'
                : hud.refuel > 0
                ? '${hud.year.floor()} · plein en cours'
                : '${hud.year.floor()} · prêt au décollage',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x33F7D618),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66F7D618)),
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, color: ChachaColors.yellow, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Objectif : arriver à Kinshasa le 30 juin 2027',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    if (hud.firstFlight) ...[const SizedBox(height: 5), const _JourneyLine()],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!hud.firstFlight && (hud.fuel < 99 || hud.refuel > 0)) ...[
            // Après une reprise : le réservoir est presque vide, on paie le plein avant de partir.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TankGauge(fuel: hud.fuel, filling: hud.refuel == 2),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kérosène : ${hud.fuel.round()} %',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    if (hud.refuel == 0)
                      GlassButton(
                        onTap: game.buyFuel,
                        tint: const Color(0xDDCE1021),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          'Acheter du kérosène · ${_money(game.fuelBill)} ${hud.currency}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hud.refuel == 2 ? Icons.local_gas_station_rounded : Icons.local_shipping_rounded,
                            color: ChachaColors.yellow,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            switch (hud.refuel) {
                              1 => 'Le camion-citerne arrive…',
                              2 => 'Plein en cours…',
                              _ => 'Plein terminé · le camion repart',
                            },
                            style: const TextStyle(
                              color: ChachaColors.yellow,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Le prix se lit : le kérosène d'avion coûte cher.
            if (hud.refuel == 0)
              Text(
                '${(100 - hud.fuel).round()} % à ${ChachaGame.fuelPrice} ${hud.currency} le pourcent · tu as ${_money(hud.money)} ${hud.currency} et ${_money(hud.score)} points',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
              ),
            const SizedBox(height: 8),
          ],
          Text(
            hud.refuel > 0
                ? 'Attends la fin du plein : le camion doit repartir'
                : hud.fuel < 50
                ? 'Achète du kérosène, puis maintiens TURBO pour décoller'
                : 'Maintiens TURBO pour prendre de la vitesse sur la piste',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          // Au tout premier vol, la tour explique les commandes une fois en l'air.
          if (!hud.firstFlight) ...[
            const SizedBox(height: 2),
            Text(
              hud.tiltAvailable
                  ? 'En vol : incline le téléphone, glisse le doigt ou utilise ▲ ▼'
                  : 'En vol : glisse le doigt, ▲ ▼ ou les flèches · espace = TURBO',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Le voyage en une ligne : de 1960 à 2027, 67 ans d'histoire à traverser.
class _JourneyLine extends StatelessWidget {
  const _JourneyLine();

  @override
  Widget build(BuildContext context) {
    const year = TextStyle(color: ChachaColors.yellow, fontSize: 11, fontWeight: FontWeight.w900);
    return Row(
      children: [
        const Text('1960', style: year),
        const SizedBox(width: 4),
        const Icon(Icons.flight_rounded, color: Colors.white, size: 13),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: const LinearGradient(colors: [Colors.white, Color(0x33FFFFFF)]),
            ),
          ),
        ),
        Text(
          '67 ans d\'histoire',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: const LinearGradient(colors: [Color(0x33FFFFFF), ChachaColors.yellow]),
            ),
          ),
        ),
        const Text('2027', style: year),
      ],
    );
  }
}

/// Le réservoir de l'avion, dessiné à côté du bouton : il se remplit pendant que le camion pompe.
class _TankGauge extends StatelessWidget {
  const _TankGauge({required this.fuel, required this.filling});

  final double fuel;
  final bool filling;

  @override
  Widget build(BuildContext context) {
    final f = (fuel / 100).clamp(0.0, 1.0);
    final color = fuel < 50 ? const Color(0xFFFF7A7A) : const Color(0xFF7CF0A6);
    return Container(
      width: 30,
      height: 58,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        color: const Color(0x33000000),
        boxShadow: filling ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)] : null,
      ),
      alignment: Alignment.bottomCenter,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 120),
        heightFactor: f,
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.6)],
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(double s) {
  final m = s ~/ 60, r = (s % 60).floor();
  return '$m:${r.toString().padLeft(2, '0')}';
}

class _Controls extends StatelessWidget {
  const _Controls({required this.game, required this.hud});

  final ChachaGame game;
  final HudState hud;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (game.canUseReserve && hud.fuel < 35) ...[
          // La réserve : ce qui a débordé du plein, à verser quand le kérosène manque.
          GlassButton(
            onTap: game.useReserve,
            radius: 20,
            tint: hud.fuel < 15 ? const Color(0x99F7D618) : ChachaColors.glassFill,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 22),
                Text('RÉSERVE ${hud.reserve.round()} %', style: const TextStyle(fontSize: 10, letterSpacing: 0.6)),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (game.landingUseful) ...[
          // Le pilote peut demander l'atterrissage : là où l'attendent ses passagers, sinon au plus proche.
          ValueListenableBuilder(
            valueListenable: game.mission,
            builder: (_, m, _) => GlassButton(
              onTap: game.requestLanding,
              radius: 20,
              tint: m != null ? const Color(0x66F7D618) : ChachaColors.glassFill,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flight_land_rounded, color: Colors.white, size: 22),
                  Text('ATTERRIR', style: TextStyle(fontSize: 10, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (hud.phase == FlightPhase.cruising) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassButton(
                onPressChanged: (down) => game.keyY = down ? -1 : 0,
                radius: 22,
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 8),
              GlassButton(
                onPressChanged: (down) => game.keyY = down ? 1 : 0,
                radius: 22,
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
        if (hud.phase == FlightPhase.cruising)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: hud.magnetReady.clamp(0, 1),
                  strokeWidth: 3,
                  color: ChachaColors.yellow,
                  backgroundColor: const Color(0x22FFFFFF),
                ),
              ),
              GlassButton(
                onTap: game.useMagnet,
                radius: 34,
                padding: const EdgeInsets.all(18),
                // L'aimant : pendant 3 secondes, il attire vers l'avion les médaillons, les bidons et les étoiles.
                // Puis il se recharge en 10 secondes (le cercle jaune se remplit).
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 24, height: 24, child: CustomPaint(painter: _MagnetIcon())),
                    SizedBox(height: 2),
                    Text('AIMANT', style: TextStyle(fontSize: 9, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(width: 14),
        // TURBO est un bouton rond, à portée du pouce droit. Il s'allume en jaune quand la tour demande la ligne droite.
        // Gros, et il suffit de garder le pouce dessus : l'avion accélère tant qu'on appuie.
        _TurboCall(
          on: game.turboWanted,
          child: GlassButton(
            onPressChanged: game.turboPress,
            radius: 56,
            // Vert bien vif quand il est actif ; un appui court le bloque, un autre l'arrête.
            tint: hud.boost
                ? const Color(0xE61DB954)
                : (game.turboCall ? const Color(0xCCF7D618) : const Color(0x88CE1021)),
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 112,
              height: 112,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 26),
                  const SizedBox(height: 1),
                  const Text('TURBO', style: TextStyle(fontSize: 15, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                  Text(
                    game.turboLock
                        ? 'actif · touche\npour arrêter'
                        : (hud.boost ? 'actif · lâche\npour arrêter' : 'touche ou\nmaintiens'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, height: 1.15, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Au sol, TURBO respire doucement pour montrer où appuyer.
class _TurboCall extends StatefulWidget {
  const _TurboCall({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  State<_TurboCall> createState() => _TurboCallState();
}

class _TurboCallState extends State<_TurboCall> with SingleTickerProviderStateMixin {
  late final _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    return AnimatedBuilder(
      animation: _beat,
      builder: (_, child) => Transform.scale(
        scale: 1 + 0.05 * _beat.value,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ChachaColors.yellow.withValues(alpha: 0.25 + 0.55 * _beat.value),
                blurRadius: 12 + 22 * _beat.value,
                spreadRadius: 1 + 7 * _beat.value,
              ),
            ],
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Un aimant en fer à cheval : rouge, avec ses deux pôles argentés.
class _MagnetIcon extends CustomPainter {
  const _MagnetIcon();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final arm = w * 0.26;
    final rect = Rect.fromLTWH(arm / 2, h * 0.12, w - arm, (w - arm) * 0.95);
    final red = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = arm
      ..color = const Color(0xFFE53935);
    // L'arc du bas et les deux bras qui montent
    canvas.drawArc(rect, 0, math.pi, false, red);
    final top = h * 0.14, mid = rect.center.dy;
    canvas.drawLine(Offset(rect.left, mid), Offset(rect.left, top + arm * 0.9), red);
    canvas.drawLine(Offset(rect.right, mid), Offset(rect.right, top + arm * 0.9), red);
    // Les pôles argentés
    final silver = Paint()..color = const Color(0xFFE0E4EA);
    canvas.drawRect(Rect.fromLTWH(rect.left - arm / 2, top - arm * 0.1, arm, arm), silver);
    canvas.drawRect(Rect.fromLTWH(rect.right - arm / 2, top - arm * 0.1, arm, arm), silver);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Pendant une guerre : le nom de la zone, la vague en cours et la traversée des années.
class _ZonePanel extends StatelessWidget {
  const _ZonePanel({super.key, required this.zone, required this.next});

  final ZoneHud zone;
  final String next;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF7A7A);
    final z = zone.zone;
    return Glass(
      tint: const Color(0x55400008),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: red, size: 16),
              const SizedBox(width: 6),
              Text(
                z.name.toUpperCase(),
                style: const TextStyle(color: red, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= zone.waves; i++)
                Container(
                  width: 9,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i < zone.wave || (i == zone.wave && !zone.active && zone.progress >= 1)
                        ? const Color(0xFF7CF0A6)
                        : i == zone.wave
                        ? red
                        : const Color(0x33FFFFFF),
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                zone.active ? 'Vague ${zone.wave} / ${zone.waves}' : 'Ciel libre',
                style: TextStyle(
                  color: zone.active ? Colors.white : const Color(0xFF7CF0A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (next.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                next,
                style: const TextStyle(color: ChachaColors.yellow, fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _gift(IconData icon, String title, String subtitle) => Container(
  padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
  decoration: BoxDecoration(
    color: const Color(0x33F7D618),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0x66F7D618)),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: ChachaColors.yellow, size: 22),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          ),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    ],
  ),
);

class _EndPanel extends StatefulWidget {
  const _EndPanel({required this.hud, required this.game, required this.checkpoint, required this.onRestart});

  final HudState hud;
  final ChachaGame game;
  final Checkpoint? checkpoint;
  final void Function(Checkpoint? from) onRestart;

  @override
  State<_EndPanel> createState() => _EndPanelState();
}

/// Le bilan tient en quelques lignes ; le reste (tes vols, les dates, le détail) s'ouvre avec « Détails ».
class _EndPanelState extends State<_EndPanel> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final hud = widget.hud, game = widget.game, checkpoint = widget.checkpoint, onRestart = widget.onRestart;
    final win = hud.phase == FlightPhase.finished;
    final past = flights.value.take(5).toList();
    final earned = game.moneyEarned;
    // Après un crash, on reprend seulement si la réparation est payée (l'argent n'est pas en dette).
    final canResume = !win && checkpoint != null && checkpoint.money >= 0;
    final broke = !win && checkpoint != null && checkpoint.money < 0;
    final muted = TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5);
    final accent = win ? ChachaColors.yellow : const Color(0xFFFF6B6B);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - 24, maxWidth: 520),
      child: SingleChildScrollView(
        child: Glass(
          tint: const Color(0x99001433),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En tête : le pilote, ce qui s'est passé, et l'accueil dans le coin.
              Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: pilotPhoto,
                    builder: (_, photo, _) => Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.8)),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: ChachaColors.night,
                        backgroundImage: photo == null ? null : MemoryImage(photo),
                        child: photo == null ? const Icon(Icons.person_rounded, color: Colors.white70, size: 24) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          win ? 'Moment de gloire !' : 'Crash',
                          style: TextStyle(color: accent, fontSize: 24, height: 1.05, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          win
                              ? 'Commandant ${pilotName.value ?? ''} · du 30 juin 1960 au 30 juin 2027'
                              : [
                                  'Commandant ${pilotName.value ?? ''}'.trim(),
                                  if (game.failWhy.isNotEmpty) game.failWhy,
                                ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Accueil',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.home_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0)]),
                ),
              ),
              const SizedBox(height: 14),
              // Le bilan en quatre cases égales.
              Row(
                children: [
                  _EndStat('Année', '${hud.year.floor()}'),
                  _EndStat('Temps', _clock(game.flightSeconds)),
                  _EndStat(
                    'Points',
                    _points(hud.score),
                    note: hud.score > 0 && hud.score >= bestScore ? 'record' : null,
                  ),
                  _EndStat(
                    earned >= 0 ? 'Gagné' : 'Dépensé',
                    '${_points(earned.abs())} ${hud.currency}',
                    color: earned >= 0 ? const Color(0xFF7CF0A6) : const Color(0xFFFF9A9A),
                  ),
                ],
              ),
              if (!win && game.repairBill.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: broke ? const Color(0x33FF5A5A) : const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    broke
                        ? '${game.repairBill}\nPas assez d\'argent pour réparer l\'avion : recommence en 1960 et récolte de l\'argent.'
                        : game.repairBill,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: broke ? const Color(0xFFFFB4B4) : Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (win) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _gift(
                      Icons.workspace_premium_rounded,
                      hud.medals >= 30
                          ? 'Badge d\'or'
                          : hud.medals >= 15
                          ? 'Badge d\'argent'
                          : 'Badge de bronze',
                      'Pilote de Dipanda',
                    ),
                    _gift(Icons.school_rounded, 'Diplôme', 'Histoire du Congo 1960 – 2027'),
                    _gift(Icons.flight_rounded, 'Avion offert', 'Tous les avions du hangar'),
                  ],
                ),
                // Un championnat est ouvert : le pilote laisse son numéro pour recevoir le prix s'il gagne.
                ValueListenableBuilder(
                  valueListenable: Telemetry.championship,
                  builder: (_, ch, _) =>
                      ch == null ? const SizedBox.shrink() : _MomoBox(ch, seconds: game.flightSeconds),
                ),
              ],
              const SizedBox(height: 16),
              // Deux boutons, de même largeur : le premier est le bon choix.
              Row(
                children: [
                  Expanded(
                    child: _EndButton(
                      canResume ? 'Reprendre en ${checkpoint.year.floor()}' : 'Recommencer en 1960',
                      icon: canResume ? Icons.play_arrow_rounded : Icons.replay_rounded,
                      primary: true,
                      onTap: () => onRestart(canResume ? checkpoint : null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: canResume
                        ? _EndButton('Recommencer en 1960', icon: Icons.replay_rounded, onTap: () => onRestart(null))
                        : _EndButton('Accueil', icon: Icons.home_rounded, onTap: () => Navigator.of(context).pop()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _more = !_more),
                  child: Text(
                    _more ? 'Moins de détails ▴' : 'Détails du vol ▾',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_more) ...[
                Text(
                  '${hud.medals} médaillons · ${_money(hud.money)} ${hud.currency} en caisse',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                Text(
                  'Temps de vol enregistré dans le classement des pilotes',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                if (canResume)
                  Text(
                    'Tu peux reprendre en ${checkpoint.year.floor()}, là où tu étais.',
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'TES VOLS · MEILLEUR SCORE ${_points(bestScore)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final f in past) _FlightRow(flight: f),
                ],
                const SizedBox(height: 8),
                Center(
                  child: GlassButton(
                    onTap: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => TimelineScreen(caught: {...game.caught}))),
                    tint: const Color(0x557CF0A6),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: const Text('Les dates à retenir'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Une case du bilan : un petit titre, une grande valeur.
class _EndStat extends StatelessWidget {
  const _EndStat(this.label, this.value, {this.color = Colors.white, this.note});

  final String label;
  final String value;
  final Color color;
  final String? note;

  IconData get _icon => switch (label) {
    'Année' => Icons.calendar_month_rounded,
    'Temps' => Icons.timer_rounded,
    'Points' => Icons.star_rounded,
    'Gagné' => Icons.trending_up_rounded,
    _ => Icons.payments_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final tint = note == null ? Colors.white.withValues(alpha: 0.6) : ChachaColors.yellow;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x33FFFFFF), Color(0x12FFFFFF)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: note == null ? const Color(0x22FFFFFF) : const Color(0x99F7D618)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon, size: 12, color: tint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    note == null ? label.toUpperCase() : '${label.toUpperCase()} · ${note!.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tint, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un des deux grands boutons du bilan.
class _EndButton extends StatelessWidget {
  const _EndButton(this.label, {required this.icon, required this.onTap, this.primary = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      onTap: onTap,
      radius: 16,
      tint: primary ? const Color(0xCCCE1021) : const Color(0x33FFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le championnat à la fin d'un vol gagné : le temps du pilote et son numéro Mobile Money pour le prix.
class _MomoBox extends StatefulWidget {
  const _MomoBox(this.championship, {required this.seconds});

  final Championship championship;
  final double seconds;

  @override
  State<_MomoBox> createState() => _MomoBoxState();
}

class _MomoBoxState extends State<_MomoBox> {
  final _field = TextEditingController();
  bool _sending = false, _sent = false, _bad = false;

  @override
  void initState() {
    super.initState();
    Telemetry.savedMomo().then((n) {
      if (n != null && mounted) setState(() => _field.text = n);
    });
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final ok = await Telemetry.sendMomo(_field.text.trim());
    if (mounted) setState(() => (_sending = false, _sent = ok, _bad = !ok));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.championship;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x26F7D618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66F7D618)),
      ),
      child: Column(
        children: [
          Text(
            '🏆 ${c.title}${c.prize.isEmpty ? '' : ' · prix : ${c.prize}'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ChachaColors.yellow, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            c.first
                ? 'Tu es arrivé en 2027 : le premier arrivé gagne.'
                : 'Ton temps de 1960 à 2027 : ${_clock(widget.seconds)}. Le plus rapide gagne.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (_sent)
            const Text(
              '✓ Numéro enregistré : si tu gagnes, le prix t\'arrive par Mobile Money.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7CF0A6), fontSize: 13, fontWeight: FontWeight.w800),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _field,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: 'Ton numéro Mobile Money · ex. 0812345678',
                      errorText: _bad ? 'Numéro non valide, ou pas de réseau' : null,
                      filled: true,
                      fillColor: const Color(0x22FFFFFF),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _send(),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                ),
                const SizedBox(width: 8),
                GlassButton(
                  onTap: _sending ? null : _send,
                  tint: const Color(0x55CE1021),
                  child: Text(_sending ? '…' : 'Envoyer'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _points(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');

/// Une ligne de l'historique : la date, jusqu'où le vol est allé, le score.
class _FlightRow extends StatelessWidget {
  const _FlightRow({required this.flight});

  final FlightRecord flight;

  @override
  Widget build(BuildContext context) {
    final d = flight.date;
    final day = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flight.won ? Icons.flag_rounded : Icons.flight_land_rounded,
            size: 15,
            color: flight.won ? ChachaColors.yellow : Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            '$day · ${flight.won ? 'Arrivé le 30 juin 2027' : 'Arrêté en ${flight.year.floor()}'} · '
            '${_points(flight.score)} pts · ${flight.medals} médaillons',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Une petite photo d'archive, discrète, avec sa légende et sa source.
class _Thumb extends StatelessWidget {
  const _Thumb({super.key, required this.photo});

  final ArchivePhoto photo;
  static const width = 64.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un visage dans un rond doré ; un billet reste un rectangle.
          if (photo.isNote || photo.wide)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ColoredBox(
                color: photo.file.startsWith('logo') ? Colors.white : Colors.transparent,
                child: Image.asset(
                  photo.asset,
                  width: width,
                  height: photo.wide ? width * 0.7 : width * 0.5,
                  fit: photo.file.startsWith('logo') ? BoxFit.contain : BoxFit.cover,
                  cacheWidth: (width * 2.5).round(),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            )
          else
            Container(
              width: width,
              height: width,
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFFF1A8), Color(0xFFE0A100), Color(0xFFFFD34D)]),
              ),
              child: ClipOval(
                child: Image.asset(
                  photo.asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.5),
                  cacheWidth: (width * 2.5).round(),
                  errorBuilder: (_, _, _) => const ColoredBox(color: Color(0x33FFFFFF)),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            photo.credit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

/// Deux photos d'un même moment : elles alternent toutes les quatre secondes, en fondu et avec un léger zoom.
class _Slides extends StatefulWidget {
  const _Slides({required this.photos});

  final List<ArchivePhoto> photos;

  @override
  State<_Slides> createState() => _SlidesState();
}

class _SlidesState extends State<_Slides> {
  late final Timer _timer;
  var _i = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => setState(() => _i = (_i + 1) % widget.photos.length));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 700),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
    ),
    child: _Thumb(key: ValueKey(_i), photo: widget.photos[_i]),
  );
}

/// « ♪ titre — artiste », seulement quand le fichier licencié est dans le jeu.
class _SongLine extends StatelessWidget {
  const _SongLine({required this.songKey});

  final String songKey;

  @override
  Widget build(BuildContext context) {
    final song = momentSongs[songKey];
    if (song == null) return const SizedBox.shrink();
    return FutureBuilder(
      future: Music.instance.isAvailable(songKey),
      builder: (_, snap) => snap.data != true
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '♪ ${song.title} — ${song.artist}',
                style: const TextStyle(color: ChachaColors.yellow, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

/// La fiche de l'avion : nom, constructeur, places, passagers à bord, compagnie.
class _PlaneCardView extends StatelessWidget {
  const _PlaneCardView({required this.card});

  final PlaneCard card;

  @override
  Widget build(BuildContext context) {
    final t = card.type;
    final fill = card.passengers / t.seats;
    return Glass(
      tint: const Color(0x55001A40),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.title.toUpperCase(),
              style: const TextStyle(
                color: ChachaColors.yellow,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
            Text(
              '${t.maker} ${t.name}',
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
            ),
            Text(card.airline, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.airline_seat_recline_normal_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${card.passengers} / ${t.seats} passagers',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fill),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor: const AlwaysStoppedAnimation(ChachaColors.yellow),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'En service ${t.from.floor()} – ${t.to >= 2027 ? 'aujourd\'hui' : t.to.floor()}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// La mission en cours, en haut à droite : d'où, vers où, combien, et les étoiles.
class _MissionChip extends StatelessWidget {
  const _MissionChip({required this.mission, required this.hud});

  final Mission mission;
  final HudState hud;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final y = hud.year;
    return Glass(
      tint: m.why.isNotEmpty && m.boarded ? const Color(0x55400008) : const Color(0x40001A40),
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFFFFB86B), size: 16),
              const SizedBox(width: 6),
              Text(
                m.boarded
                    ? '${m.count} passagers → ${m.to.cityAt(y)}'
                    : '${m.count} passagers attendent à ${m.from.cityAt(y)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ],
          ),
          if (m.boarded)
            Text(
              '${'★' * m.stars}${'☆' * (3 - m.stars)}  ${m.why.isNotEmpty ? m.why : 'Protège tes passagers'}',
              style: TextStyle(
                color: m.why.isNotEmpty ? const Color(0xFFFF9A9A) : ChachaColors.yellow,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// Grand tournant : le drapeau d'avant se transforme en celui d'après (la photo reste sur la fiche du moment).
class _TurningPointView extends StatelessWidget {
  const _TurningPointView({super.key, required this.point});

  final TurningPoint point;

  @override
  Widget build(BuildContext context) {
    final e = point.event;
    return Glass(
      tint: const Color(0x66401000),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 2200),
            curve: Curves.easeInOutCubic,
            builder: (_, v, _) => SizedBox(
              width: 96,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(painter: FlagPainter(point.before)),
                  ),
                  // Le nouveau drapeau monte comme une vague.
                  ClipRect(
                    clipper: _Rise(v),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CustomPaint(painter: FlagPainter(point.after)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'UN GRAND TOURNANT',
                  style: TextStyle(
                    color: ChachaColors.yellow,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  e.title,
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${e.date} · ${e.city}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rise extends CustomClipper<Rect> {
  _Rise(this.v);

  final double v;

  @override
  Rect getClip(Size s) => Rect.fromLTRB(0, s.height * (1 - v), s.width, s.height);

  @override
  bool shouldReclip(_Rise old) => old.v != v;
}

/// Le quiz du kérosène : une question d'histoire, trois réponses.
class _QuizView extends StatelessWidget {
  const _QuizView({super.key, required this.quiz, required this.game});

  final Quiz quiz;
  final ChachaGame game;

  @override
  Widget build(BuildContext context) {
    return Glass(
      tint: const Color(0x66001A40),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_gas_station_rounded, color: ChachaColors.yellow, size: 18),
                SizedBox(width: 6),
                Text(
                  'PLUS DE KÉROSÈNE · RÉPONDS POUR LE PLEIN',
                  style: TextStyle(
                    color: ChachaColors.yellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quiz.question,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < quiz.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      game.answerQuiz(i);
                    },
                    child: Text(quiz.options[i], style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _money(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Un petit billet dessiné, à la couleur de la monnaie de l'époque.
class _MiniNote extends StatelessWidget {
  const _MiniNote({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = switch (currency) {
      'Z' => const Color(0xFF3E9B5B),
      'NZ' => const Color(0xFF7B6FC9),
      _ => const Color(0xFF4FA3D9),
    };
    final painted = Container(
      width: 26,
      height: 15,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        currency,
        style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900),
      ),
    );
    // Le vrai billet de l'époque quand on l'a ; sinon un petit billet dessiné.
    final file = switch (currency) {
      'NZ' => 'billet-1-nouveau-zaire-1993.jpg',
      'FC' => 'billet-1-franc-1997.jpg',
      _ => null,
    };
    if (file == null) return painted;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.asset(
        'assets/notes/$file',
        width: 34,
        height: 17,
        fit: BoxFit.cover,
        cacheWidth: 100,
        errorBuilder: (_, _, _) => painted,
      ),
    );
  }
}

/// La cabine vue d'en haut : les sièges, le signal des ceintures, le chariot du repas.
class _CabinView extends StatelessWidget {
  const _CabinView({super.key, required this.cabin, required this.game});

  final CabinHud cabin;
  final ChachaGame game;

  @override
  Widget build(BuildContext context) {
    final c = cabin;
    final belts = c.mode == CabinMode.beltsAsk || c.mode == CabinMode.beltsFastening || c.mode == CabinMode.beltsDone;
    final done = c.mode == CabinMode.beltsDone || c.mode == CabinMode.served;
    return Glass(
      tint: c.mode == CabinMode.beltsAsk ? const Color(0x55402000) : const Color(0x55001A40),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _BeltSign(lit: c.mode != CabinMode.beltsAsk && belts, meal: !belts),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: TextStyle(
                          color: done ? const Color(0xFF7CF0A6) : ChachaColors.yellow,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        c.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (c.mode == CabinMode.beltsPay) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PayButton(
                      label: 'Payer ${_money(ChachaGame.beltsMoney)} ${game.hud.value?.currency ?? ''}',
                      enabled: game.money >= ChachaGame.beltsMoney,
                      onTap: () => game.payBelts(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PayButton(
                      label: 'Payer ${ChachaGame.beltsPoints} points',
                      enabled: game.score >= ChachaGame.beltsPoints,
                      onTap: () => game.payBelts(false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 128,
              width: double.infinity,
              child: _CabinScene(cabin: c),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFFFB86B) : const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          enabled ? label : '$label · pas assez',
          style: TextStyle(
            color: enabled ? const Color(0xFF2A1600) : Colors.white54,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Le voyant du plafond : une ceinture (ambre quand il faut l'allumer, vert une fois allumé), ou une assiette.
class _BeltSign extends StatelessWidget {
  const _BeltSign({required this.lit, required this.meal});

  final bool lit, meal;

  @override
  Widget build(BuildContext context) {
    final color = meal ? ChachaColors.yellow : (lit ? const Color(0xFF7CF0A6) : const Color(0xFFFFB86B));
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [if (lit || meal) BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
      ),
      child: Icon(meal ? Icons.restaurant_rounded : Icons.airline_seat_recline_normal_rounded, color: color, size: 20),
    );
  }
}

/// La cabine vue de côté : les passagers illustrés à leur place ; celui qui n'est pas attaché tombe.
class _CabinScene extends StatefulWidget {
  const _CabinScene({required this.cabin});

  final CabinHud cabin;

  @override
  State<_CabinScene> createState() => _CabinSceneState();
}

class _CabinSceneState extends State<_CabinScene> {
  static const _people = PassengerKind.values;

  Widget _portrait(PassengerKind kind, double size) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: PassengerPainter(kind)),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final c = widget.cabin;
      final w = box.maxWidth, h = box.maxHeight;
      final cols = math.max(4, (w / 84).floor());
      final cell = w / cols;
      final size = math.min(h * 0.92, cell * 1.12);
      final falling = c.mode == CabinMode.beltsPay;
      final shown = (falling ? c.seats + 1 : c.seats).clamp(1, cols);
      final faller = shown ~/ 2;
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: CustomPaint(painter: _CabinBackPainter(cols))),
            for (var i = 0; i < shown; i++)
              if (!falling || i != faller)
                Positioned(
                  left: cell * (i + 0.5) - size / 2,
                  bottom: -2,
                  child: _portrait(_people[i % _people.length], size),
                ),
            Positioned.fill(child: CustomPaint(painter: _CabinFrontPainter(c, cols, shown, size))),
            if (falling && c.progress < 1)
              // Celui qui n'était pas attaché : secoué vers le haut, puis il bascule dans l'allée.
              Positioned(
                left: cell * (faller + 0.5) - size / 2 + cell * 0.7 * c.progress,
                bottom:
                    -2 +
                    (c.progress < 0.22 ? c.progress * 70 : 15.4 - math.pow((c.progress - 0.22) / 0.78, 2) * h * 1.3),
                child: Transform.rotate(
                  angle: c.progress * 2.5,
                  child: _portrait(_people[faller % _people.length], size),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Le décor : les hublots, les sièges, le sol.
class _CabinBackPainter extends CustomPainter {
  _CabinBackPainter(this.cols);

  final int cols;

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1EADB), Color(0xFFD5CBB6)],
        ).createShader(Offset.zero & s),
    );
    final cell = s.width / cols;
    for (var i = 0; i < cols; i++) {
      final w = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cell * i, s.height * 0.26), width: cell * 0.26, height: s.height * 0.26),
        const Radius.circular(8),
      );
      c.drawRRect(w, Paint()..color = const Color(0xFF7CC4F2));
      c.drawRRect(
        w,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFB8AE98),
      );
    }
    c.drawRect(Rect.fromLTWH(0, s.height * 0.9, s.width, s.height * 0.1), Paint()..color = const Color(0xFF34404F));
    for (var i = 0; i < cols; i++) {
      final seat = Rect.fromCenter(
        center: Offset(cell * (i + 0.5), s.height * 0.62),
        width: cell * 0.8,
        height: s.height * 0.8,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(seat, const Radius.circular(12)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A70BD), Color(0xFF143F75)],
          ).createShader(seat),
      );
    }
  }

  @override
  bool shouldRepaint(_CabinBackPainter old) => old.cols != cols;
}

/// Ce qui passe devant les passagers : les ceintures qui se bouclent, les plateaux, le chariot.
class _CabinFrontPainter extends CustomPainter {
  _CabinFrontPainter(this.cabin, this.cols, this.shown, this.size);

  final CabinHud cabin;
  final int cols, shown;
  final double size;

  @override
  void paint(Canvas c, Size s) {
    final mode = cabin.mode;
    final cell = s.width / cols;
    for (var i = 0; i < shown; i++) {
      final x = cell * (i + 0.5);
      final order = i / cols;
      if (mode == CabinMode.beltsFastening || mode == CabinMode.beltsDone) {
        final k = ((cabin.progress - order * 0.8) * 5).clamp(0.0, 1.0);
        if (k > 0.3) {
          final from = Offset(x - size * 0.34, s.height - size * 0.3);
          final to = Offset(x + size * 0.28, s.height - size * 0.01);
          c.drawLine(
            from,
            Offset.lerp(from, to, k)!,
            Paint()
              ..color = const Color(0xFF20262E)
              ..strokeWidth = size * 0.055,
          );
          if (k >= 1) {
            c.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.lerp(from, to, 0.62)!, width: size * 0.13, height: size * 0.075),
                const Radius.circular(2),
              ),
              Paint()..color = const Color(0xFFC9CED6),
            );
          }
        }
      }
      if ((mode == CabinMode.serving || mode == CabinMode.served) && order < cabin.progress) {
        final tray = Rect.fromCenter(center: Offset(x, s.height * 0.93), width: cell * 0.72, height: s.height * 0.05);
        c.drawRect(tray, Paint()..color = const Color(0xFFC9A36B));
        c.drawOval(
          Rect.fromCenter(center: tray.center.translate(-cell * .1, -3), width: cell * .34, height: 7),
          Paint()..color = Colors.white,
        );
        c.drawRect(
          Rect.fromLTWH(tray.center.dx + cell * .16, tray.top - s.height * .13, 4, s.height * .13),
          Paint()..color = const Color(0xFF7A4418),
        );
      }
    }
    if (mode == CabinMode.serving) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cabin.progress * s.width + size * 0.34, s.height * .58, size * 0.5, s.height * .34),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFB9BEC6),
      );
    }
  }

  @override
  bool shouldRepaint(_CabinFrontPainter old) => old.cabin != cabin || old.shown != shown || old.size != size;
}

/// Le repas à bord : on fait glisser les plats, on en choisit plusieurs, puis les boissons, et on sert.
class _MealView extends StatefulWidget {
  const _MealView({super.key, required this.offer, required this.game});

  final MealOffer offer;
  final ChachaGame game;

  @override
  State<_MealView> createState() => _MealViewState();
}

class _MealViewState extends State<_MealView> {
  final _food = <String>{};
  final _drinks = <String>{'Eau'};
  bool _drinking = false;

  void _toggle(Set<String> set, String v) => setState(() {
    if (!set.remove(v)) set.add(v);
  });

  void _serve() {
    final food = _food.toList();
    widget.game.serveMeal(food.first, food.skip(1).join(', '), _drinks.toList());
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final items = _drinking ? o.drinks : o.food;
    final chosen = _drinking ? _drinks : _food;
    return Glass(
      tint: const Color(0xB3001A40),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${o.number == 1 ? 'REPAS À BORD' : '${o.number}E REPAS À BORD'} · ${o.passengers} PASSAGERS',
              style: const TextStyle(
                color: ChachaColors.yellow,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _drinking
                    ? 'Et pour boire ?'
                    : (o.number == 1
                          ? 'Il est temps de servir vos passagers'
                          : 'C\'est l\'heure du ${o.number == 2 ? 'deuxième' : '${o.number}e'} repas : vos passagers ont faim'),
                key: ValueKey(_drinking),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              _drinking
                  ? 'L\'eau est déjà sur le chariot · fais glisser et ajoute ce que tu veux'
                  : o.short
                  ? 'Aujourd\'hui, on n\'a que ça · touche plusieurs plats pour les choisir'
                  : 'Fais glisser les images · touche plusieurs plats pour les choisir',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: ListView.separated(
                  key: ValueKey(_drinking),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _MealCard(
                    name: items[i],
                    index: i,
                    selected: chosen.contains(items[i]),
                    onTap: () => _toggle(chosen, items[i]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    chosen.isEmpty ? 'Rien de choisi pour le moment' : chosen.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_drinking)
                  GlassButton(
                    onTap: () => setState(() => _drinking = false),
                    tint: const Color(0x33FFFFFF),
                    child: const Text('Retour', style: TextStyle(fontSize: 15)),
                  )
                else if (o.canRefuse)
                  GlassButton(
                    onTap: widget.game.refuseMeal,
                    tint: const Color(0x33FFFFFF),
                    child: const Text('Boko lia te', style: TextStyle(fontSize: 15)),
                  ),
                const SizedBox(width: 8),
                GlassButton(
                  onTap: chosen.isEmpty ? null : (_drinking ? _serve : () => setState(() => _drinking = true)),
                  tint: const Color(0xCCCE1021),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _drinking ? Icons.room_service_rounded : Icons.local_bar_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(_drinking ? 'Servir' : 'À boire', style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Une image du menu : elle arrive en glissant, grossit quand on la choisit.
class _MealCard extends StatelessWidget {
  const _MealCard({required this.name, required this.index, required this.selected, required this.onTap});

  final String name;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = mealPhotos[name]!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + math.min(index, 6) * 70),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.translate(offset: Offset((1 - v) * 40, 0), child: child),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1 : 0.92,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 122,
            decoration: BoxDecoration(
              color: const Color(0xFF0D2547),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? ChachaColors.yellow : const Color(0x33FFFFFF),
                width: selected ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        'assets/meals/$photo',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        cacheWidth: 300,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (selected)
                  const Positioned(
                    top: 5,
                    right: 5,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: ChachaColors.yellow,
                      child: Icon(Icons.check_rounded, size: 16, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La pause : le vol attend ; on règle la musique, les sons et les vibrations.
class _PauseView extends StatelessWidget {
  const _PauseView({required this.onResume, required this.onGuide, required this.onHome});

  final VoidCallback onResume, onGuide, onHome;

  @override
  Widget build(BuildContext context) {
    Widget toggle(ValueNotifier<bool> which, IconData on, IconData off, String label) => ValueListenableBuilder(
      valueListenable: which,
      builder: (_, v, _) => GlassButton(
        onTap: () => saveSwitch(which, !v),
        tint: v ? const Color(0x557CF0A6) : ChachaColors.glassFill,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(v ? on : off, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label : ${v ? 'oui' : 'non'}', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
    return ColoredBox(
      color: const Color(0x99000814),
      child: Center(
        child: Glass(
          tint: const Color(0x88001A40),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_rounded, color: ChachaColors.yellow, size: 34),
              const SizedBox(height: 4),
              const Text(
                'Pause',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              Text(
                'Le vol t\'attend. Reprends quand tu veux.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  toggle(musicOn, Icons.music_note_rounded, Icons.music_off_rounded, 'Musique'),
                  toggle(soundsOn, Icons.volume_up_rounded, Icons.volume_off_rounded, 'Sons'),
                  toggle(vibrationsOn, Icons.vibration_rounded, Icons.mobile_off_rounded, 'Vibrations'),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  GlassButton(
                    onTap: onResume,
                    tint: const Color(0x66CE1021),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 6),
                        Text('Reprendre le vol', style: TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                  GlassButton(
                    onTap: onGuide,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Text('Guide du pilote', style: TextStyle(fontSize: 14)),
                  ),
                  GlassButton(
                    onTap: onHome,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Text('Accueil', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
