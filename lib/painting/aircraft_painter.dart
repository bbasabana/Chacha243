import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/aircraft_types.dart';
import '../data/eras.dart';
import '../theme/chacha_colors.dart';
import 'flag_painter.dart';

/// Dessine un avion vu de profil, nez à droite, avec un ombrage qui lui donne du volume.
///
/// Tout est vectoriel : le même dessin reste net d'un téléphone à un écran 4K.
/// Le dessin occupe une boîte de 100 × 50 unités, mise à l'échelle de [box].
class AircraftPainter {
  const AircraftPainter._();

  static void paint(
    Canvas canvas,
    Size box,
    AircraftType type,
    Livery livery, {
    double propPhase = 0,
    double gear = 0,
    bool landingLight = false,
    double blink = 0,
  }) {
    final u = box.width / 100;
    canvas.save();
    canvas.translate(0, box.height * 0.5);
    canvas.scale(u);

    final h = type.bodyHeight / 2;
    final body = _bodyPath(type, h);

    if (landingLight) _drawLandingLight(canvas, h);
    _drawFarWing(canvas, type, h, livery);
    if (type.layout == EngineLayout.rearJets) _drawRearEngine(canvas, h, far: true);
    _drawTail(canvas, type, h, livery);
    if (gear > 0) _drawGear(canvas, type, h, gear);
    _drawBody(canvas, body, type, h, livery);
    _drawWindows(canvas, type, h);
    _drawStabilizer(canvas, h, livery);
    if (type.layout == EngineLayout.rearJets) _drawRearEngine(canvas, h);
    if (type.layout == EngineLayout.triJet) _drawTailEngine(canvas, h);
    _drawNearWing(canvas, type, h, livery, propPhase);
    _drawLights(canvas, type, h, blink);

    canvas.restore();
  }

  // ---------------------------------------------------------------- fuselage

  static Path _bodyPath(AircraftType t, double h) {
    final p = Path()..moveTo(2, -h * 0.55);
    p.cubicTo(8, -h * 0.85, 16, -h, 26, -h);
    final noseStart = t.hump ? 90.0 : 86.0;
    if (t.hump) {
      p.lineTo(52, -h);
      p.cubicTo(60, -h, 63, -h * 1.75, 72, -h * 1.75);
      p.cubicTo(82, -h * 1.75, 87, -h * 1.35, noseStart, -h);
    } else {
      p.lineTo(noseStart, -h);
    }
    p.cubicTo(95, -h * 0.98, 100, -h * 0.25, 100, h * 0.2);
    p.cubicTo(100, h * 0.7, 95, h, 88, h);
    p.lineTo(32, h);
    p.cubicTo(20, h, 9, h * 0.25, 2, -h * 0.2);
    p.close();
    return p;
  }

  static void _drawBody(Canvas canvas, Path body, AircraftType t, double h, Livery l) {
    final top = t.hump ? -h * 1.75 : -h;
    // Ombre portée douce sous le fuselage
    canvas.drawPath(
      body.shift(const Offset(0, 1.6)),
      Paint()
        ..color = const Color(0x40001433)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );

    // Volume du cylindre : reflet en haut, ventre plus sombre
    final shade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(l.body, Colors.white, 0.7)!,
          l.body,
          Color.lerp(l.body, l.belly, 0.55)!,
          Color.lerp(l.belly, Colors.black, 0.25)!,
        ],
        stops: const [0, 0.35, 0.72, 1],
      ).createShader(Rect.fromLTRB(0, top, 100, h));
    canvas.drawPath(body, shade);

    canvas.save();
    canvas.clipPath(body);
    // Liseré de la compagnie
    canvas.drawRect(Rect.fromLTRB(0, h * 0.02, 100, h * 0.2), Paint()..color = l.stripe);
    canvas.drawRect(Rect.fromLTRB(0, h * 0.26, 100, h * 0.36), Paint()..color = l.stripe2);
    if (l.nose != null) {
      // Avant peint, puis la diagonale rouge bordée de jaune qui descend vers l'aile
      final top2 = top - 1;
      canvas.drawPath(
        Path()
          ..moveTo(66, top2)
          ..lineTo(101, top2)
          ..lineTo(101, h + 1)
          ..lineTo(56, h + 1)
          ..close(),
        Paint()..color = l.nose!,
      );
      canvas.drawPath(
        Path()
          ..moveTo(66, top2)
          ..lineTo(63.2, top2)
          ..lineTo(53.2, h + 1)
          ..lineTo(56, h + 1)
          ..close(),
        Paint()..color = ChachaColors.red,
      );
      canvas.drawPath(
        Path()
          ..moveTo(63.2, top2)
          ..lineTo(62.2, top2)
          ..lineTo(52.2, h + 1)
          ..lineTo(53.2, h + 1)
          ..close(),
        Paint()..color = ChachaColors.yellow,
      );
    }
    if (l.fuselageFlag) {
      FlagPainter.paintFlag(canvas, Rect.fromLTWH(17, -h * 0.05, 3.6, 2.4), FlagStyle.current2006);
    }
    // Ombrage du liseré pour garder le volume
    canvas.drawRect(
      Rect.fromLTRB(0, -h * 2, 100, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0x00000000), Color(0x00000000), Color(0x33000000)],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromLTRB(0, top, 100, h)),
    );
    // Reflet spéculaire, comme sur du métal poli
    canvas.drawLine(
      Offset(24, -h * 0.66),
      Offset(t.hump ? 54 : 88, -h * 0.66),
      Paint()
        ..color = const Color(0xA6FFFFFF)
        ..strokeWidth = h * 0.16
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
    if (t.hump) {
      canvas.drawLine(
        Offset(64, -h * 1.5),
        Offset(84, -h * 1.45),
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..strokeWidth = h * 0.14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
    }
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.18
        ..color = const Color(0x55001433),
    );
  }

  static void _drawWindows(Canvas canvas, AircraftType t, double h) {
    final glass = Paint()..color = const Color(0xFF13284D);
    final shine = Paint()..color = const Color(0x8CBFE0FF);
    final y = -h * 0.3;
    final end = t.hump ? 84.0 : 83.0;
    final step = t.bodyHeight > 12 ? 2.1 : 2.5;
    for (var x = 28.0; x < end; x += step) {
      if ((x - 52).abs() < 1.2) continue; // issue de secours au-dessus de l'aile
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 1.05, height: 1.55),
        const Radius.circular(0.5),
      );
      canvas.drawRRect(r, glass);
      canvas.drawRect(Rect.fromLTWH(x - 0.4, y - 0.65, 0.35, 0.5), shine);
    }
    if (t.hump) {
      for (var x = 66.0; x < 82; x += 2.1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, -h * 1.35), width: 1.05, height: 1.45),
            const Radius.circular(0.5),
          ),
          glass,
        );
      }
    }
    // Portes avant et arrière
    final door = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.18
      ..color = const Color(0x66001433);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(84.3, -h * 0.62, 2.2, h * 1.2), const Radius.circular(0.6)),
      door,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(26.0, -h * 0.62, 2.0, h * 1.15), const Radius.circular(0.6)),
      door,
    );
    // Cockpit
    final cy = t.hump ? -h * 1.45 : -h * 0.5;
    final cx = t.hump ? 85.5 : 92.0;
    final cockpit = Path()
      ..moveTo(cx, cy - h * 0.12)
      ..lineTo(cx + 4.4, cy + h * 0.02)
      ..lineTo(cx + 5.4, cy + h * 0.32)
      ..lineTo(cx + 0.4, cy + h * 0.28)
      ..close();
    canvas.drawPath(cockpit, Paint()..color = const Color(0xFF0E1E3C));
    canvas.drawLine(
      Offset(cx + 0.8, cy),
      Offset(cx + 3.8, cy + h * 0.08),
      Paint()
        ..color = const Color(0xB3D6ECFF)
        ..strokeWidth = 0.35,
    );
  }

  // -------------------------------------------------------------- empennage

  static void _drawTail(Canvas canvas, AircraftType t, double h, Livery l) {
    final finH = t.bodyHeight * 1.45;
    final base = t.layout == EngineLayout.triJet ? -h * 1.55 : -h * 0.9;
    final fin = Path()
      ..moveTo(26, -h * 0.98)
      ..lineTo(10, base - finH)
      ..lineTo(3.2, base - finH)
      ..lineTo(2.6, -h * 0.5)
      ..close();
    canvas.drawPath(
      fin,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Color.lerp(l.tail, Colors.white, 0.35)!, l.tail, Color.lerp(l.tail, Colors.black, 0.25)!],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromLTRB(2, base - finH, 26, -h * 0.5)),
    );
    // Bord d'attaque brillant
    canvas.drawLine(
      Offset(25, -h * 1.02),
      Offset(10.2, base - finH + 0.3),
      Paint()
        ..color = const Color(0x80FFFFFF)
        ..strokeWidth = 0.5,
    );

    final center = Offset(9.5, base - finH * 0.52);
    final r = finH * 0.2;
    switch (l.emblem) {
      case TailEmblem.star:
        canvas.drawPath(
          FlagPainter.starPath(center, r),
          Paint()..color = ChachaColors.yellow,
        );
      case TailEmblem.zaire:
        canvas.drawCircle(center, r, Paint()..color = ChachaColors.yellow);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - r * 0.75)
            ..quadraticBezierTo(center.dx + r * 0.5, center.dy, center.dx, center.dy + r * 0.4)
            ..quadraticBezierTo(center.dx - r * 0.5, center.dy, center.dx, center.dy - r * 0.75),
          Paint()..color = ChachaColors.red,
        );
      case TailEmblem.flag:
        canvas.save();
        canvas.clipPath(fin);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(-math.pi / 3.2);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: finH * 3, height: r * 1.3),
            Paint()..color = ChachaColors.yellow);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: finH * 3, height: r * 0.9),
            Paint()..color = ChachaColors.red);
        canvas.restore();
        canvas.drawPath(
          FlagPainter.starPath(Offset(center.dx - r * 0.2, center.dy - r * 1.6), r * 0.55),
          Paint()..color = ChachaColors.yellow,
        );
        canvas.restore();
      case TailEmblem.roundel:
        canvas.drawCircle(center, r * 1.15, Paint()..color = const Color(0xFF1F6FB8));
        canvas.drawCircle(center, r * 1.05, Paint()..color = const Color(0xFF3FB6E8));
        canvas.drawPath(FlagPainter.starPath(center, r * 0.75), Paint()..color = ChachaColors.yellow);
      case TailEmblem.none:
        break;
    }
  }

  static void _drawStabilizer(Canvas canvas, double h, Livery l) {
    final stab = Path()
      ..moveTo(17, -h * 0.25)
      ..lineTo(5.5, h * 0.55)
      ..lineTo(2.2, h * 0.55)
      ..lineTo(5.5, -h * 0.3)
      ..close();
    canvas.drawPath(
      stab,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(l.body, Colors.white, 0.4)!, Color.lerp(l.belly, Colors.black, 0.1)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(2, -h * 0.3, 17, h * 0.55)),
    );
  }

  // ------------------------------------------------------------------- ailes

  static void _drawFarWing(Canvas canvas, AircraftType t, double h, Livery l) {
    if (t.highWing) return;
    final far = Path()
      ..moveTo(60, -h * 0.15)
      ..lineTo(46, -h * 0.15)
      ..lineTo(38, -h * 1.15)
      ..lineTo(41, -h * 1.2)
      ..close();
    canvas.drawPath(far, Paint()..color = Color.lerp(l.belly, Colors.black, 0.35)!);
  }

  static void _drawNearWing(Canvas canvas, AircraftType t, double h, Livery l, double propPhase) {
    final Path wing;
    if (t.highWing) {
      wing = Path()
        ..moveTo(62, -h * 0.98)
        ..lineTo(49, -h * 0.98)
        ..lineTo(38, h * 0.95)
        ..lineTo(41.5, h * 1.0)
        ..close();
    } else {
      final span = t.bodyHeight > 12 ? 2.3 : 2.0;
      wing = Path()
        ..moveTo(63, h * 0.35)
        ..lineTo(45, h * 0.42)
        ..lineTo(33, h * span)
        ..lineTo(37.5, h * (span + 0.06))
        ..close();
    }
    final bounds = wing.getBounds();
    canvas.drawPath(
      wing.shift(const Offset(0, 0.8)),
      Paint()
        ..color = const Color(0x33001433)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawPath(
      wing,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color.lerp(l.body, Colors.white, 0.6)!, Color.lerp(l.belly, Colors.black, 0.05)!],
        ).createShader(bounds),
    );
    // Bord d'attaque
    final lead = t.highWing
        ? [Offset(62, -h * 0.98), Offset(41.5, h * 1.0)]
        : [Offset(63, h * 0.35), Offset(37.5, h * ((t.bodyHeight > 12 ? 2.3 : 2.0) + 0.06))];
    canvas.drawLine(lead[0], lead[1],
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..strokeWidth = 0.45);

    // Moteurs, du plus loin au plus proche du fuselage
    Offset along(double f) => Offset.lerp(lead[0], lead[1], f)!;
    switch (t.layout) {
      case EngineLayout.twinJets:
      case EngineLayout.triJet:
        _jet(canvas, along(0.3) + Offset(0, h * 0.55), t.bodyHeight > 12 ? 14 : 11, h * 0.42, l.engine);
      case EngineLayout.fourJets:
        _jet(canvas, along(0.55) + Offset(0, h * 0.45), 10, h * 0.34, l.engine);
        _jet(canvas, along(0.25) + Offset(0, h * 0.5), 11, h * 0.38, l.engine);
      case EngineLayout.twinProps:
        _prop(canvas, along(t.highWing ? 0.28 : 0.3) + Offset(-2, h * (t.highWing ? 0.25 : 0.2)), h, propPhase);
      case EngineLayout.fourProps:
        _prop(canvas, along(0.55) + Offset(-2, h * 0.15), h * 0.9, propPhase + 1.3);
        _prop(canvas, along(0.25) + Offset(-2, h * 0.2), h, propPhase);
      case EngineLayout.rearJets:
        break;
    }
    // Feu de navigation vert au bout de l'aile proche (droite de l'avion)
    canvas.drawCircle(lead[1] + const Offset(0.8, 0.1), 0.55, Paint()..color = const Color(0xFF39FF88));
  }

  // ----------------------------------------------------------------- moteurs

  static void _jet(Canvas canvas, Offset c, double len, double r, [Color? paint]) {
    final rect = Rect.fromCenter(center: c, width: len, height: r * 2);
    canvas.drawLine(c + Offset(len * 0.1, -r), c + Offset(len * 0.2, -r * 2.2),
        Paint()
          ..color = const Color(0xFF9AA6B5)
          ..strokeWidth = r * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: paint == null
              ? const [Color(0xFFFFFFFF), Color(0xFFC8D2DE), Color(0xFF7D8896)]
              : [Color.lerp(paint, Colors.white, 0.55)!, paint, Color.lerp(paint, Colors.black, 0.35)!],
        ).createShader(rect),
    );
    if (paint != null) {
      // Liseré rouge et jaune sur le capot, comme sur la livrée
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
      canvas.drawLine(Offset(rect.left + len * 0.2, rect.bottom), Offset(rect.left + len * 0.55, rect.top),
          Paint()
            ..color = ChachaColors.yellow
            ..strokeWidth = r * 0.5);
      canvas.drawLine(Offset(rect.left + len * 0.27, rect.bottom), Offset(rect.left + len * 0.62, rect.top),
          Paint()
            ..color = ChachaColors.red
            ..strokeWidth = r * 0.3);
      canvas.restore();
    }
    // Entrée d'air et sortie des gaz
    canvas.drawOval(Rect.fromCenter(center: Offset(rect.right - r * 0.15, c.dy), width: r * 0.6, height: r * 1.75),
        Paint()..color = const Color(0xFF1A2333));
    canvas.drawOval(Rect.fromCenter(center: Offset(rect.right - r * 0.05, c.dy), width: r * 0.3, height: r * 1.9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.25
          ..color = const Color(0xFFE6EDF5));
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + 0.2, c.dy - r * 0.6)
        ..lineTo(rect.left - r * 0.9, c.dy)
        ..lineTo(rect.left + 0.2, c.dy + r * 0.6)
        ..close(),
      Paint()..color = const Color(0xFF5B6573),
    );
    canvas.drawLine(Offset(rect.left + r, c.dy - r * 0.55), Offset(rect.right - r, c.dy - r * 0.55),
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round);
  }

  static void _prop(Canvas canvas, Offset c, double h, double phase) {
    final r = h * 0.4;
    final len = 11.0;
    final rect = Rect.fromLTWH(c.dx - len * 0.5, c.dy - r, len, r * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFC2CCD8), Color(0xFF6E7987)],
        ).createShader(rect),
    );
    final hub = Offset(rect.right + 0.6, c.dy);
    // Disque d'hélice flou qui tourne
    canvas.drawOval(
      Rect.fromCenter(center: hub, width: 2.2, height: h * 2.8),
      Paint()
        ..shader = RadialGradient(colors: const [Color(0x88D8E2EE), Color(0x22D8E2EE)])
            .createShader(Rect.fromCenter(center: hub, width: 2.2, height: h * 2.8)),
    );
    final blade = Paint()
      ..color = const Color(0xCC2A2F38)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final a = phase + k * 2 * math.pi / 3;
      canvas.drawLine(hub, hub + Offset(math.cos(a) * 0.5, math.sin(a) * h * 1.35), blade);
    }
    canvas.drawPath(
      Path()
        ..moveTo(hub.dx - 0.5, hub.dy - r * 0.7)
        ..quadraticBezierTo(hub.dx + 1.8, hub.dy, hub.dx - 0.5, hub.dy + r * 0.7)
        ..close(),
      Paint()..color = const Color(0xFFE9EEF4),
    );
  }

  static void _drawRearEngine(Canvas canvas, double h, {bool far = false}) {
    if (far) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(23, -h * 1.05), width: 12, height: h * 0.6),
          Radius.circular(h * 0.3),
        ),
        Paint()..color = const Color(0xFF8792A0),
      );
      return;
    }
    _jet(canvas, Offset(21, -h * 0.55), 12, h * 0.36);
  }

  static void _drawTailEngine(Canvas canvas, double h) {
    _jet(canvas, Offset(14, -h * 1.25), 13, h * 0.36);
  }

  // ------------------------------------------------------------ train, feux

  static void _drawGear(Canvas canvas, AircraftType t, double h, double gear) {
    final strut = Paint()
      ..color = const Color(0xFF8B95A2)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    final tyre = Paint()..color = const Color(0xFF1B1E24);
    final hubPaint = Paint()..color = const Color(0xFFB9C2CD);
    final drop = 5.5 * gear;
    for (final x in [49.0, 46.0]) {
      canvas.drawLine(Offset(x, h * 0.8), Offset(x, h + drop), strut);
      canvas.drawCircle(Offset(x, h + drop + 0.6), 1.6, tyre);
      canvas.drawCircle(Offset(x, h + drop + 0.6), 0.6, hubPaint);
    }
    canvas.drawLine(Offset(88, h * 0.8), Offset(88, h + drop), strut);
    canvas.drawCircle(Offset(88, h + drop + 0.6), 1.2, tyre);
  }

  static void _drawLights(Canvas canvas, AircraftType t, double h, double blink) {
    final on = (blink % 1) < 0.12;
    if (!on) return;
    final glow = Paint()
      ..color = const Color(0xFFFF2B3D)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawCircle(Offset(55, (t.hump ? -h * 1.75 : -h) - 0.3), 1.0, glow);
    canvas.drawCircle(Offset(52, h + 0.3), 1.0, glow);
    canvas.drawCircle(
      Offset(4.5, -h - t.bodyHeight * 1.4),
      1.2,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
  }

  static void _drawLandingLight(Canvas canvas, double h) {
    final beam = Path()
      ..moveTo(90, h * 0.55)
      ..lineTo(150, h * 0.1)
      ..lineTo(150, h * 3.2)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x99FFF6D8), Color(0x00FFF6D8)],
        ).createShader(Rect.fromLTRB(90, -h, 150, h * 3)),
    );
  }
}

/// Un [CustomPainter] pour afficher un avion dans l'interface (hangar, accueil).
class AircraftView extends CustomPainter {
  AircraftView(this.type, this.livery, {this.propPhase = 0, this.gear = 0});

  final AircraftType type;
  final Livery livery;
  final double propPhase;
  final double gear;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = w * 0.5;
    canvas.translate(0, (size.height - h) / 2);
    AircraftPainter.paint(canvas, Size(w, h), type, livery, propPhase: propPhase, gear: gear, blink: 0.5);
  }

  @override
  bool shouldRepaint(AircraftView old) =>
      old.type != type || old.livery != livery || old.propPhase != propPhase || old.gear != gear;
}
