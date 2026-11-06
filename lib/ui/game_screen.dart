import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/aircraft_types.dart';
import '../data/archive.dart';
import '../data/history_events.dart';
import '../game/chacha_game.dart';
import '../game/checkpoint.dart';
import '../game/music.dart';
import '../game/sfx.dart';
import '../game/telemetry.dart';
import 'guide.dart';
import '../painting/flag_painter.dart';
import '../theme/chacha_colors.dart';
import '../app_state.dart';
import 'cockpit_panel.dart';
import 'finale.dart';
import 'glass.dart';
import 'timeline_screen.dart';

/// L'écran de vol : le jeu Flame, avec par-dessus le tableau de bord en verre.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.type, this.resume});

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
    final q = Uri.base.queryParameters;
    return ChachaGame(widget.type)
      ..autopilot = q['demo'] == '1' && q['montrer'] != 'plein'
      ..timeScale = double.tryParse(q['vitesse'] ?? '') ?? 1
      ..startYear = from?.year ?? double.tryParse(q['annee'] ?? '')
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
      ..onFinale = (() => Music.instance.play('chacha', loop: true, level: 0.95))
      ..onSong = ((key, {level, loop = false}) => Music.instance.play(key, level: level, loop: loop))
      ..onSwell = Music.instance.swell
      ..onHush = Music.instance.stop;
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
    Glass.cheap = false;
    _focus.dispose();
    Music.instance.stop();
    super.dispose();
  }

  // Pour les captures : `?montrer=guide` ouvre le guide dès le départ.
  late bool _guide = Uri.base.queryParameters['montrer'] == 'guide';

  /// Le guide met le vol en pause le temps de le lire.
  void _showGuide(bool open) {
    _game.paused = open || _paused;
    if (!_paused) open ? Music.instance.pause() : Music.instance.resume();
    setState(() => _guide = open);
  }

  late bool _paused = Uri.base.queryParameters['montrer'] == 'pause';

  /// Un appel, l'écran qui s'éteint : le vol se met en pause tout seul.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) && !_paused) _pause(true);
  }

  /// La pause : le vol s'arrête, on règle le son, puis on reprend là où on était.
  void _pause(bool on) {
    _game.paused = on;
    on ? Music.instance.pause() : Music.instance.resume();
    if (on) Sfx.instance.still();
    setState(() => _paused = on);
  }

  void _restart(Checkpoint? from) {
    Music.instance.stop();
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
            if (_paused && !_guide)
              Positioned.fill(
                child: _Scaled(
                  child: _PauseView(
                    onResume: () => _pause(false),
                    onGuide: () => _showGuide(true),
                    onHome: () => Navigator.of(context).pop(),
                  ),
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
    final modal = game.meal.value != null || game.quiz.value != null;
    // On découvre le tableau de bord pas à pas : l'année au décollage, les points en montée,
    // les instruments une fois en vol.
    final showYear = p != FlightPhase.ready || !hud.firstFlight;
    final showStatus = p != FlightPhase.ready && p != FlightPhase.rolling;
    final showCockpit =
        !modal && !ended && (p == FlightPhase.cruising || p == FlightPhase.approach || p == FlightPhase.ground);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        padding: const EdgeInsets.all(10),
                        radius: 16,
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        onTap: onPause,
                        padding: const EdgeInsets.all(10),
                        radius: 16,
                        child: const Icon(Icons.pause_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        onTap: onGuide,
                        padding: const EdgeInsets.all(10),
                        radius: 16,
                        child: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      _Reveal(
                        visible: showYear,
                        dim: hud.planeHigh,
                        from: const Offset(-0.3, 0),
                        child: _YearPanel(hud: hud),
                      ),
                    ],
                  ),
                  // La zone de guerre se lit sous l'année, à gauche : elle ne cache jamais un autre panneau.
                  if (flying)
                    ValueListenableBuilder(
                      valueListenable: game.zoneHud,
                      builder: (_, z, _) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: _slide,
                        layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
                        child: z == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: _Reveal(
                                  visible: true,
                                  dim: hud.planeHigh,
                                  from: const Offset(-0.3, 0),
                                  child: _ZonePanel(key: ValueKey(z.zone), zone: z, next: hud.nextStage),
                                ),
                              ),
                      ),
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
                    from: const Offset(0.3, 0),
                    child: _StatusPanel(hud: hud),
                  ),
                  if (!ended && !hud.finale)
                    ValueListenableBuilder(
                      valueListenable: game.mission,
                      builder: (_, m, _) => m == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _MissionChip(mission: m, hud: hud),
                            ),
                    ),
                  if (!ended && !modal)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _StageSlot(game: game),
                    ),
                ],
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
            Center(
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
            if (p == FlightPhase.ready)
              Align(
                alignment: const Alignment(0, -0.3),
                child: _TakeoffPanel(hud: hud, game: game, onRestart: () => onRestart(null)),
              ),
            if (!modal && !hud.finale && (flying || p == FlightPhase.ready || p == FlightPhase.rolling))
              Align(
                alignment: Alignment.bottomRight,
                child: _Controls(game: game, hud: hud),
              ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _Reveal(
                visible: showCockpit,
                dim: hud.planeLow,
                from: const Offset(0, 0.4),
                child: Transform.scale(
                  scale: 0.78,
                  alignment: Alignment.bottomLeft,
                  child: CockpitPanel(hud: hud),
                ),
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
      padding: const EdgeInsets.fromLTRB(12, 7, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 42, height: 28, child: CustomPaint(painter: FlagPainter(hud.flag))),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${hud.year.floor()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                hud.airline,
                style: const TextStyle(color: ChachaColors.yellow, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              if (hud.flightSeconds >= 1) ...[
                const SizedBox(height: 2),
                // Le temps qui passe : tout le vol, et l'étape en cours.
                Text(
                  '⏱ ${_clock(hud.flightSeconds)} · ${hud.inZone ? 'zone' : 'paix'} ${_clock(hud.stageSeconds)}',
                  style: TextStyle(
                    color: hud.inZone ? const Color(0xFFFF9A9A) : Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (hud.nextStage.isNotEmpty && !hud.inZone)
                  Text(
                    hud.nextStage,
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
        ],
      ),
    );
  }
}

/// Un panneau qui entre en glissant quand son moment vient, et s'efface quand l'avion passe derrière.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.visible, required this.from, required this.child, this.dim = false});

  final bool visible, dim;
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
          opacity: !visible ? 0 : (dim ? 0.3 : 1),
          duration: const Duration(milliseconds: 400),
          child: child,
        ),
      ),
    );
  }
}

/// La place unique des messages, sous les points : la tour, les bannières, les moments d'histoire,
/// la fiche de l'avion et la cabine y passent un par un, jamais ensemble.
class _StageSlot extends StatelessWidget {
  const _StageSlot({required this.game});

  final ChachaGame game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    return ListenableBuilder(
      listenable: Listenable.merge([g.cabin, g.radio, g.banner, g.card, g.planeCard]),
      builder: (_, _) {
        final Widget child;
        if (g.cabin.value case final c?) {
          child = _CabinView(key: ValueKey(c.mode), cabin: c, game: g);
        } else if (g.radio.value case final r?) {
          child = _RadioView(key: ValueKey(r), call: r, game: g);
        } else if (g.banner.value case final b?) {
          child = _BannerView(key: ValueKey(b), banner: b);
        } else if (g.card.value case final c?) {
          child = _StoryCardView(key: ValueKey(c), card: c);
        } else if (g.planeCard.value case final pc?) {
          child = _PlaneCardView(key: ValueKey(pc), card: pc);
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
                '${_money(hud.money)} ${hud.currency}',
                style: const TextStyle(
                  color: Color(0xFF9CF0B8),
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              // La monnaie en toutes lettres : on comprend que Z veut dire zaïres.
              Text(
                'argent · ${currencyName(hud.currency)}',
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
                      tint: const Color(0x55F7D618),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text('Acheter le plein · ${call.fuelPrice}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  GlassButton(
                    onTap: game.acceptStopover,
                    tint: const Color(0x557CF0A6),
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
  const _BannerView({super.key, required this.banner});

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

class _StoryCardView extends StatelessWidget {
  const _StoryCardView({super.key, required this.card});

  final StoryCard card;

  @override
  Widget build(BuildContext context) {
    final e = card.event;
    final (label, color) = switch (e.kind) {
      EventKind.glory => ('MOMENT DE GLOIRE', ChachaColors.yellow),
      EventKind.life => ('MOMENT MARQUANT', ChachaColors.skyLight),
      EventKind.obstacle => ('MOMENT DIFFICILE', Color(0xFFFF7A7A)),
      EventKind.memory => ('RECUEILLEMENT', Colors.white),
    };
    final tag = card.label ?? (card.caught ? label : 'MÉDAILLON MANQUÉ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
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
                    style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
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
                      const SizedBox(height: 2),
                      Text(
                        e.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, height: 1.3),
                      ),
                      if (e.song != null) _SongLine(songKey: e.song!),
                    ],
                  ),
                ),
                if (archivePhotos[e.photo] case final ArchivePhoto p when p.visible) ...[
                  const SizedBox(width: 12),
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

class _TakeoffPanel extends StatelessWidget {
  const _TakeoffPanel({required this.hud, required this.game, required this.onRestart});

  final HudState hud;
  final ChachaGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Glass(
      tint: const Color(0x40001A40),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hud.firstFlight ? "LÉOPOLDVILLE · AÉROPORT DE N'DJILI" : 'AÉROPORT · ${hud.airport.toUpperCase()}',
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
          if (hud.firstFlight) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x33F7D618),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66F7D618)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, color: ChachaColors.yellow, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Mission : arriver à Kinshasa le 30 juin 2027',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 4),
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
                        tint: const Color(0x557CF0A6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          'Faire le plein · ${_money(game.fuelBill)} ${hud.currency}',
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
            if (hud.money + hud.score < ChachaGame.fuelPrice * (50 - hud.fuel).clamp(5, 100) && hud.fuel < 50) ...[
              const SizedBox(height: 8),
              Text(
                'Plus assez d\'argent pour le kérosène : il faut recommencer depuis 1960.',
                style: TextStyle(
                  color: const Color(0xFFFF9A9A).withValues(alpha: 0.95),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              GlassButton(
                onTap: onRestart,
                tint: const Color(0x55CE1021),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: const Text('Recommencer en 1960', style: TextStyle(fontSize: 13)),
              ),
            ],
            const SizedBox(height: 8),
          ],
          Text(
            hud.refuel > 0
                ? 'Attends la fin du plein : le camion doit repartir'
                : hud.fuel < 50
                ? 'Fais le plein, puis maintiens TURBO pour décoller'
                : 'Maintiens TURBO pour prendre de la vitesse sur la piste',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 2),
          Text(
            hud.tiltAvailable
                ? 'En vol : incline le téléphone, glisse le doigt ou utilise ▲ ▼'
                : 'En vol : glisse le doigt, ▲ ▼ ou les flèches · espace = TURBO',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
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

/// « Descends » qui bat doucement au-dessus des flèches pendant l'approche.
class _DescendHint extends StatelessWidget {
  const _DescendHint();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 13),
      builder: (_, v, child) => Transform.translate(offset: Offset(0, 4 * math.sin(v * 40)), child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: ChachaColors.yellow, borderRadius: BorderRadius.circular(12)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.south_rounded, color: Color(0xFF2A1600), size: 16),
            SizedBox(width: 4),
            Text(
              'Descends',
              style: TextStyle(color: Color(0xFF2A1600), fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
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
        if (game.canUseReserve) ...[
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
        if (game.canLand) ...[
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
        if (hud.phase == FlightPhase.cruising || hud.phase == FlightPhase.approach) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hud.phase == FlightPhase.approach)
                // À l'approche : on rappelle qu'il faut faire descendre l'avion soi-même.
                const Padding(padding: EdgeInsets.only(bottom: 8), child: _DescendHint()),
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
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                    Text('AIMANT', style: TextStyle(fontSize: 9, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(width: 14),
        // TURBO est un bouton rond, à portée du pouce droit. Il s'allume en jaune quand la tour demande la ligne droite.
        // Gros, et il suffit de garder le pouce dessus : l'avion accélère tant qu'on appuie.
        GlassButton(
          onPressChanged: (down) => game.boost = down,
          radius: 56,
          tint: game.turboCall
              ? const Color(0xCCF7D618)
              : (hud.boost ? const Color(0xCCFF5A3C) : const Color(0x88CE1021)),
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 112,
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 3),
                const Text('TURBO', style: TextStyle(fontSize: 15, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                Text(
                  hud.boost ? 'ça accélère !' : 'maintiens',
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
                zone.active
                    ? 'Vague ${zone.wave} / ${zone.waves} · ${zone.jets} avion${zone.jets > 1 ? 's' : ''}'
                    : 'Makasi ! Vague suivante…',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
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
    final muted = TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - 24, maxWidth: 560),
      child: SingleChildScrollView(
        child: Glass(
          tint: const Color(0x55001433),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Le pilote en photo, avec son nom, et ce qui s'est passé.
              ValueListenableBuilder(
                valueListenable: pilotPhoto,
                builder: (_, photo, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: win ? ChachaColors.yellow : Colors.white54,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: ChachaColors.night,
                        backgroundImage: photo == null ? null : MemoryImage(photo),
                        child: photo == null ? const Icon(Icons.person_rounded, color: Colors.white70, size: 22) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            win ? 'Moment de gloire !' : 'CRASH !',
                            style: TextStyle(
                              color: win ? ChachaColors.yellow : const Color(0xFFFF6B6B),
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: win ? 0 : 1.5,
                            ),
                          ),
                          Text(
                            win
                                ? 'Commandant ${pilotName.value ?? ''} · du 30 juin 1960 au 30 juin 2027'
                                : 'Commandant ${pilotName.value ?? ''}${game.failWhy.isEmpty ? '' : ' · ${game.failWhy}'}',
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${hud.year.floor()} · ⏱ ${_clock(game.flightSeconds)} · ${_points(hud.score)} points',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                earned >= 0
                    ? 'Tu as gagné ${_points(earned)} ${hud.currency}'
                    : 'Tu as dépensé ${_points(-earned)} ${hud.currency}',
                style: TextStyle(
                  color: earned >= 0 ? const Color(0xFF7CF0A6) : const Color(0xFFFF9A9A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hud.score > 0 && hud.score >= bestScore)
                const Text(
                  'Nouveau record !',
                  style: TextStyle(color: ChachaColors.yellow, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              if (win) ...[
                const SizedBox(height: 10),
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
              if (_more) ...[
                const SizedBox(height: 12),
                Text('${hud.medals} médaillons · ${_points(hud.money)} ${hud.currency} en caisse', style: muted),
                Text('Temps de vol enregistré dans le classement des pilotes', style: muted),
                if (!win && checkpoint != null)
                  Text('Tu peux reprendre en ${checkpoint.year.floor()}, là où tu étais.', style: muted),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'TES VOLS · MEILLEUR SCORE ${_points(bestScore)}',
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
                GlassButton(
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => TimelineScreen(caught: {...game.caught}))),
                  tint: const Color(0x557CF0A6),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: const Text('Les dates à retenir'),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (!win && checkpoint != null)
                    GlassButton(
                      onTap: () => onRestart(checkpoint),
                      tint: const Color(0x88CE1021),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      child: Text('Reprendre en ${checkpoint.year.floor()}'),
                    ),
                  GlassButton(
                    onTap: () => onRestart(null),
                    tint: !win && checkpoint != null ? ChachaColors.glassFill : const Color(0x88CE1021),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    child: const Text('Recommencer en 1960'),
                  ),
                  GlassButton(
                    onTap: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    child: const Text('Accueil'),
                  ),
                  GlassButton(
                    onTap: () => setState(() => _more = !_more),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Text(_more ? 'Moins ▴' : 'Détails ▾'),
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
  const _Thumb({required this.photo});

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
          if (photo.isNote)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                photo.asset,
                width: width,
                height: width * 0.5,
                fit: BoxFit.cover,
                cacheWidth: (width * 2.5).round(),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
  const _PlaneCardView({super.key, required this.card});

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
                if (c.mode == CabinMode.beltsAsk) _PulseButton(onTap: game.fastenBelts),
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
              height: 46,
              width: double.infinity,
              child: CustomPaint(painter: _CabinPainter(c.mode, c.progress, c.seats)),
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

/// « Allumer le signal », qui bat comme un voyant tant qu'on n'a pas appuyé.
class _PulseButton extends StatelessWidget {
  const _PulseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 6000),
      builder: (_, v, child) => Transform.scale(scale: 1 + 0.06 * (0.5 + 0.5 * _wave(v * 12)), child: child),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFFB86B), borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'Allumer le signal',
            style: TextStyle(color: Color(0xFF2A1600), fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  static double _wave(double x) => (x % 1) < 0.5 ? (x % 1) * 2 : 2 - (x % 1) * 2;
}

/// Les rangées vues d'en haut : chaque siège passe au vert quand sa ceinture claque,
/// et pendant le repas le chariot avance dans l'allée en laissant un plateau à chaque rangée.
class _CabinPainter extends CustomPainter {
  _CabinPainter(this.mode, this.progress, this.seats);

  final CabinMode mode;
  final double progress;
  final int seats;

  @override
  void paint(Canvas c, Size s) {
    // Le fuselage
    final body = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height / 2));
    c.drawRRect(body, Paint()..color = const Color(0x22FFFFFF));
    final cols = 14;
    final shown = seats.clamp(1, cols * 4);
    final cell = (s.width - 40) / cols;
    final h = (s.height - 10) / 4;
    var i = 0;
    for (var col = 0; col < cols; col++) {
      for (var row = 0; row < 4; row++) {
        final x = 26 + col * cell;
        // L'allée au milieu : deux sièges de chaque côté
        final y = 3 + row * h + (row >= 2 ? 4 : 0);
        final r = Rect.fromLTWH(x, y, cell * 0.72, h * 0.78);
        final occupied = i < shown;
        i++;
        if (!occupied) {
          c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), Paint()..color = const Color(0x22FFFFFF));
          continue;
        }
        final order = col / cols;
        var color = const Color(0xFFB9C7DA);
        var scale = 1.0;
        switch (mode) {
          case CabinMode.beltsAsk:
          case CabinMode.beltsPay:
            color = const Color(0xFFFFB86B);
          case CabinMode.beltsFastening:
          case CabinMode.beltsDone:
            final k = ((progress - order * 0.8) * 5).clamp(0.0, 1.0);
            color = Color.lerp(const Color(0xFFFFB86B), const Color(0xFF7CF0A6), k)!;
            // Le « clic » : le siège grossit un instant quand la boucle se ferme.
            scale = 1 + 0.35 * (k > 0 && k < 1 ? 1 - (k - 0.5).abs() * 2 : 0);
          case CabinMode.serving:
          case CabinMode.served:
            color = const Color(0xFFB9C7DA);
        }
        final rr = Rect.fromCenter(center: r.center, width: r.width * scale, height: r.height * scale);
        c.drawRRect(RRect.fromRectAndRadius(rr, const Radius.circular(2.5)), Paint()..color = color);
        if (mode == CabinMode.beltsFastening || mode == CabinMode.beltsDone) {
          final k = ((progress - order * 0.8) * 5).clamp(0.0, 1.0);
          if (k > 0.5) {
            c.drawLine(
              Offset(rr.left + 1, rr.center.dy),
              Offset(rr.right - 1, rr.center.dy),
              Paint()
                ..color = const Color(0xFF1C3B2A)
                ..strokeWidth = 1.4,
            );
          }
        }
        if ((mode == CabinMode.serving || mode == CabinMode.served) && order < progress) {
          // Un plateau : l'assiette et la bouteille
          c.drawCircle(rr.center.translate(-1.5, 0), rr.height * 0.28, Paint()..color = Colors.white);
          c.drawRect(
            Rect.fromCenter(center: rr.center.translate(rr.width * 0.3, 0), width: 2, height: rr.height * 0.6),
            Paint()..color = const Color(0xFF8A4B1E),
          );
        }
      }
    }
    if (mode == CabinMode.serving) {
      // Le chariot dans l'allée
      final x = 26 + progress * (s.width - 52);
      final cart = Rect.fromCenter(center: Offset(x, s.height / 2 + 2), width: 18, height: 7);
      c.drawRRect(RRect.fromRectAndRadius(cart, const Radius.circular(2)), Paint()..color = ChachaColors.yellow);
      for (var k = 0; k < 3; k++) {
        c.drawRect(Rect.fromLTWH(cart.left + 3 + k * 5, cart.top - 4, 2, 4), Paint()..color = const Color(0xFF8A4B1E));
      }
    }
    // Le poste de pilotage, à l'avant
    c.drawCircle(Offset(s.width - 8, s.height / 2), 5, Paint()..color = const Color(0x66FFFFFF));
  }

  @override
  bool shouldRepaint(_CabinPainter old) => old.progress != progress || old.mode != mode || old.seats != seats;
}

/// Le menu du repas : le pilote compose le plateau, puis on sert.
class _MealView extends StatefulWidget {
  const _MealView({super.key, required this.offer, required this.game});

  final MealOffer offer;
  final ChachaGame game;

  @override
  State<_MealView> createState() => _MealViewState();
}

class _MealViewState extends State<_MealView> {
  String _base = mealBases.first, _dish = mealDishes.first;

  /// Les boissons chargées sur le chariot : plusieurs à la fois.
  final _drinks = <String>{'Primus', 'Fanta'};

  Widget _drinkChips(List<String> items) => _chips(items, '', (v) {
    if (!_drinks.remove(v)) _drinks.add(v);
  }, drinks: true);

  Widget _chips(List<String> items, String selected, void Function(String) pick, {bool drinks = false}) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final it in items)
        GestureDetector(
          onTap: () => setState(() => pick(it)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: it == selected || (drinks && _drinks.contains(it))
                  ? const Color(0x55F7D618)
                  : const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: it == selected || (drinks && _drinks.contains(it))
                    ? ChachaColors.yellow
                    : const Color(0x33FFFFFF),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (drinks) ...[
                  SizedBox(width: 7, height: 16, child: CustomPaint(painter: _BottlePainter(_bottleColor(it)))),
                  const SizedBox(width: 5),
                ],
                Text(
                  it,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  static Color _bottleColor(String drink) => switch (drink) {
    'Fanta' => const Color(0xFFFF8A1E),
    'Coca-Cola' => const Color(0xFF7A1010),
    'Vitalo' => const Color(0xFFE8C21A),
    'Eau' => const Color(0xFF8FD3FF),
    'Turbo King' => const Color(0xFF2B1A10),
    'Chivas' => const Color(0xFFC8862A),
    'Red Label' => const Color(0xFFB0301E),
    'Jameson' => const Color(0xFF2E6B3A),
    _ => const Color(0xFF8A4B1E),
  };

  @override
  Widget build(BuildContext context) {
    Text label(String t) => Text(
      t,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
    // Sur un petit écran, les choix défilent ; le bouton « Servir » reste toujours visible en bas.
    final maxHeight = MediaQuery.sizeOf(context).height - 40;
    return Glass(
      tint: const Color(0x66001A40),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_rounded, color: ChachaColors.yellow, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'REPAS À BORD · ${widget.offer.passengers} PASSAGERS',
                          style: const TextStyle(
                            color: ChachaColors.yellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Le plat du jour',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Le même plat pour tout le monde ; pour boire, chacun choisit sur le chariot.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    label('ACCOMPAGNEMENT'),
                    const SizedBox(height: 4),
                    _chips(mealBases, _base, (v) => _base = v),
                    const SizedBox(height: 8),
                    label('PLAT'),
                    const SizedBox(height: 4),
                    _chips(mealDishes, _dish, (v) => _dish = v),
                    const SizedBox(height: 8),
                    label('SUR LE CHARIOT · BIÈRES'),
                    const SizedBox(height: 4),
                    _drinkChips(mealBeers),
                    const SizedBox(height: 6),
                    label('SUCRÉS'),
                    const SizedBox(height: 4),
                    _drinkChips(mealSodas),
                    const SizedBox(height: 6),
                    label('LIQUEURS'),
                    const SizedBox(height: 4),
                    _drinkChips(mealSpirits),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$_base et $_dish pour ${widget.offer.passengers} · ${_drinks.length} boisson${_drinks.length > 1 ? 's' : ''} sur le chariot',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GlassButton(
                  onTap: _drinks.isEmpty
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          widget.game.serveMeal(_base, _dish, _drinks.toList());
                        },
                  tint: const Color(0x55CE1021),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.room_service_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Servir', style: TextStyle(fontSize: 15)),
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

/// Une petite bouteille : goulot, épaule, étiquette blanche.
class _BottlePainter extends CustomPainter {
  _BottlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color;
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(w * 0.38, 0)
      ..lineTo(w * 0.62, 0)
      ..lineTo(w * 0.62, h * 0.28)
      ..quadraticBezierTo(w, h * 0.36, w, h * 0.5)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.5)
      ..quadraticBezierTo(0, h * 0.36, w * 0.38, h * 0.28)
      ..close();
    c.drawPath(path, p);
    c.drawRect(Rect.fromLTWH(0, h * 0.58, w, h * 0.22), Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_BottlePainter old) => old.color != color;
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
