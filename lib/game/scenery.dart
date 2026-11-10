import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  /// La silhouette de Kinshasa dessinée par un designer (et ses fenêtres), chargée au lancement du jeu.
  static ui.Image? skyline, skylineWindows;

  static Future<void> loadSkyline() async {
    if (skyline != null) return;
    Future<ui.Image> load(String name) async {
      final data = await rootBundle.load('assets/scenery/$name');
      return (await ui.instantiateImageCodec(data.buffer.asUint8List())).getNextFrame().then((f) => f.image);
    }

    try {
      skyline = await load('kinshasa-skyline.png');
      skylineWindows = await load('kinshasa-windows.png');
    } catch (_) {
      // Sans l'image, on garde les petits immeubles dessinés à la main.
    }
  }

  /// Deux plans de skyline qui défilent à des vitesses différentes, avec un léger balancement ;
  /// au crépuscule, les fenêtres s'allument et scintillent.
  static void _skyline(Canvas c, Size s, double offsetX, double groundY, double unit, double dusk, double t) {
    final img = skyline!;
    final aspect = img.width / img.height;
    void layer(double h, double speed, double lift, Color color, double lights, double phase) {
      final w = h * aspect;
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final sway = math.sin(t * 0.5 + phase) * 1.6 * unit;
      final x0 = -((offsetX * speed) % (2 * w));
      final body = Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
      final glass = Paint()
        ..colorFilter = ColorFilter.mode(
          Color.fromRGBO(255, 214, 130, (0.95 * lights * (0.82 + 0.18 * math.sin(t * 2.3 + phase))).clamp(0, 1)),
          BlendMode.srcIn,
        );
      for (var i = 0; i < 4; i++) {
        final x = x0 + i * w;
        if (x > s.width || x + w < 0) continue;
        final dst = Rect.fromLTWH(x, groundY - h + lift + sway, w, h);
        c.save();
        if (i.isOdd) {
          // Une image sur deux est retournée : la ville se raccorde sans coupure.
          c.translate(dst.center.dx, 0);
          c.scale(-1, 1);
          c.translate(-dst.center.dx, 0);
        }
        c.drawImageRect(img, src, dst, body);
        if (lights > 0.02 && skylineWindows != null) c.drawImageRect(skylineWindows!, src, dst, glass);
        c.restore();
      }
    }

    layer(120 * unit, 0.6, 4 * unit, _mix(const Color(0xFF6E8FB8), const Color(0xFF3A4478), dusk), 0, 1.7);
    layer(185 * unit, 1.0, 10 * unit, _mix(const Color(0xFF2E3F66), const Color(0xFF181D45), dusk), dusk, 0);
  }

  static void city(Canvas c, Size s, double offsetX, double groundY, double unit, double dusk, [double t = 0]) {
    if (skyline != null) return _skyline(c, s, offsetX, groundY, unit, dusk, t);
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
  /// Le fleuve Congo vu d'en haut : une immense eau brune et argentée entre deux rives de forêt,
  /// des îles, des tourbillons, des pirogues et un bateau. [flow] avance avec l'avion, [fade] va de 0 à 1.
  static void river(Canvas c, Size s, double flow, double t, double fade, double unit) {
    if (fade <= 0) return;
    final top = s.height * (1.0 - 0.3 * fade);
    final bank = s.height * 0.045;
    c.save();
    c.clipRect(Rect.fromLTWH(0, top - bank * 2.2, s.width, s.height));
    // Rive nord : la forêt dense, en boules de feuillage sombres.
    for (var i = -1; i < s.width / (22 * unit) + 2; i++) {
      final x = i * 22 * unit - (flow * 0.55) % (22 * unit);
      final n = ((x + flow * 0.55) / (22 * unit)).floor();
      final h = (0.5 + 0.5 * math.sin(n * 1.9)) * bank * 0.9 + bank * 0.9;
      c.drawCircle(
        Offset(x, top - bank * 0.4),
        h * 0.9,
        Paint()..color = Color.lerp(const Color(0xFF0E3A22), const Color(0xFF1C5C34), 0.5 + 0.5 * math.sin(n * 2.7))!,
      );
      // La lumière sur le haut des cimes, comme la canopée vue d'avion.
      c.drawCircle(
        Offset(x - h * 0.25, top - bank * 0.4 - h * 0.35),
        h * 0.42,
        Paint()..color = Color.lerp(const Color(0xFF2E7A40), const Color(0xFF4F9A4A), 0.5 + 0.5 * math.sin(n * 1.3))!,
      );
    }
    // La rive : une bande d'herbe claire au bord de l'eau.
    c.drawRect(Rect.fromLTWH(0, top - bank * 0.25, s.width, bank * 0.3), Paint()..color = const Color(0xFF6E9A4A));
    // L'eau : brune sur les bords, ciel reflété au milieu.
    final water = Rect.fromLTWH(0, top - bank * 0.1, s.width, s.height - top + bank * 0.1);
    c.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B5A3A), Color(0xFF9AA79A), Color(0xFFB4C8CC), Color(0xFF8A8466), Color(0xFF5E5A44)],
          stops: [0, 0.22, 0.5, 0.78, 1],
        ).createShader(water),
    );
    // Un reflet de soleil qui danse sur l'eau.
    for (var i = 0; i < 46; i++) {
      final x = ((i * 97.0 * unit) - flow * 0.8) % (s.width + 60) - 30;
      final y = top + water.height * (0.12 + ((i * 53) % 80) / 100.0);
      final w = (10 + (i * 31) % 26) * unit * (0.6 + 0.4 * math.sin(t * 2.2 + i));
      c.drawLine(
        Offset(x, y),
        Offset(x + w, y),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 1.6 * unit
          ..strokeCap = StrokeCap.round,
      );
    }
    // Des tourbillons de courant.
    final swirl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * unit
      ..color = const Color(0x44D8D2B8);
    for (var i = 0; i < 6; i++) {
      final x = ((i * 410.0 * unit) - flow * 0.7) % (s.width + 200) - 100;
      final y = top + water.height * (0.3 + (i % 3) * 0.22);
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 60 * unit, height: 16 * unit), 0.2, 4.4, false, swirl);
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 34 * unit, height: 8 * unit), 1.4, 4.0, false, swirl);
    }
    // Une île boisée, au milieu du courant.
    final ix = ((900.0 * unit) - flow * 0.9) % (s.width * 1.6) - s.width * 0.2;
    final iy = top + water.height * 0.48;
    c.drawOval(
      Rect.fromCenter(center: Offset(ix, iy), width: 210 * unit, height: 30 * unit),
      Paint()..color = const Color(0xFFB7A777),
    );
    for (var k = -3; k <= 3; k++) {
      final r = (11 + (k * k * 3 + k + 3) % 7) * unit;
      final at = Offset(ix + k * 25 * unit, iy - 6 * unit - r * 0.3);
      c.drawCircle(at, r, Paint()..color = k.isEven ? const Color(0xFF1A5A32) : const Color(0xFF226B3C));
      c.drawCircle(at.translate(-r * 0.25, -r * 0.35), r * 0.45, Paint()..color = const Color(0xFF3F8A48));
    }
    // Le courant : de longues stries claires qui filent avec l'eau, même quand l'avion ralentit.
    final current = Paint()
      ..strokeWidth = 1.3 * unit
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 28; i++) {
      final w = (40 + (i * 37) % 70) * unit;
      final x = ((i * 131.0 * unit) - flow * 0.75 - t * 26 * unit) % (s.width + w + 40) - w;
      final y = top + water.height * (0.08 + ((i * 41) % 88) / 100.0);
      c.drawLine(Offset(x, y), Offset(x + w, y), current..color = Color.fromRGBO(240, 236, 220, 0.12 + (i % 3) * 0.05));
    }
    // Un bateau du fleuve : le pousseur et sa barge chargée, comme ceux qui descendent vers Kinshasa.
    final bx = ((1500.0 * unit) - flow * 0.6 - t * 6 * unit) % (s.width * 1.5) - s.width * 0.25;
    riverBoat(c, Offset(bx, top + water.height * 0.62), unit * 1.25, t);
    // Les pirogues, chacune avec son piroguier debout qui pousse sur sa perche.
    for (var i = 0; i < 3; i++) {
      final x = ((i * 760.0 + 300) * unit - flow * 0.95) % (s.width + 300) - 150;
      final y = top + water.height * (0.3 + i * 0.25) + math.sin(t * 1.3 + i) * 1.2 * unit;
      pirogue(c, Offset(x, y), (120 - i * 16) * unit, t + i * 1.7, cargo: i != 1);
    }
    // Rive sud.
    for (var i = -1; i < s.width / (26 * unit) + 2; i++) {
      final x = i * 26 * unit - (flow * 1.1) % (26 * unit);
      final n = ((x + flow * 1.1) / (26 * unit)).floor();
      c.drawCircle(
        Offset(x, s.height + 2 * unit),
        (10 + (n * 7) % 9) * unit,
        Paint()..color = Color.lerp(const Color(0xFF0E3A22), const Color(0xFF226B3C), 0.5 + 0.5 * math.sin(n * 3.1))!,
      );
    }
    c.restore();
    // Brume légère au-dessus de l'eau.
    c.drawRect(
      Rect.fromLTWH(0, top - bank * 2, s.width, bank * 2),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00DCE8F0), Color(0x55DCE8F0)],
        ).createShader(Rect.fromLTWH(0, top - bank * 2, s.width, bank * 2)),
    );
  }

  /// Une pirogue du fleuve, vue de côté : une coque longue et basse taillée dans un tronc, peinte de motifs,
  /// et le piroguier debout à l'arrière qui pousse sur sa longue perche. [at] est le milieu de la ligne d'eau.
  static void pirogue(Canvas c, Offset at, double len, double t, {bool cargo = true}) {
    final x = at.dx, y = at.dy, l = len;
    final hull = Path()
      ..moveTo(x - l * 0.5, y - l * 0.05)
      ..quadraticBezierTo(x - l * 0.44, y + l * 0.035, x - l * 0.3, y + l * 0.04)
      ..lineTo(x + l * 0.32, y + l * 0.04)
      ..quadraticBezierTo(x + l * 0.46, y + l * 0.03, x + l * 0.52, y - l * 0.07)
      ..lineTo(x + l * 0.44, y - l * 0.02)
      ..lineTo(x - l * 0.42, y - l * 0.02)
      ..close();
    // Le reflet dans l'eau, sombre et tremblant.
    c.drawPath(
      Path()
        ..moveTo(x - l * 0.46, y + l * 0.04)
        ..lineTo(x + l * 0.46, y + l * 0.04)
        ..lineTo(x + l * 0.4, y + l * 0.09)
        ..lineTo(x - l * 0.4, y + l * 0.09)
        ..close(),
      Paint()..color = const Color(0x332A2018),
    );
    c.drawPath(hull, Paint()..color = const Color(0xFF2B2622));
    // Les motifs peints sur la coque : des taches mauves et blanches.
    c.save();
    c.clipPath(hull);
    for (var k = 0; k < 9; k++) {
      final px = x - l * 0.38 + k * l * 0.095;
      c.drawCircle(
        Offset(px, y + l * 0.012),
        l * (0.018 + (k % 3) * 0.006),
        Paint()..color = k.isEven ? const Color(0xFFB58CC0) : const Color(0xFFE6DCE8),
      );
    }
    c.drawRect(
      Rect.fromLTRB(x - l * 0.5, y - l * 0.024, x + l * 0.5, y - l * 0.014),
      Paint()..color = const Color(0xFF5A4C6A),
    );
    c.restore();
    if (cargo) {
      // Des sacs et un régime de bananes à l'avant.
      c.drawOval(
        Rect.fromCenter(center: Offset(x + l * 0.22, y - l * 0.04), width: l * 0.12, height: l * 0.05),
        Paint()..color = const Color(0xFFCDB991),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(x + l * 0.32, y - l * 0.045), width: l * 0.08, height: l * 0.05),
        Paint()..color = const Color(0xFF8DA53A),
      );
    }
    // Le piroguier : debout à l'arrière, il pousse et la perche glisse dans le courant.
    final push = math.sin(t * 1.4);
    final mx = x - l * 0.26;
    final foot = y - l * 0.02;
    final skin = Paint()..color = const Color(0xFF3A2416);
    final legs = Paint()
      ..color = const Color(0xFF2A221C)
      ..strokeWidth = l * 0.02
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(mx - l * 0.012, foot), Offset(mx - l * 0.006, foot - l * 0.09), legs);
    c.drawLine(Offset(mx + l * 0.014, foot), Offset(mx + l * 0.006, foot - l * 0.09), legs);
    // Le short clair et la chemise.
    c.drawRect(
      Rect.fromLTRB(mx - l * 0.02, foot - l * 0.11, mx + l * 0.022, foot - l * 0.075),
      Paint()..color = const Color(0xFFE4E0D6),
    );
    final lean = push * l * 0.01;
    c.drawPath(
      Path()
        ..moveTo(mx - l * 0.022, foot - l * 0.11)
        ..lineTo(mx + l * 0.024, foot - l * 0.11)
        ..lineTo(mx + l * 0.022 + lean, foot - l * 0.2)
        ..lineTo(mx - l * 0.02 + lean, foot - l * 0.2)
        ..close(),
      Paint()..color = const Color(0xFF9C8A74),
    );
    final head = Offset(mx + lean + l * 0.002, foot - l * 0.225);
    c.drawCircle(head, l * 0.018, skin);
    // La casquette blanche.
    c.drawArc(
      Rect.fromCircle(center: head.translate(0, -l * 0.004), radius: l * 0.019),
      math.pi,
      math.pi,
      true,
      Paint()..color = Colors.white,
    );
    c.drawLine(
      head.translate(0, -l * 0.004),
      head.translate(l * 0.03, -l * 0.002),
      Paint()
        ..color = Colors.white
        ..strokeWidth = l * 0.006,
    );
    // La perche : du dessus de sa tête, à droite, jusque dans l'eau derrière la pirogue.
    final top = Offset(mx + l * 0.16 + push * l * 0.03, foot - l * 0.33);
    final water = Offset(mx - l * 0.3 + push * l * 0.05, y + l * 0.03);
    c.drawLine(
      top,
      water,
      Paint()
        ..color = const Color(0xFF6B5638)
        ..strokeWidth = l * 0.008
        ..strokeCap = StrokeCap.round,
    );
    final hands = Offset.lerp(top, water, 0.28)!;
    c.drawLine(Offset(mx + lean, foot - l * 0.18), hands, legs..strokeWidth = l * 0.014);
    // Les ronds dans l'eau où la perche entre.
    c.drawOval(
      Rect.fromCenter(center: water, width: l * (0.08 + 0.03 * (1 + push)), height: l * 0.018),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l * 0.004
        ..color = const Color(0x66FFFFFF),
    );
  }

  /// Un bateau du fleuve Congo : le pousseur à deux ponts, sa timonerie et sa cheminée qui fume,
  /// devant lui une barge chargée de bâches, de sacs et de passagers.
  static void riverBoat(Canvas c, Offset at, double u, double t) {
    final x = at.dx, y = at.dy;
    // Le sillage blanc derrière.
    c.drawPath(
      Path()
        ..moveTo(x, y + 2 * u)
        ..lineTo(x - 140 * u, y - 4 * u)
        ..lineTo(x - 140 * u, y + 14 * u)
        ..close(),
      Paint()..color = const Color(0x2EFFFFFF),
    );
    // Le pousseur : une coque bleue, deux ponts blancs aux fenêtres sombres.
    final hull = Path()
      ..moveTo(x, y - 8 * u)
      ..lineTo(x + 70 * u, y - 8 * u)
      ..lineTo(x + 70 * u, y + 4 * u)
      ..lineTo(x + 6 * u, y + 4 * u)
      ..close();
    c.drawPath(hull, Paint()..color = const Color(0xFF1F4E7A));
    c.drawRect(Rect.fromLTWH(x, y - 9.5 * u, 70 * u, 1.6 * u), Paint()..color = const Color(0xFF8E3A2A));
    final white = Paint()..color = const Color(0xFFECEDEA);
    final glass = Paint()..color = const Color(0xFF2B3440);
    c.drawRect(Rect.fromLTWH(x + 6 * u, y - 21 * u, 60 * u, 12 * u), white);
    c.drawRect(Rect.fromLTWH(x + 14 * u, y - 31 * u, 42 * u, 10 * u), white);
    for (var k = 0; k < 9; k++) {
      c.drawRect(Rect.fromLTWH(x + 9 * u + k * 6.4 * u, y - 18 * u, 4 * u, 4 * u), glass);
    }
    for (var k = 0; k < 5; k++) {
      c.drawRect(Rect.fromLTWH(x + 18 * u + k * 7.4 * u, y - 28 * u, 5 * u, 4 * u), glass);
    }
    // La timonerie, en haut, et le petit drapeau du pays.
    c.drawRect(Rect.fromLTWH(x + 26 * u, y - 39 * u, 18 * u, 8 * u), white);
    c.drawRect(Rect.fromLTWH(x + 28 * u, y - 37 * u, 14 * u, 3.5 * u), glass);
    c.drawLine(
      Offset(x + 40 * u, y - 39 * u),
      Offset(x + 40 * u, y - 50 * u),
      Paint()
        ..color = const Color(0xFF333333)
        ..strokeWidth = 0.8 * u,
    );
    c.drawRect(Rect.fromLTWH(x + 40 * u, y - 50 * u, 8 * u, 5 * u), Paint()..color = ChachaColors.sky);
    c.drawPath(FlagPainter.starPath(Offset(x + 42 * u, y - 48.6 * u), 1.2 * u), Paint()..color = ChachaColors.yellow);
    // La cheminée et sa fumée qui s'en va derrière.
    c.drawRect(Rect.fromLTWH(x + 12 * u, y - 40 * u, 6 * u, 10 * u), Paint()..color = const Color(0xFF222222));
    for (var k = 0; k < 4; k++) {
      final age = (t * 0.6 + k / 4) % 1;
      c.drawCircle(
        Offset(x + 15 * u - age * 50 * u, y - 44 * u - age * 14 * u),
        (3 + age * 7) * u,
        Paint()..color = Color.fromRGBO(90, 90, 90, 0.35 * (1 - age)),
      );
    }
    // La barge devant : coque rouillée, bâches de couleur, sacs, et des passagers assis.
    final bx = x + 72 * u;
    c.drawPath(
      Path()
        ..moveTo(bx, y - 6 * u)
        ..lineTo(bx + 120 * u, y - 6 * u)
        ..lineTo(bx + 112 * u, y + 4 * u)
        ..lineTo(bx, y + 4 * u)
        ..close(),
      Paint()..color = const Color(0xFF5A4636),
    );
    const tarps = [Color(0xFF2F6DB5), Color(0xFFE08A2E), Color(0xFFD8C14A), Color(0xFF8E2F2F), Color(0xFF3E8E5A)];
    for (var k = 0; k < 7; k++) {
      final w = (12 + (k * 5) % 8) * u;
      final h = (6 + (k * 3) % 6) * u;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx + 4 * u + k * 16 * u, y - 6 * u - h, w, h), Radius.circular(2 * u)),
        Paint()..color = tarps[k % tarps.length],
      );
    }
    for (var k = 0; k < 10; k++) {
      final px = bx + 8 * u + k * 11 * u;
      c.drawCircle(Offset(px, y - 15 * u - (k % 3) * 2 * u), 1.6 * u, Paint()..color = const Color(0xFF2A1A10));
    }
  }

  /// Un ballon de football qui tourne : il apporte un peu de kérosène et d'entretien.
  static void football(Canvas c, Offset at, double r, double t) {
    c.drawCircle(
      at,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromCircle(center: at, radius: r * 1.9)),
    );
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(t * 2.4);
    c.drawCircle(Offset.zero, r, Paint()..color = Colors.white);
    final dark = Paint()..color = const Color(0xFF1B1B1F);
    Path pentagon(Offset o, double s) {
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 5;
        final pt = o + Offset(math.cos(a), math.sin(a)) * s;
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return path..close();
    }

    c.drawPath(pentagon(Offset.zero, r * 0.38), dark);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final o = Offset(math.cos(a), math.sin(a)) * r * 0.86;
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
      c.drawPath(pentagon(o, r * 0.3), dark);
      c.restore();
    }
    c.restore();
    c.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = const Color(0xFF8A8A92),
    );
  }

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

  /// Kisangani : les rapides des chutes Wagenia, les échafaudages de bois et leurs grandes nasses coniques.
  static void wagenia(Canvas c, Offset base, double u, double t) {
    Paint stroke(Color color, double w) => Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Les rapides : l'eau brune du fleuve qui dévale, blanche d'écume
    final water = Rect.fromLTRB(base.dx - 230 * u, base.dy - 30 * u, base.dx + 230 * u, base.dy + 2 * u);
    final river = Path()..moveTo(water.left, water.bottom);
    for (var i = 0; i <= 46; i++) {
      final x = water.left + water.width * i / 46;
      final edge = math.sin(i / 46 * math.pi);
      river.lineTo(x, water.bottom - (water.height * (0.55 + 0.45 * edge)) - math.sin(i * 1.9 + t * 3) * 2.4 * u);
    }
    river
      ..lineTo(water.right, water.bottom)
      ..close();
    c.drawPath(
      river,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4F6F2), Color(0xFFBFD3D9), Color(0xFF8C8A63)],
        ).createShader(water),
    );
    for (var i = 0; i < 22; i++) {
      final x = water.left + 20 * u + ((i * 47 + t * 42) % 420) * u;
      final y = water.top + (7 + (i * 7) % 20) * u;
      c.drawArc(
        Rect.fromCenter(center: Offset(x, y), width: 24 * u, height: 9 * u),
        math.pi,
        math.pi,
        false,
        stroke(const Color(0xEEFFFFFF), 2.4 * u),
      );
    }
    for (final (dx, w) in const [
      (-222.0, 52.0),
      (-150.0, 30.0),
      (-60.0, 22.0),
      (95.0, 34.0),
      (160.0, 20.0),
      (224.0, 56.0),
    ]) {
      c.drawOval(
        Rect.fromCenter(center: base.translate(dx * u, -13 * u), width: w * u, height: w * 0.6 * u),
        Paint()..color = const Color(0xFF3F362C),
      );
    }
    // L'échafaudage : des troncs plantés dans les rochers, liés par des lianes
    const wood = Color(0xFF6B4A2B), woodDark = Color(0xFF4B321C);
    final posts = <(Offset, Offset)>[
      (base.translate(-128 * u, -8 * u), base.translate(-112 * u, -112 * u)),
      (base.translate(-52 * u, -8 * u), base.translate(-60 * u, -120 * u)),
      (base.translate(28 * u, -8 * u), base.translate(20 * u, -116 * u)),
      (base.translate(112 * u, -8 * u), base.translate(100 * u, -108 * u)),
      (base.translate(-96 * u, -8 * u), base.translate(-70 * u, -92 * u)),
      (base.translate(70 * u, -8 * u), base.translate(40 * u, -96 * u)),
    ];
    for (final (a, b) in posts) {
      c.drawLine(a, b, stroke(woodDark, 4.2 * u));
      c.drawLine(a, b, stroke(wood, 2.6 * u));
    }
    final beamA = base.translate(-140 * u, -86 * u), beamB = base.translate(128 * u, -80 * u);
    c.drawLine(beamA, beamB, stroke(woodDark, 4.6 * u));
    c.drawLine(beamA, beamB, stroke(wood, 3 * u));
    c.drawLine(base.translate(-120 * u, -58 * u), base.translate(110 * u, -54 * u), stroke(wood, 2.4 * u));
    // Les nasses : de grands cônes de lianes tressées, la gueule face au courant
    for (final (dx, len, sway) in const [(-92.0, 84.0, 0.0), (-10.0, 96.0, 1.3), (72.0, 80.0, 2.4)]) {
      final top = Offset.lerp(beamA, beamB, (dx + 140) / 268)!;
      final swing = math.sin(t * 1.2 + sway) * 3 * u;
      final mouth = top.translate(swing, 34 * u);
      final tip = mouth.translate(len * 0.75 * u + swing, len * 0.45 * u);
      c.drawLine(top, mouth.translate(0, -13 * u), stroke(const Color(0xFF3B2A18), 1.4 * u));
      final ring = Rect.fromCenter(center: mouth, width: 12 * u, height: 30 * u);
      for (var k = 0; k <= 6; k++) {
        final a = -math.pi / 2 + math.pi * k / 6;
        final edge = mouth + Offset(math.cos(a) * 6 * u * (k == 0 || k == 6 ? 0 : 1), math.sin(a) * 15 * u);
        c.drawLine(edge, tip, stroke(const Color(0xFFE0BE82), 1.5 * u));
      }
      for (final f in const [0.3, 0.55, 0.78]) {
        final p = Offset.lerp(mouth, tip, f)!;
        c.drawOval(
          Rect.fromCenter(center: p, width: 10 * u * (1 - f), height: 30 * u * (1 - f)),
          stroke(const Color(0xFFB8935A), 1.3 * u),
        );
      }
      c.drawOval(ring, stroke(const Color(0xFF8A6A3C), 2.2 * u));
    }
    // Les pêcheurs, en équilibre sur la poutre
    for (final (f, sit) in const [(0.2, false), (0.55, true), (0.86, false)]) {
      final feet = Offset.lerp(beamA, beamB, f)!.translate(0, -2 * u);
      const skin = Color(0xFF5E3A22);
      if (sit) {
        c.drawLine(feet.translate(0, -1 * u), feet.translate(5 * u, 9 * u), stroke(skin, 2.6 * u));
        c.drawLine(feet.translate(0, -2 * u), feet.translate(-1 * u, -15 * u), stroke(skin, 4.4 * u));
        c.drawCircle(feet.translate(-1 * u, -20 * u), 3.4 * u, Paint()..color = skin);
        c.drawLine(
          feet.translate(-3 * u, -4 * u),
          feet.translate(3 * u, -4 * u),
          stroke(const Color(0xFF2E7D5B), 4 * u),
        );
      } else {
        c.drawLine(feet, feet.translate(-2 * u, -12 * u), stroke(skin, 2.6 * u));
        c.drawLine(feet.translate(4 * u, 0), feet.translate(1 * u, -12 * u), stroke(skin, 2.6 * u));
        c.drawLine(feet.translate(0, -12 * u), feet.translate(-1 * u, -26 * u), stroke(skin, 4.6 * u));
        c.drawLine(
          feet.translate(-3 * u, -13 * u),
          feet.translate(3 * u, -13 * u),
          stroke(const Color(0xFF1D5FB8), 4.4 * u),
        );
        c.drawLine(feet.translate(-1 * u, -24 * u), feet.translate(9 * u, -14 * u), stroke(skin, 2.2 * u));
        c.drawCircle(feet.translate(-1 * u, -31 * u), 3.4 * u, Paint()..color = skin);
      }
    }
  }

  /// Lubumbashi : la grande cheminée de brique et le terril noir de la Gécamines, les pylônes, les ateliers.
  static void gecamines(Canvas c, Offset base, double u, double t) {
    // Le terril : un cône noir de scories, aplati au sommet
    final heap = Path()
      ..moveTo(base.dx - 60 * u, base.dy)
      ..lineTo(base.dx + 62 * u, base.dy - 118 * u)
      ..lineTo(base.dx + 96 * u, base.dy - 118 * u)
      ..lineTo(base.dx + 250 * u, base.dy)
      ..close();
    final bounds = Rect.fromLTRB(base.dx - 60 * u, base.dy - 118 * u, base.dx + 250 * u, base.dy);
    c.drawPath(
      heap,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF3A4654), Color(0xFF1C232D), Color(0xFF10151C)],
        ).createShader(bounds),
    );
    c.save();
    c.clipPath(heap);
    for (var i = 0; i < 9; i++) {
      final x = base.dx + (70 + i * 6) * u;
      c.drawLine(
        Offset(x, base.dy - 118 * u),
        Offset(x - (130 - i * 34) * u, base.dy),
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..strokeWidth = 1.2 * u,
      );
    }
    c.restore();
    c.drawRect(
      Rect.fromLTWH(base.dx + 70 * u, base.dy - 127 * u, 16 * u, 9 * u),
      Paint()..color = const Color(0xFF55606E),
    );
    // Les ateliers
    for (final (dx, w, h) in const [(-150.0, 70.0, 20.0), (-70.0, 90.0, 28.0), (30.0, 60.0, 18.0)]) {
      final r = Rect.fromLTWH(base.dx + dx * u, base.dy - h * u, w * u, h * u);
      c.drawRect(r, Paint()..color = const Color(0xFF5B4A44));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 4 * u), Paint()..color = const Color(0xFF8B8F96));
      for (var k = 1; k < 5; k++) {
        c.drawRect(
          Rect.fromLTWH(r.left + r.width * k / 5 - 2 * u, r.top + 8 * u, 4 * u, 5 * u),
          Paint()..color = const Color(0xFFE9D9A0),
        );
      }
    }
    // La fumée, poussée par le vent
    for (var i = 0; i < 6; i++) {
      final k = ((t * 0.16 + i / 6) % 1);
      c.drawCircle(
        Offset(base.dx - 96 * u + k * 80 * u, base.dy - 196 * u - k * 26 * u),
        (7 + k * 16) * u,
        Paint()..color = Color.fromRGBO(225, 228, 232, 0.5 * (1 - k)),
      );
    }
    // La cheminée de brique, cerclée de fer
    final stack = Path()
      ..moveTo(base.dx - 106 * u, base.dy)
      ..lineTo(base.dx - 101 * u, base.dy - 190 * u)
      ..lineTo(base.dx - 91 * u, base.dy - 190 * u)
      ..lineTo(base.dx - 86 * u, base.dy)
      ..close();
    final sb = Rect.fromLTRB(base.dx - 106 * u, base.dy - 190 * u, base.dx - 86 * u, base.dy);
    c.drawPath(
      stack,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB0795C), Color(0xFF8A5A44), Color(0xFF5E3B2D)],
        ).createShader(sb),
    );
    c.drawRect(
      Rect.fromLTWH(base.dx - 102.5 * u, base.dy - 196 * u, 13 * u, 7 * u),
      Paint()..color = const Color(0xFF4A2E24),
    );
    for (var k = 1; k < 9; k++) {
      final y = base.dy - 190 * u * k / 9;
      c.drawLine(
        Offset(base.dx - 105 * u, y),
        Offset(base.dx - 87 * u, y),
        Paint()
          ..color = const Color(0x55301A12)
          ..strokeWidth = 1.2 * u,
      );
    }
    final small = Rect.fromLTWH(base.dx - 172 * u, base.dy - 70 * u, 9 * u, 70 * u);
    c.drawRect(small, Paint()..color = const Color(0xFF7A5243));
    // Les pylônes de la ligne à haute tension
    final steel = Paint()
      ..color = const Color(0xFF9AA3AE)
      ..strokeWidth = 1.3 * u
      ..strokeCap = StrokeCap.round;
    final tops = <Offset>[];
    for (final (dx, h) in const [(10.0, 96.0), (190.0, 84.0)]) {
      final foot = base.translate(dx * u, 0), top = foot.translate(0, -h * u);
      tops.add(top);
      c.drawLine(foot.translate(-9 * u, 0), top.translate(-2 * u, 0), steel);
      c.drawLine(foot.translate(9 * u, 0), top.translate(2 * u, 0), steel);
      for (var k = 0; k < 6; k++) {
        final y0 = h * u * k / 6, y1 = h * u * (k + 1) / 6;
        final w0 = 9 * u * (1 - k / 6) + 2 * u * k / 6, w1 = 9 * u * (1 - (k + 1) / 6) + 2 * u * (k + 1) / 6;
        c.drawLine(foot.translate(-w0, -y0), foot.translate(w1, -y1), steel);
        c.drawLine(foot.translate(w0, -y0), foot.translate(-w1, -y1), steel);
      }
      for (final f in const [0.72, 0.9]) {
        c.drawLine(foot.translate(-15 * u, -h * u * f), foot.translate(15 * u, -h * u * f), steel);
      }
    }
    final wire = Paint()
      ..color = const Color(0x99D8DDE3)
      ..strokeWidth = 0.8 * u
      ..style = PaintingStyle.stroke;
    for (final side in const [-15.0, 15.0]) {
      final a = tops[0].translate(side * u, 10 * u), b = tops[1].translate(side * u, 9 * u);
      c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + 16 * u, b.dx, b.dy),
        wire,
      );
    }
  }
}
