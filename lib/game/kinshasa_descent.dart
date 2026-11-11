import 'dart:math' as math;

import 'package:flutter/material.dart';

/// L'arrivée sur Kinshasa, vue d'en haut, avant la piste : le stade, le boulevard Lumumba et ses taxis jaunes,
/// la passerelle et le saut-de-mouton, puis l'aéroport de N'djili et sa tour orange. Ensuite le tarmac habituel.
///
/// Chaque chose n'apparaît qu'à partir de son année : le stade des Martyrs en 1994, les passerelles du boulevard
/// en 2015, l'aérogare et la tour orange de N'djili en juin 2015, les sauts-de-mouton en 2020.
abstract final class KinshasaDescent {
  /// Le survol dure ce temps, puis l'avion fait sa descente ordinaire vers la piste.
  static const seconds = 15.0;

  static const martyrsFrom = 1994.7, boardsFrom = 2010.0, footbridgeFrom = 2015.0, terminalFrom = 2015.48;
  static const flyoverFrom = 2020.0, yellowFrom = 2008.0;

  /// Ce que dit la tour en survolant le stade, puis le boulevard, puis l'aéroport.
  static String stadiumLine(double year) => switch (year) {
    < 1967.4 => 'Voici le stade Roi Baudouin : vous êtes à Léopoldville.',
    < martyrsFrom => 'Voici le stade du 20 Mai : vous êtes à Kinshasa.',
    < 1997.38 => 'Voici le stade Kamanyola, tout neuf : vous êtes à Kinshasa.',
    _ => 'Voici le stade des Martyrs : vous êtes à Kinshasa.',
  };

  static String roadLine(double year) => switch (year) {
    < 1966.5 => 'En bas, la route de l\'aéroport et ses marchés.',
    < footbridgeFrom => 'En bas, le boulevard Lumumba, ses taxis et ses marchés.',
    < flyoverFrom => 'En bas, le boulevard Lumumba, ses taxis jaunes et la passerelle de Kingasani.',
    _ => 'En bas, le boulevard Lumumba, ses taxis jaunes, la passerelle de Kingasani et le saut-de-mouton.',
  };

  static String airportLine(double year) => year < terminalFrom
      ? 'Voici l\'aéroport de N\'djili. Train sorti.'
      : 'Voici l\'aéroport de N\'djili et sa tour orange. Train sorti.';

  // Le parcours, en unités du sol (environ 250 m) devant le point de départ de la caméra.
  static const _travel = 11.3, _far = 15.0;
  static const _stadiumX = 0.5, _stadiumZ = 2.7, _stadiumA = 0.56, _stadiumB = 0.4;
  static const _roadX = -0.26, _roadHalf = 0.085, _roadFrom = 0.6, _roadTo = 11.9;
  static const _marketFrom = 5.3, _marketTo = 9.9, _footbridgeZ = 6.2;
  static const _flyFrom = 7.3, _flyTo = 9.4, _crossZ = 8.35;
  static const _runwayX = -0.02, _runwayFrom = 12.25, _runwayHalf = 0.1;
  static const _towerX = 0.55, _towerZ = 12.36;

  static const _haze = Color(0xFFB9C9D3);
  static const _roofs = [
    Color(0xFFB5583A),
    Color(0xFFC8C4BA),
    Color(0xFF9C4A30),
    Color(0xFFE0DCD2),
    Color(0xFF7FA4BF),
    Color(0xFFA9A49A),
    Color(0xFFC77B4A),
    Color(0xFF8E3F2C),
  ];

  static double _rnd(double a, double b) {
    final v = math.sin(a * 127.1 + b * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// [k] : où en est le survol, de 0 (le stade au loin) à 1 (la piste sous l'avion).
  static void draw(Canvas c, Size s, double k, double t, double fade, double year, double dusk) {
    if (fade <= 0) return;
    final w = s.width, h = s.height;
    c.saveLayer(Offset.zero & s, Paint()..color = Color.fromRGBO(255, 255, 255, fade.clamp(0.0, 1.0)));
    final y0 = h * 0.3;
    final cam = k.clamp(0.0, 1.0) * _travel;
    // L'avion descend : la caméra se rapproche du sol, la ville grandit.
    final height = 1 - 0.3 * Curves.easeIn.transform(k.clamp(0.0, 1.0));
    final span = (h * 1.05 - y0) * height, f = w * 0.62;

    double depth(double z) => math.max(z - cam, 0.12);
    Offset p(double x, double z, [double e = 0]) {
      final d = depth(z);
      return Offset(w * 0.5 + x * f / d, y0 + span / d - e * f / d);
    }

    double mist(double z) => math.pow(((depth(z) - 1.4) / (_far - 1.4)).clamp(0.0, 1.0), 0.8) * 0.85;
    Color tint(Color color, double z) => Color.lerp(color, _haze, mist(z))!;
    Paint paint(Color color, double z) => Paint()..color = tint(color, z);
    void quad(List<Offset> pts, Paint pt) => c.drawPath(Path()..addPolygon(pts, true), pt);
    void flat(double x0, double x1, double z0, double z1, Color color, {double e = 0}) {
      final za = math.max(z0, cam + 0.12), zb = math.min(z1, cam + _far);
      if (za >= zb) return;
      quad([p(x0, za, e), p(x1, za, e), p(x1, zb, e), p(x0, zb, e)], paint(color, (za + zb) / 2));
    }

    // Le ciel au loin, le fleuve Congo à l'horizon, Brazzaville au-delà.
    c.drawRect(
      Rect.fromLTRB(0, y0 - h * 0.12, w, y0 + 2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_haze.withValues(alpha: 0), _haze],
        ).createShader(Rect.fromLTRB(0, y0 - h * 0.12, w, y0 + 2)),
    );
    final hills = Path()..moveTo(0, y0 - h * 0.01);
    for (var i = 0; i <= 30; i++) {
      hills.lineTo(w * i / 30, y0 - h * (0.012 + 0.016 * (0.5 + 0.5 * math.sin(i * 1.3))));
    }
    hills
      ..lineTo(w, y0)
      ..lineTo(0, y0)
      ..close();
    c.drawPath(hills, Paint()..color = const Color(0xFF9DAEBB));
    c.drawRect(Rect.fromLTRB(0, y0 - h * 0.006, w, y0 + h * 0.012), Paint()..color = const Color(0xFF9FB6C2));
    // Le sol de la ville.
    c.drawRect(
      Rect.fromLTRB(0, y0 + h * 0.012, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFAFBDB4), Color(0xFF9DAA88), Color(0xFF8C956A)],
          stops: [0, 0.3, 1],
        ).createShader(Rect.fromLTRB(0, y0, w, h)),
    );

    // L'herbe le long de la piste.
    flat(_runwayX - 0.22, _runwayX + 0.2, _runwayFrom - 0.15, cam + _far, const Color(0xFF8FA36A));

    final martyrs = year >= martyrsFrom;
    final ra = martyrs ? _stadiumA : _stadiumA * 0.78, rb = martyrs ? _stadiumB : _stadiumB * 0.78;
    bool reserved(double x, double z, double margin) {
      final sx = (x - _stadiumX) / (ra + margin), sz = (z - _stadiumZ) / (rb + margin);
      if (sx * sx + sz * sz < 1.25) return true;
      if (z > _roadFrom && z < _roadTo + 0.3 && (x - _roadX).abs() < _roadHalf + 0.1 + margin) return true;
      if (z > _crossZ - 0.05 - margin && z < _crossZ + 0.05 + margin && x < _roadX + 0.2) return true;
      // L'aéroport : la piste, le parking des avions, l'aérogare, les hangars. Les quartiers l'entourent.
      if (z > _runwayFrom - 0.7 - margin && (x - _runwayX).abs() < 0.22 + margin) return true;
      return z > 11.75 - margin && z < 13.15 + margin && x > 0.08 - margin && x < 1.45 + margin;
    }

    // Les quartiers : des rangées de toits de tôle et de dalles, des manguiers. Plus loin, des blocs plus grands.
    for (final (z0, z1, step) in const [(0.3, 2.4, 0.16), (2.4, 4.8, 0.32), (4.8, 9.6, 0.64), (9.6, 19.2, 1.28)]) {
      for (var z = ((cam + z0) / step).ceil() * step; z < math.min(cam + z1, cam + _far); z += step) {
        final d = depth(z), xMax = d * w * 0.55 / f + step;
        for (var x = (-xMax / step).floor() * step; x < xMax; x += step) {
          final r1 = _rnd(x, z), r2 = _rnd(z, x + 3), cx = x + (r1 - 0.5) * step * 0.3;
          if (reserved(cx, z, step * 0.3)) continue;
          final size = step * (0.74 + 0.22 * r2);
          final a = p(cx - size / 2, z + size * 0.35), b = p(cx + size / 2, z - size * 0.35);
          final rect = Rect.fromPoints(a, b);
          if (r1 < 0.16) {
            c.drawOval(rect, paint(r2 < 0.5 ? const Color(0xFF2F6B35) : const Color(0xFF4A8A3C), z));
            continue;
          }
          c.drawRect(rect.translate(0, rect.height * 0.25), paint(const Color(0xFFD8CDB8), z));
          c.drawRect(rect, paint(_roofs[(r2 * _roofs.length).floor() % _roofs.length], z));
        }
      }
    }

    // Le boulevard, la rue qui le croise sous le saut-de-mouton, et la route de l'aérogare.
    flat(-2.5, _roadX, _crossZ - 0.035, _crossZ + 0.035, const Color(0xFF7A7D80));
    flat(_roadX - _roadHalf, _roadX + _roadHalf, _roadFrom, _roadTo, const Color(0xFF6E7175));
    flat(_roadX, _towerX, 11.82, 11.9, const Color(0xFF7A7D80));
    flat(_roadX - 0.006, _roadX + 0.006, _roadFrom, _roadTo, const Color(0xFFC9C3B6), e: 0.001);
    // Les lignes des voies.
    for (var z = (cam / 0.12).ceil() * 0.12; z < math.min(_roadTo, cam + 7); z += 0.12) {
      if (z < _roadFrom) continue;
      for (final side in const [-0.5, 0.5]) {
        final x = _roadX + side * _roadHalf;
        c.drawLine(
          p(x, z),
          p(x, z + 0.05),
          Paint()
            ..color = tint(Colors.white, z).withValues(alpha: 0.8)
            ..strokeWidth = math.max(0.6, 0.004 * f / depth(z)),
        );
      }
    }
    final flyover = year >= flyoverFrom;
    double rise(double z) {
      if (!flyover || z < _flyFrom || z > _flyTo) return 0;
      final up = ((z - _flyFrom) / 0.55).clamp(0.0, 1.0), down = ((_flyTo - z) / 0.55).clamp(0.0, 1.0);
      return 0.055 * Curves.easeInOut.transform(math.min(up, down));
    }

    // Les taxis et les taxis-bus : jaunes depuis la fin des années 2000, de toutes les couleurs avant.
    // Ceux des voies du milieu montent sur le saut-de-mouton.
    void vehicles({required bool upper}) {
      for (var i = 0; i < 120; i++) {
        final lane = const [-0.8, -0.32, 0.32, 0.8][i % 4];
        final inner = lane.abs() < 0.5;
        final dir = lane < 0 ? -1.0 : 1.0;
        final len = _roadTo - _roadFrom;
        final z = _roadFrom + ((i * 0.37 + _rnd(i.toDouble(), 2) * 0.2 + dir * t * 0.05) % len + len) % len;
        final e = inner ? rise(z) : 0.0;
        if ((e > 0) != upper) continue;
        if (z < cam + 0.15 || z > cam + 6) continue;
        final r = _rnd(i.toDouble(), 5);
        final bus = r < 0.6;
        final Color body = year >= yellowFrom
            ? (r < 0.84 ? const Color(0xFFF6C800) : const Color(0xFFF2F2F2))
            : const [Color(0xFFF2F2F2), Color(0xFF3B6FB6), Color(0xFFC0392B), Color(0xFFD9C9A3)][(r * 4).floor()];
        final x = _roadX + lane * _roadHalf, half = bus ? 0.013 : 0.01, l = bus ? 0.055 : 0.036;
        final a = p(x - half, z - l / 2, e + 0.005), b = p(x + half, z + l / 2, e + 0.005);
        final rect = Rect.fromPoints(a, b);
        c.drawRect(rect.translate(0, rect.height * 0.22), paint(const Color(0xFF2A2A2A), z));
        c.drawRect(rect, paint(body, z));
        // Le pare-brise, et le toit blanc des taxis-bus.
        c.drawRect(
          Rect.fromLTRB(rect.left, rect.top + rect.height * 0.12, rect.right, rect.top + rect.height * 0.3),
          paint(const Color(0xFF263238), z),
        );
        if (bus) {
          c.drawRect(
            Rect.fromLTRB(
              rect.left + rect.width * 0.15,
              rect.top + rect.height * 0.4,
              rect.right - rect.width * 0.15,
              rect.bottom - rect.height * 0.1,
            ),
            paint(Color.lerp(body, Colors.white, 0.35)!, z),
          );
        }
      }
    }

    // Du plus loin au plus proche : l'aéroport, le saut-de-mouton, la passerelle, le marché, les fils, puis le stade.
    _drawAirport(c, p, paint, quad, flat, year, t, cam);
    vehicles(upper: false);
    if (flyover) {
      // Le saut-de-mouton : les voies du milieu montent par-dessus le carrefour, entre deux barrières
      // rouges et blanches ; sous lui, les voies de côté et la rue qui traverse.
      const n = 42, half = _roadHalf * 0.6;
      for (var i = 0; i < n; i++) {
        final za = _flyFrom + (_flyTo - _flyFrom) * i / n, zb = _flyFrom + (_flyTo - _flyFrom) * (i + 1) / n;
        if (zb < cam + 0.12 || za > cam + _far) continue;
        final ea = rise(za), eb = rise(zb);
        // Les murs de béton, puis la chaussée.
        for (final side in const [-1.0, 1.0]) {
          final x = _roadX + side * half;
          quad([p(x, za), p(x, zb), p(x, zb, eb), p(x, za, ea)], paint(const Color(0xFFC9C4BA), za));
        }
        quad([
          p(_roadX - half, za, ea),
          p(_roadX + half, za, ea),
          p(_roadX + half, zb, eb),
          p(_roadX - half, zb, eb),
        ], paint(const Color(0xFF808286), za));
        if (i.isEven) flat(_roadX - 0.003, _roadX + 0.003, za, zb, Colors.white, e: (ea + eb) / 2 + 0.001);
      }
      vehicles(upper: true);
      // Les barrières rouges et blanches, devant les taxis.
      for (var i = 0; i < n; i++) {
        final za = _flyFrom + (_flyTo - _flyFrom) * i / n, zb = _flyFrom + (_flyTo - _flyFrom) * (i + 1) / n;
        if (zb < cam + 0.12 || za > cam + _far) continue;
        final ea = rise(za), eb = rise(zb);
        for (final side in const [-1.0, 1.0]) {
          final x = _roadX + side * half;
          quad([
            p(x, za, ea),
            p(x, zb, eb),
            p(x, zb, eb + 0.012),
            p(x, za, ea + 0.012),
          ], paint(i.isEven ? const Color(0xFFD32F2F) : Colors.white, za));
        }
      }
    }
    if (year >= footbridgeFrom && _footbridgeZ > cam + 0.15) _drawFootbridge(c, p, paint, quad, t);
    // Le marché de Kingasani : des parasols de toutes les couleurs des deux côtés du boulevard, et du monde.
    const umbrellas = [
      Color(0xFFE53935),
      Color(0xFFFDD835),
      Color(0xFF1E88E5),
      Color(0xFF43A047),
      Color(0xFFFB8C00),
      Color(0xFF8E24AA),
      Color(0xFFFFFFFF),
    ];
    for (var i = 0; i < 220; i++) {
      final z = _marketFrom + (_marketTo - _marketFrom) * _rnd(i.toDouble(), 7);
      if (z < cam + 0.2 || z > cam + _far) continue;
      final side = i.isEven ? -1 : 1;
      final x = _roadX + side * (_roadHalf + 0.016 + 0.11 * _rnd(i.toDouble(), 11));
      final r = 0.012 * f / depth(z);
      final at = p(x, z, 0.008);
      c.drawOval(Rect.fromCenter(center: at, width: r * 2, height: r * 1.3), paint(umbrellas[i % umbrellas.length], z));
      // Les gens entre les parasols.
      final walker = p(x + 0.012 * math.sin(t * 0.7 + i), z + 0.012);
      c.drawCircle(walker, math.max(0.6, r * 0.32), paint(const Color(0xFF3A2A22), z));
    }
    // Les poteaux électriques et leurs fils, qui pendent au-dessus du boulevard.
    if (year >= 1975) {
      final wire = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      Offset? last0, last1;
      for (var z = 5.2; z < 10.2; z += 0.45) {
        if (z < cam + 0.2 || z > cam + 9) {
          last0 = last1 = null;
          continue;
        }
        final tops = <Offset>[];
        for (final side in const [-1.0, 1.0]) {
          final x = _roadX + side * (_roadHalf + 0.012);
          final top = p(x, z, 0.085);
          c.drawLine(p(x, z), top, paint(const Color(0xFF6D6A64), z)..strokeWidth = math.max(1, 0.004 * f / depth(z)));
          tops.add(top);
        }
        wire.color = tint(const Color(0xFF202020), z).withValues(alpha: 0.85);
        // Les fils qui traversent le boulevard.
        for (var j = 0; j < 3; j++) {
          final a = tops[0].translate(0, j * 1.5), b = tops[1].translate(0, j * 1.5);
          final mid = Offset.lerp(a, b, 0.5)!.translate(0, (b.dx - a.dx).abs() * 0.08);
          c.drawPath(
            Path()
              ..moveTo(a.dx, a.dy)
              ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
            wire,
          );
        }
        // Et ceux qui suivent la route, d'un poteau au suivant.
        for (final (prev, now) in [(last0, tops[0]), (last1, tops[1])]) {
          if (prev == null) continue;
          final mid = Offset.lerp(prev, now, 0.5)!.translate(0, (now.dy - prev.dy).abs() * 0.15 + 2);
          c.drawPath(
            Path()
              ..moveTo(prev.dx, prev.dy)
              ..quadraticBezierTo(mid.dx, mid.dy, now.dx, now.dy),
            wire,
          );
        }
        last0 = tops[0];
        last1 = tops[1];
      }
    }

    if (_stadiumZ + _stadiumB > cam + 0.15) _drawStadium(c, p, paint, quad, year, t);

    // Le soir, la ville s'assombrit.
    if (dusk > 0.05) {
      c.drawRect(Rect.fromLTRB(0, y0 - h * 0.12, w, h), Paint()..color = Color.fromRGBO(12, 18, 40, dusk * 0.5));
    }
    c.restore();
  }

  /// Le stade vu d'en haut : l'anneau blanc du toit, les gradins rouges, bleus et orange, la piste et la pelouse.
  /// Avant 1994, un stade plus petit, aux gradins de béton.
  static void _drawStadium(
    Canvas c,
    Offset Function(double, double, [double]) p,
    Paint Function(Color, double) paint,
    void Function(List<Offset>, Paint) quad,
    double year,
    double t,
  ) {
    final martyrs = year >= martyrsFrom;
    final a = martyrs ? _stadiumA : _stadiumA * 0.78, b = martyrs ? _stadiumB : _stadiumB * 0.78;
    final top = martyrs ? 0.085 : 0.045;
    const n = 48;
    Offset ring(int i, double scale, double e) {
      final th = i / n * math.pi * 2;
      return p(_stadiumX + math.cos(th) * a * scale, _stadiumZ + math.sin(th) * b * scale, e);
    }

    const z = _stadiumZ;
    // L'ombre au sol.
    quad([for (var i = 0; i < n; i++) ring(i, 1.06, 0)], paint(const Color(0x55203018), z));
    // La pelouse, sa piste rouge, les lignes du terrain.
    quad([for (var i = 0; i < n; i++) ring(i, 0.56, 0.004)], paint(const Color(0xFFB0523C), z));
    quad([for (var i = 0; i < n; i++) ring(i, 0.47, 0.005)], paint(const Color(0xFF3F9A3A), z));
    final fa = a * 0.36, fb = b * 0.3;
    final field = [
      p(_stadiumX - fa, z - fb, 0.006),
      p(_stadiumX + fa, z - fb, 0.006),
      p(_stadiumX + fa, z + fb, 0.006),
      p(_stadiumX - fa, z + fb, 0.006),
    ];
    quad(field, paint(const Color(0xFF4CAF50), z));
    c.drawPath(
      Path()..addPolygon(field, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.75),
    );
    c.drawLine(p(_stadiumX, z - fb, 0.006), p(_stadiumX, z + fb, 0.006), Paint()..color = Colors.white70);
    // Les gradins, par secteurs de couleur, du bord de la piste jusqu'au toit.
    const seats = [Color(0xFFD84B3A), Color(0xFF2F6FC0), Color(0xFFF08A2A), Color(0xFF42B4E6)];
    for (var i = 0; i < n; i++) {
      final color = martyrs ? seats[(i ~/ 3) % seats.length] : const Color(0xFFB8B2A6);
      quad([ring(i, 0.58, 0.01), ring(i + 1, 0.58, 0.01), ring(i + 1, 0.86, top), ring(i, 0.86, top)], paint(color, z));
    }
    // L'anneau du toit, blanc cassé.
    for (var i = 0; i < n; i++) {
      quad([
        ring(i, 0.86, top),
        ring(i + 1, 0.86, top),
        ring(i + 1, 1.0, top),
        ring(i, 1.0, top),
      ], paint(martyrs ? const Color(0xFFEDE6D8) : const Color(0xFFD0CBC0), z));
    }
    // La façade, côté avion : piliers blancs et, depuis 2010, les panneaux rouges tout autour.
    for (var i = n ~/ 2; i < n; i++) {
      final th = (i + 0.5) / n * math.pi * 2;
      if (math.sin(th) > 0) continue;
      quad([
        ring(i, 1.0, 0),
        ring(i + 1, 1.0, 0),
        ring(i + 1, 1.0, top),
        ring(i, 1.0, top),
      ], paint(const Color(0xFFDCD5C6), z));
      if (martyrs && year >= boardsFrom) {
        quad([
          ring(i, 1.0, top * 0.12),
          ring(i + 1, 1.0, top * 0.12),
          ring(i + 1, 1.0, top * 0.38),
          ring(i, 1.0, top * 0.38),
        ], paint(i.isEven ? const Color(0xFFE21E26) : const Color(0xFFC8141C), z));
      }
      c.drawLine(ring(i, 1.0, 0), ring(i, 1.0, top), Paint()..color = const Color(0x55000000));
    }
  }

  /// La passerelle de Kingasani : un pont pour les piétons au-dessus du boulevard, ses escaliers de chaque côté.
  static void _drawFootbridge(
    Canvas c,
    Offset Function(double, double, [double]) p,
    Paint Function(Color, double) paint,
    void Function(List<Offset>, Paint) quad,
    double t,
  ) {
    const z = _footbridgeZ, e = 0.045, x0 = _roadX - _roadHalf - 0.06, x1 = _roadX + _roadHalf + 0.06, dz = 0.012;
    // Les piliers.
    for (final x in [x0 + 0.02, _roadX, x1 - 0.02]) {
      c.drawLine(p(x, z), p(x, z, e), paint(const Color(0xFF8C8F94), z)..strokeWidth = 2);
    }
    // Les escaliers qui descendent le long du trottoir.
    for (final x in [x0, x1]) {
      quad([
        p(x - 0.008, z, e),
        p(x + 0.008, z, e),
        p(x + 0.008, z - 0.09),
        p(x - 0.008, z - 0.09),
      ], paint(const Color(0xFFB0B4BA), z));
    }
    quad([p(x0, z - dz, e), p(x1, z - dz, e), p(x1, z + dz, e), p(x0, z + dz, e)], paint(const Color(0xFFDADDE2), z));
    // Les garde-corps bleus.
    for (final side in const [-1.0, 1.0]) {
      quad([
        p(x0, z + side * dz, e),
        p(x1, z + side * dz, e),
        p(x1, z + side * dz, e + 0.008),
        p(x0, z + side * dz, e + 0.008),
      ], paint(const Color(0xFF2E6DB4), z));
    }
    // Quelques piétons qui traversent.
    for (var i = 0; i < 4; i++) {
      final k = ((t * 0.05 + i * 0.27) % 1);
      final at = p(x0 + (x1 - x0) * (i.isEven ? k : 1 - k), z, e + 0.004);
      c.drawCircle(at, 1.6, paint(const Color(0xFF3A2A22), z));
    }
  }

  /// N'djili vu d'en haut : la piste dans l'axe de l'avion, le grand parking, les avions garés tout autour
  /// de l'aérogare, les hangars, et les quartiers qui entourent l'aéroport.
  /// Depuis juin 2015, l'aérogare ronde aux lames bleues fait tout le tour de la grande tour orange.
  static void _drawAirport(
    Canvas c,
    Offset Function(double, double, [double]) p,
    Paint Function(Color, double) paint,
    void Function(List<Offset>, Paint) quad,
    void Function(double, double, double, double, Color, {double e}) flat,
    double year,
    double t,
    double cam,
  ) {
    // Le parking des avions et la bretelle qui rejoint la piste.
    flat(0.1, 1.42, 11.8, 13.1, const Color(0xFFB9BBB7));
    flat(_runwayX + _runwayHalf, 0.12, 12.55, 12.66, const Color(0xFF8E9092));
    flat(_runwayX + _runwayHalf, 0.12, 12.95, 13.06, const Color(0xFF8E9092));
    // La piste : bandes blanches du seuil, axe en pointillés, bords, feux d'approche.
    flat(_runwayX - _runwayHalf, _runwayX + _runwayHalf, _runwayFrom, cam + _far, const Color(0xFF55585C));
    for (var i = 0; i < 8; i++) {
      final x = _runwayX - _runwayHalf * 0.85 + i * _runwayHalf * 1.7 / 7.5;
      flat(x, x + _runwayHalf * 0.12, _runwayFrom + 0.03, _runwayFrom + 0.13, Colors.white, e: 0.001);
    }
    for (var z = _runwayFrom + 0.22; z < cam + _far; z += 0.16) {
      flat(_runwayX - 0.005, _runwayX + 0.005, z, z + 0.08, Colors.white, e: 0.001);
    }
    for (final x in const [-_runwayHalf + 0.004, _runwayHalf - 0.008]) {
      flat(_runwayX + x, _runwayX + x + 0.004, _runwayFrom, cam + _far, Colors.white, e: 0.001);
    }
    for (var i = 0; i < 6; i++) {
      final z = _runwayFrom - 0.05 - i * 0.07;
      final on = ((t * 2.5 - i * 0.3) % 1) < 0.35;
      c.drawCircle(p(_runwayX, z, 0.002), 1.8, Paint()..color = on ? const Color(0xFFFFF59D) : const Color(0x66FFFFFF));
    }
    // Les hangars, au toit arrondi.
    for (final (x, z) in const [(1.1, 12.75), (1.3, 12.75)]) {
      const hw = 0.08, hd = 0.12, he = 0.04;
      quad([
        p(x - hw, z - hd),
        p(x + hw, z - hd),
        p(x + hw, z - hd, he),
        p(x - hw, z - hd, he),
      ], paint(const Color(0xFFB0B5BA), z));
      quad([
        p(x - hw, z - hd, he),
        p(x + hw, z - hd, he),
        p(x + hw, z + hd, he),
        p(x - hw, z + hd, he),
      ], paint(const Color(0xFFD5D9DD), z));
      for (var j = 1; j < 6; j++) {
        final zz = z - hd + 2 * hd * j / 6;
        c.drawLine(p(x - hw, zz, he), p(x + hw, zz, he), paint(const Color(0xFF9EA4AA), z));
      }
    }

    final round = year >= terminalFrom;
    // Les avions garés, le nez vers l'aérogare.
    final parked = round
        ? [for (var i = 0; i < 6; i++) (math.pi * (1.1 + 0.8 * i / 5), 0.4)]
        : [for (var i = 0; i < 5; i++) (math.pi * 1.5 + (i - 2) * 0.32, 0.3)];
    for (final (th, dist) in parked) {
      final x = _towerX + math.cos(th) * dist, z = _towerZ + math.sin(th) * dist * 0.75;
      _parkedPlane(c, p, paint, quad, x, z, th + math.pi, 0.11);
    }

    if (!round) {
      // L'ancienne aérogare, longue et blanche, et sa tour fine au bout.
      const z0 = 12.3, z1 = 12.5, e = 0.045, x0 = 0.3, x1 = 0.85;
      quad([p(x0, z0, e), p(x1, z0, e), p(x1, z1, e), p(x0, z1, e)], paint(const Color(0xFFCFCBC2), z0));
      quad([p(x0, z0), p(x1, z0), p(x1, z0, e), p(x0, z0, e)], paint(const Color(0xFFE9E6DE), z0));
      quad([
        p(x0, z0, e * 0.4),
        p(x1, z0, e * 0.4),
        p(x1, z0, e * 0.7),
        p(x0, z0, e * 0.7),
      ], paint(const Color(0xFF37474F), z0));
      _tower(
        c,
        p,
        paint,
        x: 0.9,
        z: 12.4,
        base: 0.014,
        flare: 0.003,
        top: 0.09,
        cab: const Color(0xFF2E5E5A),
        body: const Color(0xFFF2F0EA),
      );
      return;
    }
    // L'aérogare ronde : un anneau de bâtiments tout autour de la tour orange, une cour au milieu.
    const ri = 0.12, ro = 0.22, e = 0.045, n = 36, squash = 0.75;
    Offset ring(double th, double radius, double h) =>
        p(_towerX + math.cos(th) * radius, _towerZ + math.sin(th) * radius * squash, h);
    double th(int i) => math.pi * 2 * i / n;
    bool far(int i) => math.sin(th(i) + math.pi / n) > 0;
    // La cour, au pied de la tour.
    quad([for (var i = 0; i < n; i++) ring(th(i), ri, 0.001)], paint(const Color(0xFFB8C4A8), _towerZ));
    void roof(bool back) {
      for (var i = 0; i < n; i++) {
        if (far(i) != back) continue;
        quad([
          ring(th(i), ri, e),
          ring(th(i + 1), ri, e),
          ring(th(i + 1), ro, e),
          ring(th(i), ro, e),
        ], paint(const Color(0xFFDDE1E5), _towerZ));
      }
    }

    void glass(int i, double radius) {
      final entrance = (th(i) - math.pi * 1.5).abs() < math.pi * 2 / n * 1.6;
      quad([
        ring(th(i), radius, 0),
        ring(th(i + 1), radius, 0),
        ring(th(i + 1), radius, e),
        ring(th(i), radius, e),
      ], paint(entrance ? const Color(0xFFF2A23A) : const Color(0xFF9EC3E6), _towerZ));
      if (entrance) return;
      // Les lames bleues penchées, deux par travée.
      for (final f in const [0.0, 0.5]) {
        final a = Offset.lerp(ring(th(i), radius, 0), ring(th(i + 1), radius, 0), f)!;
        final b = Offset.lerp(ring(th(i), radius, e * 1.15), ring(th(i + 1), radius, e * 1.15), f + 0.5)!;
        c.drawLine(a, b, paint(const Color(0xFF2C5DA8), _towerZ)..strokeWidth = 1.6);
      }
    }

    // Derrière la tour : le toit, puis la façade intérieure qu'on voit à travers la cour.
    roof(true);
    for (var i = 0; i < n; i++) {
      if (far(i)) glass(i, ri);
    }
    _tower(
      c,
      p,
      paint,
      x: _towerX,
      z: _towerZ,
      base: 0.03,
      flare: 0.024,
      top: 0.16,
      cab: const Color(0xFF55707A),
      body: const Color(0xFFF2A23A),
    );
    // Devant la tour : le toit, puis la façade extérieure et l'entrée orange.
    roof(false);
    for (var i = 0; i < n; i++) {
      if (!far(i)) glass(i, ro);
    }
  }

  /// Un avion garé vu d'en haut : le fuselage blanc, les ailes en flèche, la queue bleue.
  static void _parkedPlane(
    Canvas c,
    Offset Function(double, double, [double]) p,
    Paint Function(Color, double) paint,
    void Function(List<Offset>, Paint) quad,
    double x,
    double z,
    double heading,
    double size,
  ) {
    final ca = math.cos(heading), sa = math.sin(heading);
    // (le long, de côté) → le sol.
    Offset at(double along, double across) =>
        p(x + (along * ca - across * sa) * size, z + (along * sa + across * ca) * size * 0.75, 0.006);
    quad([
      at(0.5, 0),
      at(0.42, 0.06),
      at(-0.48, 0.05),
      at(-0.5, 0),
      at(-0.48, -0.05),
      at(0.42, -0.06),
    ], paint(Colors.white, z));
    quad([at(0.08, 0.05), at(-0.12, 0.5), at(-0.2, 0.5), at(-0.1, 0.05)], paint(const Color(0xFFE8EAEC), z));
    quad([at(0.08, -0.05), at(-0.12, -0.5), at(-0.2, -0.5), at(-0.1, -0.05)], paint(const Color(0xFFE8EAEC), z));
    quad([at(-0.38, 0.04), at(-0.46, 0.2), at(-0.5, 0.2), at(-0.48, 0.04)], paint(const Color(0xFF2F6FC0), z));
    quad([at(-0.38, -0.04), at(-0.46, -0.2), at(-0.5, -0.2), at(-0.48, -0.04)], paint(const Color(0xFF2F6FC0), z));
  }

  /// Une tour de contrôle : le fût (évasé vers le haut pour la tour orange), la cabine vitrée, le toit.
  static void _tower(
    Canvas c,
    Offset Function(double, double, [double]) p,
    Paint Function(Color, double) paint, {
    required double x,
    required double z,
    required double base,
    required double flare,
    required double top,
    required Color cab,
    required Color body,
  }) {
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= 10; i++) {
      final e = top * i / 10, r = base + flare * math.pow(i / 10, 2.2);
      left.add(p(x - r, z, e));
      right.add(p(x + r, z, e));
    }
    final shaft = Path()..addPolygon([...left, ...right.reversed], true);
    final bounds = shaft.getBounds();
    c.drawPath(
      shaft,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(body, Colors.white, 0.25)!, body, Color.lerp(body, Colors.black, 0.2)!],
        ).createShader(bounds),
    );
    final rc = base + flare + 0.006;
    final glass = Rect.fromPoints(p(x - rc, z, top + 0.022), p(x + rc, z, top));
    c.drawRect(glass, paint(cab, z));
    for (var i = 1; i < 6; i++) {
      final gx = glass.left + glass.width * i / 6;
      c.drawLine(Offset(gx, glass.top), Offset(gx, glass.bottom), Paint()..color = Colors.white54);
    }
    c.drawRect(
      Rect.fromPoints(p(x - rc - 0.004, z, top + 0.028), p(x + rc + 0.004, z, top + 0.022)),
      paint(const Color(0xFFDADDE0), z),
    );
  }
}
