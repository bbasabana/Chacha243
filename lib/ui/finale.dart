import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/archive.dart';
import '../data/cabin_talk.dart';
import '../game/chacha_game.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Le mois et l'année d'une année décimale : 2027.2 → (« mars », 2027).
(String, int) monthOf(double year) => (_months[((year - year.floor()) * 12).floor().clamp(0, 11)], year.floor());

// ------------------------------------------------------------ la cabine parle

/// Les répliques sortent de l'avion, l'une après l'autre, comme des bulles de BD.
class TalkBubbles extends StatelessWidget {
  const TalkBubbles({super.key, required this.game});

  final ChachaGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: game.talk,
      builder: (_, talk, _) {
        if (talk == null) return const SizedBox.shrink();
        return ValueListenableBuilder(
          valueListenable: game.hud,
          builder: (context, _, _) {
            final size = MediaQuery.sizeOf(context);
            const width = 260.0;
            // Sur notre avion, ou sur l'autre avion quand c'est son pilote qui parle.
            final at = talk.at?.call() ?? Offset(game.planeX, game.planeY);
            final other = talk.at != null;
            // Au-dessus de l'avion quand il vole bas, en dessous quand il vole haut.
            final above = at.dy > size.height * 0.42;
            final left = (at.dx - (other ? width / 2 : 30))
                .clamp(12.0, math.max(12.0, size.width - width - 12))
                .toDouble();
            final gap = game.planeLength * (other ? 0.12 : 0.22) + 14;
            return Stack(
              children: [
                AnimatedPositioned(
                  key: ObjectKey(talk),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  left: left,
                  width: width,
                  top: above ? null : at.dy + gap,
                  bottom: above ? size.height - at.dy + gap : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    verticalDirection: above ? VerticalDirection.up : VerticalDirection.down,
                    children: [
                      for (var i = 0; i < talk.lines.length; i++)
                        _Bubble(
                          key: ValueKey('${identityHashCode(talk)}-$i'),
                          line: talk.lines[i],
                          delay: i * 1.3,
                          left: i.isOdd,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Une pique en lingala, à côté de l'avion : trois points, puis le message s'écrit comme dans un chat.
class TauntBubble extends StatelessWidget {
  const TauntBubble({super.key, required this.game});

  final ChachaGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: game.taunt,
      builder: (_, taunt, _) {
        if (taunt == null) return const SizedBox.shrink();
        return ValueListenableBuilder(
          valueListenable: game.hud,
          builder: (context, _, _) {
            final size = MediaQuery.sizeOf(context);
            final width = math.min(300.0, size.width * 0.42);
            // Au crash, la parole est seule au milieu de l'écran, avant le bilan.
            if (game.phase == FlightPhase.crashed) {
              if (game.crashShown) return const SizedBox.shrink();
              return Align(
                alignment: const Alignment(0, -0.35),
                child: SizedBox(
                  width: math.min(380.0, size.width * 0.6),
                  child: TauntMessage(key: ObjectKey(taunt), taunt: taunt, big: true),
                ),
              );
            }
            // Juste devant le nez de l'avion ; au-dessus quand il vole bas, en dessous quand il vole haut.
            final above = game.planeY > size.height * 0.45;
            final left = (game.planeX + game.planeLength * 0.2)
                .clamp(12.0, math.max(12.0, size.width - width - 12))
                .toDouble();
            final gap = game.planeLength * 0.14 + 10;
            return Stack(
              children: [
                Positioned(
                  left: left,
                  width: width,
                  top: above ? null : game.planeY + gap,
                  bottom: above ? size.height - game.planeY + gap : null,
                  child: TauntMessage(key: ObjectKey(taunt), taunt: taunt, tailDown: above),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class TauntMessage extends StatefulWidget {
  const TauntMessage({super.key, required this.taunt, this.tailDown = false, this.big = false});

  final Taunt taunt;
  final bool tailDown;

  /// Plus grand, centré : la parole du crash.
  final bool big;

  @override
  State<TauntMessage> createState() => _TauntMessageState();
}

class _TauntMessageState extends State<TauntMessage> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.taunt.seconds * 1000).round()),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.taunt.text;
    const radius = Radius.circular(18);
    return AnimatedBuilder(
      animation: _a,
      builder: (_, _) {
        final s = _a.value * widget.taunt.seconds;
        final pop = Curves.easeOutBack.transform((s / 0.28).clamp(0.0, 1.0));
        final typing = s < Taunt.dots;
        final letters = ((s - Taunt.dots) / Taunt.perLetter).floor().clamp(0, text.length);
        return Align(
          alignment: widget.big ? Alignment.center : Alignment.centerLeft,
          child: Transform.scale(
            scale: 0.6 + 0.4 * pop,
            alignment: widget.tailDown ? Alignment.bottomLeft : Alignment.topLeft,
            child: Opacity(
              opacity: (s / 0.18).clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: widget.tailDown ? radius : const Radius.circular(4),
                    bottomLeft: widget.tailDown ? const Radius.circular(4) : radius,
                    topRight: radius,
                    bottomRight: radius,
                  ),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 4))],
                ),
                child: typing
                    ? TypingDots(phase: s)
                    : Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: text.substring(0, letters)),
                            // Le reste garde sa place : la bulle ne saute pas pendant que le texte s'écrit.
                            TextSpan(
                              text: text.substring(letters),
                              style: const TextStyle(color: Colors.transparent),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: const Color(0xFF0B1B3A),
                          fontSize: widget.big ? 18 : 14.5,
                          height: 1.25,
                          fontWeight: widget.big ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Les trois points qui sautent, comme quand quelqu'un écrit.
class TypingDots extends StatelessWidget {
  const TypingDots({super.key, required this.phase});

  final double phase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(0, -4 * math.max(0, math.sin(phase * 9 - i * 0.9))),
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(color: Color(0xFF8A94A6), shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  const _Bubble({super.key, required this.line, required this.delay, required this.left});

  final TalkLine line;
  final double delay;
  final bool left;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) _a.forward();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  IconData get _icon {
    final s = widget.line.speaker.toLowerCase();
    if (s.contains('hôtesse')) return Icons.support_agent_rounded;
    if (s.contains('commandant') || s.contains('copilote') || s.contains(' vers ')) return Icons.flight_rounded;
    if (s.contains('enfant')) return Icons.child_care_rounded;
    if (s.contains('maman') || s.contains('passagère')) return Icons.face_3_rounded;
    if (s == 'passagers') return Icons.groups_rounded;
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) {
        final v = Curves.easeOutBack.transform(_a.value);
        return Opacity(
          opacity: _a.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(widget.left ? 18 : 0, (1 - v) * 14),
            child: Transform.scale(scale: 0.7 + 0.3 * v, alignment: Alignment.bottomLeft, child: child),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xE60B1E3D),
            borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(4)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 5))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: Color(0x33F7D618), shape: BoxShape.circle),
                child: Icon(_icon, size: 16, color: ChachaColors.yellow),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.speaker.toUpperCase(),
                      style: const TextStyle(
                        color: ChachaColors.yellow,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l.lingala,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (l.french.isNotEmpty)
                      Text(
                        l.french,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ la dernière ligne droite

/// Les mois défilent jusqu'au 30 juin 2027 : le mois en grand, les jours qui restent.
class FinaleCountdown extends StatelessWidget {
  const FinaleCountdown({super.key, required this.hud});

  final HudState hud;

  static const _start = 2026.75, _end = 2027.4945;

  @override
  Widget build(BuildContext context) {
    final (month, year) = monthOf(hud.year);
    final days = math.max(0, ((_end - hud.year) * 365).ceil());
    final k = ((hud.year - _start) / (_end - _start)).clamp(0.0, 1.0);
    // Sur un téléphone couché, le compte à rebours se fait plus petit et passe sous les bandeaux.
    final small = MediaQuery.sizeOf(context).height < 500;
    return Transform.translate(
      offset: Offset(0, small ? 34 : 0),
      child: Transform.scale(scale: small ? 0.82 : 1, child: _box(month, year, days, k)),
    );
  }

  Widget _box(String month, int year, int days, double k) {
    return Glass(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      tint: const Color(0x55001433),
      child: SizedBox(
        width: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, a) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.6),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Text(
                '${month.toUpperCase()} $year',
                key: ValueKey(month),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              days > 0 ? 'J-$days avant le 30 juin 2027' : 'Le 30 juin 2027',
              style: const TextStyle(color: ChachaColors.yellow, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      widthFactor: k,
                      heightFactor: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [ChachaColors.sky, ChachaColors.yellow, ChachaColors.red]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- l'arrivée

/// Posé à N'djili le 30 juin 2027 : les années d'indépendance, le message au pays,
/// les « Vive… », puis le bilan du pilote.
class FinaleView extends StatefulWidget {
  const FinaleView({super.key, required this.game, required this.bilan});

  final ChachaGame game;
  final WidgetBuilder bilan;

  @override
  State<FinaleView> createState() => _FinaleViewState();
}

class _FinaleViewState extends State<FinaleView> with SingleTickerProviderStateMixin {
  // La fête part du moment de l'atterrissage : « ?avance= » permet d'en capturer chaque étape.
  late final _clock = AnimationController(vsync: this, duration: const Duration(minutes: 3))
    ..value = (widget.game.phaseTime / 180).clamp(0.0, 1.0)
    ..forward();
  final _scroll = ScrollController();
  bool _bilan = false;
  int _cheered = -1;

  static const _years = 2027 - 1960;
  static const _titleAt = 2.5, _messageAt = 7.0, _typing = 34.0, _cheerGap = 1.6;
  static const cheers = [
    'Vive le Congo !',
    'Vive l\'indépendance !',
    'Vive le pays de Lumumba !',
    'Vive le pays de Kasa-Vubu !',
  ];

  /// Le message au pays ; ce qui est entre ** s'écrit en gras.
  late final _segments = _parse(
    '**$_years ans** de parcours pour le Congo.\n\n'
    'Le Congo va s\'élever. **Le Congo est un pays fort**, et nos enfants doivent le savoir.\n\n'
    'La puissance d\'un pays ne réside pas seulement dans sa géographie, mais dans la mentalité de sa population '
    'et de sa jeunesse : bâtir un Congo **dans l\'unité et dans l\'amour**, afin qu\'il soit prospère.\n\n'
    'Nos divergences politiques et ethniques doivent être bannies, pour que nous développions le Congo ensemble. '
    '**Nous n\'avons qu\'un seul pays.**\n\n'
    'Merci au pilote **${pilotName.value ?? 'qui nous a conduits'}**${pilotName.value == null ? '' : ' qui nous a conduits'}. '
    'Merci à tout le monde. Merci au **Dieu Tout-Puissant** qui nous a protégés.',
  );

  late final int _length = _segments.fold(0, (n, s) => n + s.$1.length);
  double get _messageEnd => _messageAt + _length / _typing;
  double get _cheersAt => _messageEnd + 2.5;
  double get _doneAt => _cheersAt + cheers.length * _cheerGap + 1.5;

  static List<(String, bool)> _parse(String text) {
    final parts = text.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty) (parts[i], i.isOdd),
    ];
  }

  @override
  void initState() {
    super.initState();
    _clock.addListener(_onTick);
  }

  void _onTick() {
    final e = _elapsed;
    if (e >= _cheersAt) {
      final i = ((e - _cheersAt) / _cheerGap).floor();
      if (i != _cheered && i < cheers.length) {
        _cheered = i;
        widget.game.cheer();
      }
    }
    if (e >= _doneAt && !_bilan) setState(() => _bilan = true);
    if (_scroll.hasClients && e < _messageEnd + 0.5) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  /// La fête attend la fin des trois messages de la cabine, juste après l'atterrissage.
  static const _lead = 15.0;

  double get _elapsed => _clock.value * 180 - _lead;

  @override
  void dispose() {
    _clock.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double _in(double from, [double over = 0.6]) => ((_elapsed - from) / over).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    if (_bilan) return widget.bilan(context);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final e = _elapsed;
        final title = Curves.easeOutBack.transform(_in(_titleAt, 0.8));
        final compact = Curves.easeInOutCubic.transform(_in(_messageAt - 0.8, 0.8));
        final count = (Curves.easeOutCubic.transform(_in(_titleAt, 2.2)) * _years).round();
        final message = _in(_messageAt, 0.5);
        final cheering = e >= _cheersAt;
        final cheer = cheering ? ((e - _cheersAt) / _cheerGap).floor().clamp(0, cheers.length - 1) : -1;
        final cheerT = cheering ? ((e - _cheersAt) % _cheerGap) / _cheerGap : 0.0;
        return Stack(
          children: [
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _bilan = true),
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                label: const Text('Passer', style: TextStyle(color: Colors.white)),
              ),
            ),
            // Le président en fonction à l'arrivée, avec sa photo, dès que le message commence.
            if (message > 0)
              Align(
                alignment: Alignment.bottomLeft,
                child: Opacity(
                  opacity: message,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 0, 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFFFFF1A8), Color(0xFFE0A100), Color(0xFFFFD34D)]),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              archivePhotos['president']!.asset,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.6),
                              errorBuilder: (_, _, _) => const ColoredBox(color: Color(0x33FFFFFF)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Félix Tshisekedi',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Président de la République',
                              style: TextStyle(color: ChachaColors.yellow, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title > 0)
                      Transform.scale(
                        scale: title,
                        child: _Title(count: count, compact: compact, birthday: _in(_titleAt + 2.4)),
                      ),
                    if (message > 0 && !cheering)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Transform.translate(
                            offset: Offset(0, (1 - Curves.easeOutCubic.transform(message)) * 30),
                            child: Glass(
                              tint: const Color(0x66001433),
                              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                                child: SingleChildScrollView(
                                  controller: _scroll,
                                  child: _typed(((e - _messageAt) * _typing).floor()),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (cheering)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * Curves.elasticOut.transform((cheerT * 2.2).clamp(0.0, 1.0)),
                          child: Text(
                            cheers[cheer],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ChachaColors.yellow,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              shadows: [Shadow(color: Color(0xAA000000), blurRadius: 18)],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Le message tapé lettre après lettre, avec un curseur qui clignote.
  Widget _typed(int shown) {
    final spans = <TextSpan>[];
    var left = math.max(0, shown);
    for (final (text, bold) in _segments) {
      if (left <= 0) break;
      final part = text.substring(0, math.min(left, text.length));
      left -= part.length;
      spans.add(
        TextSpan(
          text: part,
          style: bold ? const TextStyle(fontWeight: FontWeight.w900, color: ChachaColors.yellow) : null,
        ),
      );
    }
    final typing = shown < _length;
    if (typing && (_elapsed * 2).floor().isEven) {
      spans.add(
        const TextSpan(
          text: '▍',
          style: TextStyle(color: ChachaColors.yellow),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.45, fontWeight: FontWeight.w500),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.count, required this.compact, required this.birthday});

  final int count;
  final double compact;
  final double birthday;

  @override
  Widget build(BuildContext context) {
    final big = 96 - 52 * compact;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '30 JUIN 2027 · KINSHASA',
          style: TextStyle(
            color: ChachaColors.yellow,
            fontSize: 14 - 3 * compact,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontSize: big,
                fontWeight: FontWeight.w900,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 24)],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ans\nd\'indépendance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22 - 6 * compact,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ],
        ),
        if (birthday > 0 && compact < 1)
          Opacity(
            opacity: birthday * (1 - compact),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Joyeux anniversaire, Congo !',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
