import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/chacha_game.dart';
import '../data/cabin_talk.dart';
import '../theme/chacha_colors.dart';
import 'finale.dart' show TypingDots;
import 'passenger_art.dart';

/// Le petit écran de bord : la cabine vue depuis l'avant, les passagers, l'hôtesse dans l'allée.
class CabinCameraView extends StatefulWidget {
  const CabinCameraView({super.key, required this.shot, required this.fill, required this.onClose});

  final CabinCameraShot shot;
  final double fill;
  final VoidCallback onClose;

  @override
  State<CabinCameraView> createState() => _CabinCameraViewState();
}

class _CabinCameraViewState extends State<CabinCameraView> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.shot.line;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xE60B1B3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 108,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _CabinPainter(_clock, widget.shot.seat, widget.fill)),
                  ),
                ),
                // La publicité de bord, en bas de l'écran de la cabine : deux marques à tour de rôle.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _clock,
                      builder: (context, _) {
                        final first = _clock.value < 0.5;
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: _CabinAd(
                            key: ValueKey(first),
                            color: first ? const Color(0xFF1B2E24) : const Color(0xFF0B5C8E),
                            logo: first ? 'assets/ads/zwacolis.png' : 'assets/ads/jompiks.png',
                            text: first
                                ? 'ZwaColis · vos colis Europe-Afrique avec des voyageurs'
                                : 'Académie Digitale · Jompik\'s technology',
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Positioned(
                  left: 7,
                  top: 5,
                  child: IgnorePointer(
                    child: Text(
                      '● CAMÉRA CABINE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .6,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
              child: _ChatLine(key: ObjectKey(l), line: l, right: widget.shot.seat.isOdd),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une réplique comme dans une messagerie : le visage de celui qui parle, les trois points, puis ses mots.
class _CabinAd extends StatelessWidget {
  const _CabinAd({super.key, required this.color, required this.logo, required this.text});

  final Color color;
  final String logo, text;

  @override
  Widget build(BuildContext context) => Container(
    height: 15,
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Row(
      children: [
        Image.asset(logo, width: 11, height: 11, cacheWidth: 44),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ChatLine extends StatefulWidget {
  const _ChatLine({super.key, required this.line, required this.right});

  final TalkLine line;
  final bool right;

  @override
  State<_ChatLine> createState() => _ChatLineState();
}

class _ChatLineState extends State<_ChatLine> with SingleTickerProviderStateMixin {
  static const _dots = 0.55;
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 4))..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Qui parle : la maman, la grand-mère, la jeune femme ou l'homme.
  PassengerKind get _kind {
    final who = widget.line.speaker.toLowerCase();
    bool has(List<String> words) => words.any(who.contains);
    if (has(['mamie', 'grand', 'koko', 'vieille'])) return PassengerKind.grandmother;
    if (has(['maman', 'mama', 'mère'])) return PassengerKind.mother;
    if (has(['hôtesse', 'voisine', 'femme', 'fille', 'sœur', 'dame', 'passagère', 'étudiante'])) {
      return PassengerKind.youngWoman;
    }
    return PassengerKind.youngMan;
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line, kind = _kind;
    final face = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFCFE3FF),
        border: Border.all(color: ChachaColors.yellow, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      // Une vraie photo si elle a été déposée dans assets/passengers, sinon le portrait dessiné.
      child: Image.asset(
        'assets/passengers/${kind.name}.jpg',
        fit: BoxFit.cover,
        cacheWidth: 136,
        errorBuilder: (_, _, _) => CustomPaint(painter: PassengerPainter(kind)),
      ),
    );
    const radius = Radius.circular(12);
    return AnimatedBuilder(
      animation: _clock,
      builder: (_, _) {
        final s = _clock.value * 4;
        final pop = Curves.easeOutBack.transform((s / 0.3).clamp(0.0, 1.0));
        final perLetter = math.min(0.03, 1.3 / math.max(1, l.lingala.length));
        final letters = ((s - _dots) / perLetter).floor().clamp(0, l.lingala.length);
        final typed = letters >= l.lingala.length;
        final bubble = Flexible(
          child: Transform.scale(
            scale: 0.7 + 0.3 * pop,
            alignment: widget.right ? Alignment.bottomRight : Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
              decoration: BoxDecoration(
                color: widget.right ? const Color(0xFF1F6FE0) : const Color(0xFF22355C),
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: widget.right ? radius : const Radius.circular(3),
                  bottomRight: widget.right ? const Radius.circular(3) : radius,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.speaker,
                    style: const TextStyle(color: ChachaColors.yellow, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                  if (s < _dots)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Transform.scale(
                        scale: 0.7,
                        alignment: Alignment.centerLeft,
                        child: TypingDots(phase: s),
                      ),
                    )
                  else ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: l.lingala.substring(0, letters)),
                          TextSpan(
                            text: l.lingala.substring(letters),
                            style: const TextStyle(color: Colors.transparent),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    // La traduction suit, une fois la phrase écrite.
                    AnimatedOpacity(
                      opacity: typed ? 1 : 0,
                      duration: const Duration(milliseconds: 260),
                      child: Text(
                        l.french,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: widget.right ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: widget.right ? [bubble, const SizedBox(width: 6), face] : [face, const SizedBox(width: 6), bubble],
        );
      },
    );
  }
}

class _CabinPainter extends CustomPainter {
  _CabinPainter(this.clock, this.speaker, this.fill) : super(repaint: clock);

  final Animation<double> clock;
  final int speaker;
  final double fill;

  static const _rows = [0.5, 0.72, 1.0];
  static final _busts = <PassengerKind, ui.Picture>{};

  static ui.Picture _bust(PassengerKind kind) => _busts[kind] ??= () {
    final r = ui.PictureRecorder();
    PassengerPainter(kind).paint(Canvas(r), const Size(100, 100));
    return r.endRecording();
  }();

  void _person(Canvas c, PassengerKind kind, Offset bottom, double size) {
    c.save();
    c.translate(bottom.dx - size / 2, bottom.dy - size);
    c.scale(size / 100);
    c.drawPicture(_bust(kind));
    c.restore();
  }

  double _depth(double z) {
    final i = z.floor().clamp(0, _rows.length - 2);
    return _rows[i] + (_rows[i + 1] - _rows[i]) * (z - i);
  }

  double _floor(Size s, double scale) => s.height * (1.217 * scale - 0.196);

  /// Quelqu'un debout dans l'allée : le buste, puis le corps jusqu'au sol.
  void _standing(Canvas c, Size s, PassengerKind kind, double z, double side, bool crew) {
    final scale = _depth(z);
    final size = s.height * 0.5 * scale;
    final floor = _floor(s, scale);
    final x = s.width / 2 + side * s.width * scale;
    final bust = Offset(x, floor - size * 0.8);
    final color = crew ? const Color(0xFF16305F) : const Color(0xFF8E4A2B);
    c.drawRect(
      Rect.fromCenter(center: Offset(x, floor - size * 0.5), width: size * 0.56, height: size),
      Paint()..color = color,
    );
    _person(c, kind, bust, size);
    if (crew) {
      c.drawRect(
        Rect.fromLTWH(x - size * 0.34, bust.dy - size * 0.2, size * 0.68, size * 0.24),
        Paint()..color = color,
      );
      c.drawPath(
        Path()
          ..moveTo(x - size * 0.12, bust.dy - size * 0.24)
          ..lineTo(x + size * 0.12, bust.dy - size * 0.24)
          ..lineTo(x, bust.dy - size * 0.06)
          ..close(),
        Paint()..color = ChachaColors.yellow,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, bust.dy - size * 0.92), width: size * 0.34, height: size * 0.11),
          Radius.circular(size * 0.04),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final turn = clock.value * 2 * math.pi;
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4EEDF), Color(0xFFC9C0AC)],
        ).createShader(rect),
    );
    final v = Offset(s.width / 2, s.height * 0.16);
    final lines = Paint()
      ..color = const Color(0x55776B55)
      ..strokeWidth = 1;
    c.drawLine(v.translate(-14, -6), const Offset(0, 0), lines);
    c.drawLine(v.translate(14, -6), Offset(s.width, 0), lines);
    // Les hublots, de plus en plus grands vers nous
    for (final r in _rows) {
      for (final side in [-1.0, 1.0]) {
        final w = Rect.fromCenter(
          center: Offset(v.dx + side * s.width * 0.5 * r * 0.9, v.dy + s.height * 0.02),
          width: 9 * r,
          height: 15 * r,
        );
        c.drawRRect(RRect.fromRectAndRadius(w, Radius.circular(4 * r)), Paint()..color = const Color(0xFF7CC4F2));
      }
    }
    // L'allée
    c.drawPath(
      Path()
        ..moveTo(v.dx - 6, v.dy)
        ..lineTo(v.dx + 6, v.dy)
        ..lineTo(s.width * 0.66, s.height)
        ..lineTo(s.width * 0.34, s.height)
        ..close(),
      Paint()..color = const Color(0xFF344A6B),
    );

    const kinds = PassengerKind.values;
    final occupied = (12 * fill.clamp(0.85, 1.0)).ceil();
    final hostess = 1 + 0.75 * math.sin(turn);
    var seat = 0;
    for (var row = 0; row < _rows.length; row++) {
      final r = _rows[row];
      final size = s.height * 0.5 * r;
      final floor = _floor(s, r);
      for (final (place, far) in const [(0.17, -1.0), (0.37, -1.0), (0.17, 1.0), (0.37, 1.0)]) {
        final x = v.dx + far * place * s.width * r * 1.05;
        final back = Rect.fromCenter(center: Offset(x, floor - size * 0.52), width: size * 0.86, height: size * 1.05);
        final radius = Radius.circular(size * 0.14);
        c.drawRRect(
          RRect.fromRectAndRadius(back, radius),
          Paint()..color = Color.lerp(const Color(0xFF1B4F8F), const Color(0xFF2A70BD), r / _rows.last)!,
        );
        // L'appui-tête, comme sur les vrais sièges
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, back.top + size * 0.14), width: size * 0.66, height: size * 0.26),
            radius,
          ),
          Paint()..color = const Color(0xFFE6E8EC),
        );
        // Tout le monde n'est pas dans l'ordre des sièges : l'avion se remplit en quinconce.
        if ((seat * 5) % 12 < occupied) {
          final talking = seat == speaker % 12;
          final bob = math.sin(turn * (talking ? 8 : 1) + seat * 1.3) * size * (talking ? 0.03 : 0.012);
          final at = Offset(x, floor - size * 0.08 + bob);
          _person(c, kinds[(seat * 3 + row) % kinds.length], at, size);
          if (talking) {
            final dots = Paint()..color = Colors.white;
            for (var d = 0; d < 3; d++) {
              final up = math.sin(turn * 12 + d) > 0 ? 1.5 : 0.0;
              c.drawCircle(Offset(x - 5 + d * 5.0, at.dy - size * 1.02 - up), 1.6, dots);
            }
          }
        }
        seat++;
      }
      if (row == 0) _standing(c, s, PassengerKind.youngMan, 0.5, -0.05, false);
      if (hostess >= row && hostess < row + 1) _standing(c, s, PassengerKind.youngWoman, hostess, 0.03, true);
    }
  }

  @override
  bool shouldRepaint(_CabinPainter old) => old.speaker != speaker || old.fill != fill;
}
