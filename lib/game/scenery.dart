import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../painting/flag_painter.dart';
import '../theme/chacha_colors.dart';

/// Les décors du vol : ciel, soleil, collines, ville, piste et ses lumières.
class Scenery {
  const Scenery._();

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0, 1))!;

  /// [day] : 0 = coucher de soleil au décollage, 1 = plein jour en altitude.
  static void sky(Canvas c, Size s, double day, double storm, double night) {
    final top = _mix(const Color(0xFF1A2766), ChachaColors.skyDeep, day);
    final mid = _mix(const Color(0xFFE9824C), ChachaColors.sky, day);
    final low = _mix(const Color(0xFFFFD48A), const Color(0xFFBFE4FF), day);
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, mid, low],
          stops: const [0, 0.62, 1],
        ).createShader(rect),
    );
    if (storm > 0) c.drawRect(rect, Paint()..color = Color.fromRGBO(18, 20, 38, 0.45 * storm));
    if (night > 0) c.drawRect(rect, Paint()..color = Color.fromRGBO(6, 14, 40, 0.35 * night));
  }

  static void sun(Canvas c, Size s, Offset at, double day) {
    final r = s.height * (0.16 - day * 0.06);
    final color = _mix(const Color(0xFFFFB25C), const Color(0xFFFFF6D0), day);
    c.drawCircle(
      at,
      r * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: at, radius: r * 3.2)),
    );
    c.drawCircle(at, r, Paint()..color = color);
  }

  static double _ridge(double x, double seed) =>
      math.sin(x * 0.0031 + seed) * 0.55 +
      math.sin(x * 0.0083 + seed * 2.1) * 0.3 +
      math.sin(x * 0.019 + seed * 3.7) * 0.15;

  static void hills(Canvas c, Size s, double scroll, double baseY, double height, Color color, double seed) {
    final p = Path()..moveTo(0, s.height + 10);
    for (var x = 0.0; x <= s.width + 20; x += 18) {
      p.lineTo(x, baseY - height * (0.6 + 0.4 * _ridge(x + scroll, seed)));
    }
    p
      ..lineTo(s.width + 20, s.height + 10)
      ..close();
    c.drawPath(p, Paint()..color = color);
  }

  /// La ville de Kinshasa au crépuscule, fenêtres allumées.
  static final List<(double, double, double)> _buildings = () {
    // (position, largeur, hauteur) en unités, tirés une fois pour que la ville ne change pas.
    final rng = math.Random(7);
    final list = <(double, double, double)>[];
    var x = -200.0;
    while (x < 4200) {
      final w = 26 + rng.nextDouble() * 46;
      final h = (14 + rng.nextDouble() * 46) * (rng.nextDouble() < 0.12 ? 1.8 : 1);
      list.add((x, w, h));
      x += w + 10 + rng.nextDouble() * 40;
    }
    return list;
  }();

  static void city(Canvas c, Size s, double offsetX, double groundY, double unit, double dusk) {
    final body = Paint()..color = _mix(const Color(0xFF2A2F55), const Color(0xFF5E7FA8), 1 - dusk);
    final lit = Paint()..color = Color.fromRGBO(255, 214, 130, 0.9 * dusk);
    for (var i = 0; i < _buildings.length; i++) {
      final (bx, bw, bh) = _buildings[i];
      final w = bw * unit, h = bh * unit;
      final sx = bx * unit - offsetX;
      if (sx < -w || sx > s.width) continue;
      final r = Rect.fromLTWH(sx, groundY - h, w, h);
      c.drawRect(r, body);
      if (dusk <= 0.02) continue;
      var row = 0;
      for (var wy = r.top + 8 * unit; wy < r.bottom - 6 * unit; wy += 14 * unit, row++) {
        var col = 0;
        for (var wx = r.left + 6 * unit; wx < r.right - 6 * unit; wx += 12 * unit, col++) {
          if ((i * 31 + row * 17 + col * 7) % 5 < 2) c.drawRect(Rect.fromLTWH(wx, wy, 5 * unit, 6 * unit), lit);
        }
      }
    }
  }

  static void palm(Canvas c, Offset base, double size, Color color) {
    final trunk = Paint()
      ..color = color
      ..strokeWidth = size * 0.07
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final top = base + Offset(size * 0.12, -size);
    c.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx + size * 0.2, base.dy - size * 0.5, top.dx, top.dy),
      trunk,
    );
    final leaf = Paint()..color = color;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi * 0.95 + i * math.pi / 5.5;
      final tip = top + Offset(math.cos(a) * size * 0.55, math.sin(a) * size * 0.35 + size * 0.12);
      c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo((top.dx + tip.dx) / 2, top.dy - size * 0.12, tip.dx, tip.dy)
          ..quadraticBezierTo((top.dx + tip.dx) / 2, top.dy - size * 0.02, top.dx, top.dy),
        leaf,
      );
    }
  }

  static void tower(Canvas c, Offset base, double unit, double blink, double dusk) {
    final shaft = Rect.fromLTWH(base.dx - 9 * unit, base.dy - 120 * unit, 18 * unit, 120 * unit);
    c.drawRect(shaft, Paint()..color = const Color(0xFFDADFE6));
    final cab = Rect.fromLTWH(base.dx - 22 * unit, base.dy - 150 * unit, 44 * unit, 30 * unit);
    c.drawRRect(RRect.fromRectAndRadius(cab, Radius.circular(4 * unit)), Paint()..color = const Color(0xFF2A3346));
    c.drawRect(cab.deflate(4 * unit), Paint()..color = Color.fromRGBO(140, 220, 255, 0.5 + 0.4 * dusk));
    if ((blink % 1.2) < 0.5) {
      glow(c, Offset(base.dx, base.dy - 156 * unit), 4 * unit, const Color(0xFFFF2B3D));
    }
  }

  static void glow(Canvas c, Offset at, double r, Color color) {
    c.drawCircle(
      at,
      r * 4,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: at, radius: r * 4)),
    );
    c.drawCircle(at, r, Paint()..color = Color.lerp(color, Colors.white, 0.6)!);
  }

  /// La piste vue de côté : bande d'asphalte, marquages et feux.
  static void runway(Canvas c, Size s, double worldX, double groundY, double start, double end, double unit, double t) {
    final ground = Rect.fromLTRB(0, groundY - 6 * unit, s.width, s.height + groundY);
    c.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E4A2A), Color(0xFF16261A)],
        ).createShader(ground),
    );

    final x0 = start - worldX, x1 = end - worldX;
    final top = groundY - 4 * unit, bottom = groundY + 34 * unit;
    final band = Rect.fromLTRB(x0, top, x1, bottom);
    c.drawRect(band, Paint()..color = const Color(0xFF2B2F37));
    c.drawRect(Rect.fromLTRB(x0, top, x1, top + 2 * unit), Paint()..color = const Color(0xCCFFFFFF));
    c.drawRect(Rect.fromLTRB(x0, bottom - 2 * unit, x1, bottom), Paint()..color = const Color(0xCCFFFFFF));
    // Ligne centrale en tirets
    final dash = Paint()..color = const Color(0xE6FFFFFF);
    final cy = (top + bottom) / 2;
    final step = 90 * unit;
    for (var x = x0 - ((x0) % step) + step; x < x1; x += step) {
      if (x > -step && x < s.width + step) c.drawRect(Rect.fromLTWH(x, cy - 1.2 * unit, 46 * unit, 2.4 * unit), dash);
    }
    // Seuil de piste : bandes blanches
    for (var i = 0; i < 8; i++) {
      c.drawRect(
        Rect.fromLTWH(x0 + 20 * unit + i * 9 * unit, top + 5 * unit, 5 * unit, bottom - top - 10 * unit),
        dash,
      );
    }

    // Feux de bord : blancs, petits au loin, gros devant
    final lightStep = 70 * unit;
    for (var x = x0; x <= x1; x += lightStep) {
      if (x < -40 || x > s.width + 40) continue;
      glow(c, Offset(x, top), 1.6 * unit, const Color(0xFFFFF4D6));
      glow(c, Offset(x, bottom + 3 * unit), 2.6 * unit, const Color(0xFFFFF4D6));
    }
    // Seuil vert, extrémité rouge
    for (var k = 0; k < 4; k++) {
      final y = top + (bottom - top) * (k / 3);
      glow(c, Offset(x0, y), 2.4 * unit, const Color(0xFF36FF7A));
      glow(c, Offset(x1, y), 2.4 * unit, const Color(0xFFFF3040));
    }
    // Rampe d'approche : les flashs courent vers la piste
    final rabbit = ((t * 2.2) % 1) * 8;
    for (var k = 0; k < 8; k++) {
      final x = x1 + (8 - k) * 28 * unit;
      final on = (k - rabbit).abs() < 0.6;
      glow(c, Offset(x, cy), (on ? 3.4 : 1.6) * unit, on ? Colors.white : const Color(0x66FFFFFF));
    }
    // Voie de circulation : feux bleus
    for (var x = x0; x <= x1; x += 110 * unit) {
      if (x < -40 || x > s.width + 40) continue;
      glow(c, Offset(x + 30 * unit, bottom + 22 * unit), 1.8 * unit, const Color(0xFF3D7BFF));
    }
  }

  static void cloud(Canvas c, Offset at, double r, {bool storm = false, double flash = 0}) {
    final base = storm ? const Color(0xFF3A3F55) : Colors.white;
    final puffs = [
      const Offset(0, 0),
      const Offset(-0.9, 0.25),
      const Offset(0.95, 0.2),
      const Offset(-0.4, -0.45),
      const Offset(0.45, -0.4),
      const Offset(1.6, 0.35),
      const Offset(-1.6, 0.4),
    ];
    final sizes = [1.0, 0.75, 0.8, 0.7, 0.75, 0.5, 0.5];
    for (var i = 0; i < puffs.length; i++) {
      final o = at + puffs[i] * r;
      final rr = r * sizes[i];
      c.drawCircle(
        o,
        rr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.5),
            colors: storm
                ? [const Color(0xFF6A7088), base, const Color(0xFF1F2235)]
                : [Colors.white, const Color(0xF2FFFFFF), const Color(0xB3D7E6F7)],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: o, radius: rr)),
      );
    }
    if (storm && flash > 0) {
      final bolt = Path()
        ..moveTo(at.dx, at.dy + r * 0.3)
        ..lineTo(at.dx - r * 0.25, at.dy + r * 0.9)
        ..lineTo(at.dx + r * 0.05, at.dy + r * 0.9)
        ..lineTo(at.dx - r * 0.2, at.dy + r * 1.6);
      c.drawPath(
        bolt,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..color = Color.fromRGBO(255, 245, 180, flash),
      );
      c.drawCircle(at, r * 1.6, Paint()..color = Color.fromRGBO(255, 240, 200, 0.18 * flash));
    }
  }

  static void medal(Canvas c, Offset at, double r, double t, TextPainter label, {bool glory = false}) {
    final pulse = 1 + 0.08 * math.sin(t * 5);
    c.drawCircle(
      at,
      r * 2.2 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (glory ? const Color(0xFFFFE066) : const Color(0xFFFFD34D)).withValues(alpha: 0.6),
            const Color(0x00FFD34D),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: r * 2.2 * pulse)),
    );
    final rect = Rect.fromCircle(center: at, radius: r);
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFF7C71A), Color(0xFFB8860B)],
        ).createShader(rect),
    );
    c.drawCircle(
      at,
      r * 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = const Color(0xAAFFFFFF),
    );
    if (glory) {
      c.drawPath(FlagPainter.starPath(at + Offset(0, -r * 0.55), r * 0.22), Paint()..color = ChachaColors.red);
    }
    label.paint(c, at - Offset(label.width / 2, label.height / 2 - (glory ? r * 0.12 : 0)));
    // Reflet de verre
    c.drawArc(
      rect.deflate(r * 0.12),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x99FFFFFF),
    );
  }

  static void fuelCan(Canvas c, Offset at, double r) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: r * 1.5, height: r * 1.9),
      Radius.circular(r * 0.25),
    );
    c.drawCircle(
      at,
      r * 2,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x66FF5A4A), Color(0x00FF5A4A)],
        ).createShader(Rect.fromCircle(center: at, radius: r * 2)),
    );
    c.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6A57), Color(0xFFCE1021), Color(0xFF8E0A16)],
        ).createShader(body.outerRect),
    );
    c.drawRect(
      Rect.fromLTWH(at.dx + r * 0.2, at.dy - r * 1.25, r * 0.4, r * 0.35),
      Paint()..color = const Color(0xFFF7D618),
    );
    c.drawLine(
      at + Offset(-r * 0.4, -r * 0.4),
      at + Offset(r * 0.4, r * 0.5),
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = r * 0.14,
    );
    c.drawLine(
      at + Offset(r * 0.4, -r * 0.4),
      at + Offset(-r * 0.4, r * 0.5),
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = r * 0.14,
    );
  }

  /// Le volcan vu de loin, sous l'avion : cône sombre, cratère rouge, coulées de lave.
  /// [base] = le pied du volcan au centre, [width] = sa largeur, [t] anime la lave.
  static void volcano(Canvas c, Offset base, double width, double t, double fury) {
    final h = width * 0.42;
    final top = base.translate(0, -h);
    final crater = width * 0.09;
    final cone = Path()
      ..moveTo(base.dx - width / 2, base.dy)
      ..quadraticBezierTo(base.dx - width * 0.2, base.dy - h * 0.45, top.dx - crater, top.dy)
      ..lineTo(top.dx + crater, top.dy)
      ..quadraticBezierTo(base.dx + width * 0.2, base.dy - h * 0.45, base.dx + width / 2, base.dy)
      ..close();
    final bounds = Rect.fromLTRB(base.dx - width / 2, top.dy, base.dx + width / 2, base.dy);
    // Lueur rouge du ciel autour du cratère
    c.drawCircle(
      top,
      width * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.fromRGBO(255, 90, 30, 0.45 * fury), const Color(0x00FF5A1E)],
        ).createShader(Rect.fromCircle(center: top, radius: width * 0.5)),
    );
    c.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B2A2A), Color(0xFF231A1C), Color(0xFF14100F)],
        ).createShader(bounds),
    );
    // Coulées de lave qui descendent les pentes
    c.save();
    c.clipPath(cone);
    for (var i = 0; i < 5; i++) {
      final side = i.isEven ? -1 : 1;
      final spread = (0.12 + i * 0.07) * side;
      final flow = Path()
        ..moveTo(top.dx + crater * 0.4 * side, top.dy)
        ..cubicTo(
          top.dx + width * spread * 0.5,
          top.dy + h * 0.35,
          top.dx + width * spread * 1.1 + math.sin(t * 0.7 + i) * width * 0.01,
          top.dy + h * 0.65,
          top.dx + width * spread * 1.5,
          base.dy,
        );
      final pulse = 0.75 + 0.25 * math.sin(t * 3 + i * 1.7);
      c.drawPath(
        flow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width * (0.03 - i * 0.003)
          ..color = Color.fromRGBO(255, 80, 20, 0.5 * pulse * fury)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.015),
      );
      c.drawPath(
        flow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width * (0.012 - i * 0.0012)
          ..color = Color.fromRGBO(255, 214, 90, pulse * fury),
      );
    }
    c.restore();
    // Le cratère en fusion
    final mouth = Rect.fromCenter(center: top, width: crater * 2.2, height: crater * 0.6);
    c.drawOval(
      mouth.inflate(crater * 0.4),
      Paint()
        ..color = Color.fromRGBO(255, 110, 30, 0.6 * fury)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, crater * 0.4),
    );
    c.drawOval(mouth, Paint()..color = Color.lerp(const Color(0xFF5A1A10), const Color(0xFFFFC24A), fury)!);
  }

  /// Le camion-citerne de kérosène, vu de côté, cabine à gauche.
  static void fuelTruck(Canvas c, Offset base, double unit, {double hose = 0}) {
    final u = unit;
    final chassis = Rect.fromLTWH(base.dx - 70 * u, base.dy - 16 * u, 140 * u, 7 * u);
    c.drawRect(chassis, Paint()..color = const Color(0xFF2A2E36));
    final cab = RRect.fromRectAndCorners(
      Rect.fromLTWH(base.dx - 70 * u, base.dy - 46 * u, 34 * u, 32 * u),
      topLeft: Radius.circular(10 * u),
      topRight: Radius.circular(3 * u),
    );
    c.drawRRect(cab, Paint()..color = const Color(0xFFF7D618));
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 64 * u, base.dy - 41 * u, 18 * u, 12 * u),
        Radius.circular(3 * u),
      ),
      Paint()..color = const Color(0xFF2B4A6E),
    );
    final tank = RRect.fromRectAndRadius(
      Rect.fromLTWH(base.dx - 32 * u, base.dy - 44 * u, 100 * u, 29 * u),
      Radius.circular(14 * u),
    );
    c.drawRRect(
      tank,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFD5DCE5), Color(0xFF9AA5B4)],
        ).createShader(tank.outerRect),
    );
    c.drawRect(Rect.fromLTWH(base.dx - 32 * u, base.dy - 31 * u, 100 * u, 4 * u), Paint()..color = ChachaColors.red);
    c.drawRect(Rect.fromLTWH(base.dx - 32 * u, base.dy - 27 * u, 100 * u, 2 * u), Paint()..color = ChachaColors.yellow);
    for (final x in [-52.0, 18.0, 46.0]) {
      c.drawCircle(Offset(base.dx + x * u, base.dy - 7 * u), 8 * u, Paint()..color = const Color(0xFF15171C));
      c.drawCircle(Offset(base.dx + x * u, base.dy - 7 * u), 3.5 * u, Paint()..color = const Color(0xFF9AA3AE));
    }
    if (hose > 0) {
      // Le tuyau qui monte vers l'aile
      final from = Offset(base.dx + 68 * u, base.dy - 26 * u);
      final to = from.translate(60 * u * hose, -34 * u * hose);
      c.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(from.dx + 20 * u * hose, from.dy + 14 * u, to.dx, to.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * u
          ..color = const Color(0xFF15171C),
      );
    }
  }

  /// Le camion des pompiers qui vient après un atterrissage raté.
  static void fireTruck(Canvas c, Offset base, double unit, double t) {
    final u = unit;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(base.dx - 60 * u, base.dy - 42 * u, 120 * u, 30 * u),
      topLeft: Radius.circular(10 * u),
      topRight: Radius.circular(4 * u),
    );
    c.drawRRect(body, Paint()..color = const Color(0xFFD7262E));
    c.drawRect(Rect.fromLTWH(base.dx - 60 * u, base.dy - 26 * u, 120 * u, 3 * u), Paint()..color = Colors.white);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 54 * u, base.dy - 38 * u, 20 * u, 11 * u),
        Radius.circular(3 * u),
      ),
      Paint()..color = const Color(0xFF2B4A6E),
    );
    for (final x in [-38.0, 38.0]) {
      c.drawCircle(Offset(base.dx + x * u, base.dy - 8 * u), 8 * u, Paint()..color = const Color(0xFF15171C));
    }
    glow(
      c,
      Offset(base.dx - 40 * u, base.dy - 46 * u),
      3 * u,
      (t * 4) % 1 < 0.5 ? const Color(0xFF3B8BFF) : const Color(0xFFFF3B3B),
    );
  }

  /// Un membre de l'équipe au sol, gilet orange et casque blanc.
  /// [wave] fait bouger son bras (il fait signe ou travaille).
  static void crew(Canvas c, Offset feet, double unit, double wave, {Color vest = const Color(0xFFFF8A1E)}) {
    final u = unit;
    final legs = Paint()
      ..color = const Color(0xFF2B3346)
      ..strokeWidth = 4 * u
      ..strokeCap = StrokeCap.round;
    c.drawLine(feet.translate(-3 * u, 0), feet.translate(-1 * u, -14 * u), legs);
    c.drawLine(feet.translate(3 * u, 0), feet.translate(1 * u, -14 * u), legs);
    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(center: feet.translate(0, -21 * u), width: 11 * u, height: 15 * u),
      Radius.circular(4 * u),
    );
    c.drawRRect(torso, Paint()..color = vest);
    c.drawRect(
      Rect.fromCenter(center: feet.translate(0, -20 * u), width: 11 * u, height: 2 * u),
      Paint()..color = const Color(0xFFF4F6F9),
    );
    final shoulder = feet.translate(4 * u, -26 * u);
    final a = -1.2 + math.sin(wave) * 0.6;
    c.drawLine(shoulder, shoulder.translate(math.cos(a) * 11 * u, math.sin(a) * 11 * u), legs..color = vest);
    c.drawCircle(feet.translate(0, -33 * u), 5 * u, Paint()..color = const Color(0xFF6B4630));
    c.drawArc(
      Rect.fromCircle(center: feet.translate(0, -34 * u), radius: 5.5 * u),
      math.pi,
      math.pi,
      true,
      Paint()..color = Colors.white,
    );
  }

  /// Le kit d'entretien à attraper en vol : une clé dans une bulle verte.
  static void repairKit(Canvas c, Offset at, double r, double t) {
    c.drawCircle(
      at,
      r * 2,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x665AB4FF), Color(0x005AB4FF)],
        ).createShader(Rect.fromCircle(center: at, radius: r * 2)),
    );
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9FD3FF), Color(0xFF1F6FD1)],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(-0.7 + math.sin(t * 2) * 0.15);
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.24
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(0, -r * 0.45), Offset(0, r * 0.5), p);
    c.drawArc(
      Rect.fromCircle(center: Offset(0, -r * 0.5), radius: r * 0.28),
      math.pi * 0.1,
      math.pi * 1.8,
      false,
      p..style = PaintingStyle.stroke,
    );
    c.restore();
  }

  /// Une boîte-cadeau aux couleurs du drapeau.
  static void gift(Canvas c, Offset at, double r, double rot) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(rot);
    final box = Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.7);
    c.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(r * 0.2)), Paint()..color = ChachaColors.sky);
    c.drawRect(
      Rect.fromCenter(center: Offset.zero, width: r * 0.4, height: r * 1.7),
      Paint()..color = ChachaColors.yellow,
    );
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.4), Paint()..color = ChachaColors.red);
    c.drawCircle(Offset(-r * 0.3, -r * 1.0), r * 0.32, Paint()..color = ChachaColors.red);
    c.drawCircle(Offset(r * 0.3, -r * 1.0), r * 0.32, Paint()..color = ChachaColors.red);
    c.restore();
  }
}
