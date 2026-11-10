import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Le boulevard Lumumba à Kinshasa, redessiné d'après des photos : la tour de l'échangeur de Limete,
/// la chaussée et sa séparation rouge et blanche, les taxis jaunes, les « 207 » bleu et jaune
/// (« Esprit de mort ») et les motos-taxis, les Wewa.
///
/// Trois vues : la ville de haut pendant la descente, la rue de côté quand l'avion rase la chaussée,
/// et le pare-brise de près, avec le pilote et son casque.
abstract final class Boulevard {
  /// Les bandes de la rue, en parts de la hauteur de l'écran.
  static const skyline = 0.52, farRoad = 0.545, median = 0.64, nearRoad = 0.665, kerb = 0.95;

  /// La voie de l'avion (celle du milieu) et la voie de devant, au bord du trottoir.
  static const planeLane = 0.845, frontLane = 0.94;

  /// La vitesse de la rue sous l'avion, en unités par seconde.
  static const speed = 300.0;

  /// Le trou dans la chaussée : sa distance depuis l'entrée dans la rue.
  static const holeAt = speed * 4.6;

  /// À cette seconde de rue, le chauffeur du Wewa voit l'avion à côté de lui : il reste bouche bée.
  static const amazedAt = 29.4;

  static double _rnd(int i, int salt) {
    final x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  static double _ease(double k) {
    k = k.clamp(0.0, 1.0);
    return k * k * (3 - 2 * k);
  }

  static const _haze = Color(0xFFB9C8D2);

  // ------------------------------------------------------------------ la tour

  /// La tour de l'échangeur de Limete, d'après la photo : quatre hauts piliers jaunes serrés, deux plates-formes
  /// rondes en haut, les antennes, puis la longue flèche jaune. Au pied, la place ronde, ses gradins et ses
  /// murets jaunes ([plaza]).
  static void tower(Canvas c, Offset base, double h, {double mist = 0, bool plaza = false}) {
    Color tone(Color col) => Color.lerp(col, _haze, mist)!;
    final gold = tone(const Color(0xFFE2B33C)),
        light = tone(const Color(0xFFF2CF63)),
        shade = tone(const Color(0xFFA77A22)),
        deep = tone(const Color(0xFF5E4415));
    final x = base.dx, y = base.dy;
    Offset at(double dx, double dy) => Offset(x + h * dx, y - h * dy);
    // Un volume rond éclairé de la gauche : clair, doré, puis à l'ombre.
    Paint round(Rect r) => Paint()
      ..shader = LinearGradient(
        colors: [shade, light, gold, shade, deep],
        stops: const [0, 0.25, 0.5, 0.82, 1],
      ).createShader(r);

    if (plaza) {
      // La place ronde, ses gradins, ses murets jaunes qui partent en courbe, et la rampe vers la route.
      final disc = Rect.fromCenter(center: at(0, 0), width: h * 0.42, height: h * 0.12);
      c.drawOval(disc.inflate(h * 0.03), Paint()..color = tone(const Color(0xFF5E9A45)));
      c.drawOval(disc, Paint()..color = tone(const Color(0xFFB9A88A)));
      for (var i = 0; i < 4; i++) {
        c.drawArc(
          disc.deflate(h * (0.012 + i * 0.012)),
          math.pi * 0.15,
          math.pi * 0.7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.006
            ..color = tone(i.isEven ? const Color(0xFF8D7F68) : const Color(0xFFD8CCB4)),
        );
      }
      final wall = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.009
        ..color = gold;
      c.drawArc(disc.inflate(h * 0.004), math.pi * 0.05, math.pi * 0.9, false, wall);
      c.drawPath(
        Path()
          ..moveTo(x - h * 0.2, y + h * 0.01)
          ..quadraticBezierTo(x - h * 0.3, y + h * 0.05, x - h * 0.46, y + h * 0.04),
        wall,
      );
      c.drawPath(
        Path()
          ..moveTo(x + h * 0.2, y - h * 0.005)
          ..quadraticBezierTo(x + h * 0.3, y - h * 0.04, x + h * 0.42, y - h * 0.03),
        wall,
      );
      c.drawPath(
        Path()..addPolygon([at(0.01, -0.05), at(0.05, -0.05), at(0.07, -0.2), at(0.0, -0.2)], true),
        Paint()..color = tone(const Color(0xFFCFC6B5)),
      );
    }
    // Les quatre piliers, serrés, avec leurs fentes d'ombre.
    const top = 0.6, wide = 0.1;
    final pillars = Rect.fromLTRB(x - h * wide / 2, y - h * top, x + h * wide / 2, y);
    c.drawRect(pillars, Paint()..color = deep);
    for (var i = 0; i < 4; i++) {
      final r = Rect.fromLTWH(
        pillars.left + i * h * wide / 4 + h * 0.002,
        pillars.top,
        h * wide / 4 - h * 0.004,
        pillars.height,
      );
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(h * 0.006)), round(r));
    }
    // Les joints de béton, tous les quelques étages.
    for (var i = 1; i < 9; i++) {
      final yy = y - h * top * i / 9;
      c.drawLine(
        Offset(pillars.left, yy),
        Offset(pillars.right, yy),
        Paint()
          ..color = shade.withValues(alpha: 0.35)
          ..strokeWidth = math.max(0.5, h * 0.002),
      );
    }
    // Les deux plates-formes : des disques jaunes, plus larges que les piliers, vus un peu d'en haut.
    void platform(double level, double half, double thick) {
      final r = Rect.fromCenter(center: at(0, level), width: h * half * 2, height: h * thick);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(h * thick / 2)), round(r));
      c.drawOval(Rect.fromCenter(center: r.topCenter, width: r.width, height: h * thick * 0.7), Paint()..color = light);
      c.drawRect(
        Rect.fromLTRB(r.left + h * 0.01, r.bottom, r.right - h * 0.01, r.bottom + h * 0.008),
        Paint()..color = deep.withValues(alpha: 0.6),
      );
    }

    platform(top - 0.04, 0.072, 0.022);
    // Le tambour vitré entre les deux plates-formes.
    final drum = Rect.fromLTRB(x - h * 0.048, y - h * (top + 0.04), x + h * 0.048, y - h * (top - 0.03));
    c.drawRect(drum, round(drum));
    for (var i = 0; i < 6; i++) {
      c.drawRect(
        Rect.fromLTWH(drum.left + h * (0.006 + i * 0.015), drum.top + h * 0.016, h * 0.008, h * 0.026),
        Paint()..color = deep,
      );
    }
    platform(top + 0.04, 0.066, 0.02);
    // Les antennes : des mâts en treillis sur la plate-forme du haut.
    final lattice = Paint()
      ..color = tone(const Color(0xFF6B6157))
      ..strokeWidth = math.max(0.5, h * 0.0025);
    for (final dx in const [-0.04, -0.012, 0.02, 0.042]) {
      final foot = at(dx, top + 0.05), head = at(dx, top + 0.1 + (dx * 31 % 0.02).abs());
      c.drawLine(foot, head, lattice);
      for (var k = 0; k < 3; k++) {
        final yy = foot.dy + (head.dy - foot.dy) * (k + 0.5) / 3;
        c.drawLine(Offset(foot.dx - h * 0.006, yy), Offset(foot.dx + h * 0.006, yy - h * 0.008), lattice);
      }
    }
    // La flèche : un fût carré, puis l'aiguille, de plus en plus fine.
    void column(double from, double to, double half) {
      final r = Rect.fromLTRB(x - h * half, y - h * to, x + h * half, y - h * from);
      c.drawRect(r, round(r));
    }

    column(top + 0.05, top + 0.2, 0.019);
    c.drawRect(
      Rect.fromLTRB(x - h * 0.019, y - h * (top + 0.135), x + h * 0.019, y - h * (top + 0.125)),
      Paint()..color = deep,
    );
    column(top + 0.2, top + 0.32, 0.012);
    column(top + 0.32, 1.0, 0.0075);
    c.drawCircle(at(0, 1.0), math.max(0.8, h * 0.006), Paint()..color = tone(const Color(0xFFFF5A3A)));
  }

  // ------------------------------------------------------------ la ville de haut

  /// Kinshasa vue de l'avion qui descend : les toits, les arbres, la tour au milieu, le boulevard qui file
  /// vers l'horizon avec ses voitures. [approach] va de 0 (de haut) à 1 (tout près de la chaussée).
  static void aerial(Canvas c, Size s, double u, double approach, double t, double fade) {
    if (fade <= 0) return;
    final w = s.width, h = s.height;
    c.saveLayer(Offset.zero & s, Paint()..color = Color.fromRGBO(255, 255, 255, fade.clamp(0.0, 1.0)));
    // On s'approche du boulevard : toute la vue grossit autour de la chaussée.
    final zoom = 1 + 2.3 * approach * approach;
    final focus = Offset(w * 0.2, h * 0.86);
    c.translate(focus.dx, focus.dy);
    c.scale(zoom);
    c.translate(-focus.dx, -focus.dy);

    final y0 = h * 0.34;
    // L'horizon : la brume, puis les collines.
    c.drawRect(
      Rect.fromLTRB(-w, y0 - h * 0.14, w * 2, y0 + 2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_haze.withValues(alpha: 0), _haze],
        ).createShader(Rect.fromLTRB(0, y0 - h * 0.14, w, y0 + 2)),
    );
    final hills = Path()..moveTo(-w, y0 + 2);
    for (var i = 0; i <= 40; i++) {
      final x = -w * 0.2 + w * 1.4 * i / 40;
      hills.lineTo(x, y0 - h * (0.012 + 0.03 * (0.5 + 0.5 * math.sin(i * 0.9)) * (0.6 + 0.4 * math.sin(i * 0.37 + 1))));
    }
    hills
      ..lineTo(w * 2, y0 + 2)
      ..close();
    c.drawPath(hills, Paint()..color = const Color(0xFF8FA5B4));
    // Le sol de la ville : sable et verdure, plus pâle au loin.
    final ground = Rect.fromLTRB(-w, y0, w * 2, h * 1.4);
    c.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA9BBB4), Color(0xFF9DAE8C), Color(0xFF8C9A6B), Color(0xFF7F8A58)],
          stops: [0, 0.18, 0.55, 1],
        ).createShader(Rect.fromLTRB(0, y0, w, h)),
    );

    // Le boulevard : du bas de l'écran jusqu'à l'horizon, à gauche de la tour.
    double roadX(double d) => w * (0.42 - 0.26 * d);
    double roadHalf(double d) => w * (0.003 + 0.115 * d * d);
    double depthY(double d) => y0 + (h * 1.05 - y0) * math.pow(d, 1.7);
    // La deuxième chaussée, qui vient de la droite et tourne au pied de la tour.
    double sideX(double d) => w * (0.57 + 0.3 * (d - 0.45) / 0.55);
    double sideHalf(double d) => w * (0.012 + 0.07 * (d - 0.45) / 0.55 * d);
    bool onRoad(double x, double d) =>
        (x - roadX(d)).abs() < roadHalf(d) * 1.25 || (d > 0.45 && (x - sideX(d)).abs() < sideHalf(d) * 1.3);

    final towerBase = Offset(w * 0.56, depthY(0.45));
    // Les quartiers : des rangées de toits de tôle et de dalles, des manguiers entre les maisons.
    const roofs = [
      Color(0xFFB5583A),
      Color(0xFFC8C4BA),
      Color(0xFF9C4A30),
      Color(0xFFE0DCD2),
      Color(0xFF7FA4BF),
      Color(0xFFA9A49A),
      Color(0xFFC77B4A),
      Color(0xFF8E3F2C),
    ];
    const rows = 22;
    for (var r = 1; r <= rows; r++) {
      final d = r / rows, y = depthY(d), size = (3 + 40 * math.pow(d, 1.6)) * u, mist = (1 - d) * 0.72;
      final step = size * 1.32;
      final n = (w * 1.6 / step).ceil();
      for (var i = 0; i < n; i++) {
        final x = -w * 0.3 + i * step + _rnd(r, 9) * step, k = _rnd(i, r), k2 = _rnd(i, r + 40);
        if (onRoad(x, d)) continue;
        // Le parc au pied de la tour reste vert.
        final park = (Offset(x, y) - towerBase).distance < w * 0.09 * (0.5 + d);
        if (k < 0.26 || park) {
          if (k2 < 0.7) {
            final tree = Color.lerp(k2 < 0.35 ? const Color(0xFF2F6B35) : const Color(0xFF4A8A3C), _haze, mist)!;
            c.drawOval(
              Rect.fromCenter(center: Offset(x, y), width: size * 0.9, height: size * 0.6),
              Paint()..color = tree,
            );
            c.drawOval(
              Rect.fromCenter(center: Offset(x - size * 0.12, y - size * 0.1), width: size * 0.45, height: size * 0.28),
              Paint()..color = Color.lerp(tree, Colors.white, 0.16)!,
            );
          }
          continue;
        }
        final roof = Color.lerp(roofs[(k2 * roofs.length).floor()], _haze, mist)!;
        final bw = size * (0.7 + 0.45 * k), bh = size * (0.34 + 0.22 * k2), wall = size * 0.2;
        final rect = Rect.fromCenter(center: Offset(x, y), width: bw, height: bh);
        // Le mur qu'on voit de biais, sous le toit.
        c.drawRect(
          Rect.fromLTRB(rect.left, rect.bottom, rect.right, rect.bottom + wall),
          Paint()..color = Color.lerp(const Color(0xFFD8CDB8), _haze, mist)!.withValues(alpha: 0.95),
        );
        c.drawRect(rect, Paint()..color = roof);
        c.drawRect(
          Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + bh * 0.45),
          Paint()..color = Colors.white.withValues(alpha: 0.1),
        );
      }
    }

    // Les chaussées.
    void road(double Function(double) cx, double Function(double) half, double from, double to, {bool lanes = true}) {
      const steps = 26;
      final left = <Offset>[], right = <Offset>[];
      for (var i = 0; i <= steps; i++) {
        final d = from + (to - from) * i / steps, y = depthY(d);
        left.add(Offset(cx(d) - half(d), y));
        right.add(Offset(cx(d) + half(d), y));
      }
      final shape = Path()..addPolygon([...left, ...right.reversed], true);
      c.drawPath(
        shape,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9FA9AE), Color(0xFF74777B), Color(0xFF5C5E62)],
            stops: [0, 0.35, 1],
          ).createShader(Rect.fromLTRB(0, y0, w, h)),
      );
      if (!lanes) return;
      // La séparation rouge et blanche au milieu, et les lignes des voies.
      for (var i = 0; i < steps; i++) {
        final a = Offset((left[i].dx + right[i].dx) / 2, left[i].dy);
        final b = Offset((left[i + 1].dx + right[i + 1].dx) / 2, left[i + 1].dy);
        final dd = from + (to - from) * (i + 0.5) / steps;
        c.drawLine(
          a,
          b,
          Paint()
            ..color = Color.lerp(i.isEven ? const Color(0xFFD23B2E) : Colors.white, _haze, (1 - dd) * 0.6)!
            ..strokeWidth = math.max(0.8, half(dd) * 0.08),
        );
        if (i.isOdd) continue;
        for (final side in const [-0.5, 0.5]) {
          c.drawLine(
            Offset.lerp(a, side < 0 ? left[i] : right[i], 0.5)!,
            Offset.lerp(b, side < 0 ? left[i + 1] : right[i + 1], 0.5)!,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.75 * dd)
              ..strokeWidth = math.max(0.5, half(dd) * 0.035),
          );
        }
      }
    }

    road(sideX, sideHalf, 0.45, 1.05);
    road(roadX, roadHalf, 0.0, 1.05);

    // Les voitures du boulevard : elles montent à droite de la séparation, descendent à gauche.
    const colors = [
      Color(0xFFF4C20D),
      Colors.white,
      Color(0xFF2E9BD6),
      Color(0xFFF4C20D),
      Color(0xFF3B3F46),
      Color(0xFFC0392B),
    ];
    for (var i = 0; i < 26; i++) {
      final up = i.isEven;
      var p = (_rnd(i, 3) + t * (0.035 + 0.03 * _rnd(i, 4)) * (up ? -1 : 1)) % 1.0;
      if (p < 0) p += 1;
      final d = 0.12 + 0.93 * p, half = roadHalf(d);
      final lane = (up ? 1 : -1) * (0.22 + 0.5 * _rnd(i, 5));
      final at = Offset(roadX(d) + half * lane, depthY(d));
      final len = half * 0.2, wide = half * 0.13;
      if (len < 0.8) continue;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: wide, height: len), Radius.circular(wide * 0.3)),
        Paint()..color = Color.lerp(colors[i % colors.length], _haze, (1 - d) * 0.5)!,
      );
      c.drawRect(
        Rect.fromCenter(center: at.translate(0, up ? -len * 0.12 : len * 0.12), width: wide * 0.8, height: len * 0.25),
        Paint()..color = const Color(0xAA1B2530),
      );
    }

    tower(c, towerBase, h * 0.5, mist: 0.12, plaza: true);

    // Des nuages bas passent sous l'avion.
    for (var i = 0; i < 5; i++) {
      final x = (w * (1.3 - ((t * (0.05 + 0.02 * i) + _rnd(i, 7)) % 1.0) * 1.7)), y = h * (0.42 + 0.11 * i);
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w * (0.22 + 0.05 * i), height: h * 0.05),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2 * (1 - approach))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * u),
      );
    }
    c.restore();
  }

  // ------------------------------------------------------------------- la rue

  static const _walls = [
    Color(0xFFE8DCC2),
    Color(0xFFD9B98A),
    Color(0xFFBFD3DE),
    Color(0xFFE6C3B2),
    Color(0xFFF1EEE6),
    Color(0xFFC9CCC6),
    Color(0xFFDDD0A0),
  ];
  static const _awnings = [
    Color(0xFFC0392B),
    Color(0xFF1E8449),
    Color(0xFF2471A3),
    Color(0xFFF1C40F),
    Color(0xFFE67E22),
  ];

  /// La rue vue de côté. D'abord [front] à faux : le ciel de la ville, la tour, les immeubles, la chaussée
  /// et ce qui roule derrière l'avion ; puis, l'avion dessiné, [front] à vrai : la voie de devant et le trottoir.
  ///
  /// [dist] est le chemin parcouru sur la rue (en pixels), [st] les secondes passées dans la rue,
  /// [drop] fait descendre la rue quand l'avion remonte, [plane] est la place de l'avion à l'écran.
  static void street(
    Canvas c,
    Size s,
    double u,
    double dist,
    double st,
    double t, {
    required bool front,
    required Offset plane,
    required double planeLength,
    double fade = 1,
    double drop = 0,
  }) {
    if (fade <= 0) return;
    final w = s.width, h = s.height;
    final layered = fade < 1;
    if (layered) c.saveLayer(Offset.zero & s, Paint()..color = Color.fromRGBO(255, 255, 255, fade.clamp(0.0, 1.0)));
    c.save();
    c.translate(0, h * 1.02 * _ease(drop));
    // Ce que l'élan ajoute au chemin : les voitures qui roulent dans le même sens reculent d'autant.
    final lead = dist - speed * u * st;
    front
        ? _streetFront(c, w, h, u, dist, st, t, lead)
        : _streetBack(c, w, h, u, dist, st, t, lead, plane, planeLength);
    c.restore();
    if (layered) c.restore();
  }

  static void _streetBack(
    Canvas c,
    double w,
    double h,
    double u,
    double dist,
    double st,
    double t,
    double lead,
    Offset plane,
    double planeLength,
  ) {
    final base = h * skyline;
    // La brume chaude de la ville, derrière les toits.
    c.drawRect(
      Rect.fromLTRB(0, h * 0.2, w, base),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00E9DCC6), Color(0xCCE9DCC6)],
        ).createShader(Rect.fromLTRB(0, h * 0.2, w, base)),
    );
    // Les quartiers au loin, en silhouette.
    final far = dist * 0.05;
    for (var i = (far / (46 * u)).floor() - 1; i * 46 * u - far < w + 60 * u; i++) {
      final x = i * 46 * u - far, bh = (16 + 44 * _rnd(i, 21)) * u, bw = (30 + 26 * _rnd(i, 22)) * u;
      c.drawRect(Rect.fromLTRB(x, base - bh, x + bw, base), Paint()..color = const Color(0xFFAFC0CC));
    }
    // La tour de l'échangeur : le repère, qui passe lentement.
    tower(c, Offset(w * 0.98 - dist * 0.085, base), h * 0.47, mist: 0.1);
    _buildings(c, w, u, base, dist * 0.42);

    // Le trottoir d'en face, ses arbres, ses parasols et ses passants.
    c.drawRect(Rect.fromLTRB(0, base, w, h * farRoad), Paint()..color = const Color(0xFFCDBFA6));
    c.drawRect(Rect.fromLTRB(0, h * farRoad - 2 * u, w, h * farRoad), Paint()..color = const Color(0xFF8E8676));
    final walk = dist * 0.9;
    for (var i = (walk / (150 * u)).floor() - 1; i * 150 * u - walk < w + 80 * u; i++) {
      final x = i * 150 * u - walk, k = _rnd(i, 31);
      if (k < 0.42) {
        _tree(c, Offset(x + 40 * u, base + 3 * u), (58 + 30 * _rnd(i, 32)) * u);
      } else if (k < 0.75) {
        _stall(c, Offset(x + 30 * u, base + 4 * u), u, _awnings[(i % _awnings.length).abs()]);
      }
      _walker(c, Offset(x + 96 * u, base + 5 * u), u * 0.8, t + i, _awnings[((i * 3) % _awnings.length).abs()]);
      if (k > 0.5) _walker(c, Offset(x + 120 * u, base + 5 * u), u * 0.76, t * 0.8 + i * 2, const Color(0xFFF1EEE6));
    }

    // La chaussée : l'asphalte, plus clair au loin.
    final asphalt = Rect.fromLTRB(0, h * farRoad, w, h * kerb);
    c.drawRect(
      asphalt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7C7B7C), Color(0xFF656466), Color(0xFF545356)],
        ).createShader(asphalt),
    );
    // Les lignes blanches des voies, qui défilent.
    void dashes(double y, double thick, double len, double gap) {
      final period = (len + gap) * u, off = dist % period;
      final p = Paint()..color = const Color(0xE6F4F1E8);
      for (var x = -off; x < w; x += period) {
        c.drawRect(Rect.fromLTWH(x, y - thick * u / 2, len * u, thick * u), p);
      }
    }

    dashes(h * (farRoad + (median - farRoad) / 2), 1.6, 26, 34);
    dashes(h * (nearRoad + (kerb - nearRoad) / 3), 2.6, 40, 50);
    dashes(h * (nearRoad + (kerb - nearRoad) * 2 / 3), 3.2, 46, 56);
    // Des raccords d'asphalte plus sombres.
    for (var i = (dist / (420 * u)).floor() - 1; i * 420 * u - dist < w; i++) {
      final x = i * 420 * u - dist + 380 * u * _rnd(i, 41), y = h * (nearRoad + 0.03 + 0.2 * _rnd(i, 42));
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: (60 + 80 * _rnd(i, 43)) * u, height: 9 * u),
        Paint()..color = const Color(0x22201E20),
      );
    }

    // En face, la circulation vient vers nous.
    const kinds = [0, 1, 2, 3, 0, 2, 1, 3];
    final lane = h * (farRoad + (median - farRoad) * 0.72);
    for (var i = 0; i < kinds.length; i++) {
      final span = w * 2.8, v = (speed * 1.35 + 60 * _rnd(i, 51)) * u;
      final x = w * 1.4 - ((dist * 0.5 + st * v * 0.5 + _rnd(i, 52) * span + i * span / kinds.length) % span);
      final at = Offset(x, lane - (i.isOdd ? 12 * u : 0));
      switch (kinds[i]) {
        case 0:
          car(c, at, u * 0.58, t, flip: true);
        case 1:
          bus207(c, at, u * 0.58, t, flip: true);
        case 2:
          wewa(c, at, u * 0.58, t, flip: true, riders: 1 + i % 2);
        default:
          car(
            c,
            at,
            u * 0.58,
            t,
            flip: true,
            color: i == 3 ? const Color(0xFF3B3F46) : const Color(0xFFE9E6DF),
            taxi: false,
          );
      }
    }

    // La séparation : des blocs rouges et blancs, et les lampadaires à deux bras.
    final top = h * median, bottom = h * nearRoad;
    c.drawRect(Rect.fromLTRB(0, bottom - 1.5 * u, w, bottom + 2.5 * u), Paint()..color = const Color(0x55000000));
    final block = 30 * u;
    for (var i = (dist / block).floor() - 1; i * block - dist < w; i++) {
      final x = i * block - dist;
      final r = Rect.fromLTRB(x, top - 5 * u, x + block, bottom);
      c.drawRect(r, Paint()..color = i.isEven ? const Color(0xFFD23B2E) : const Color(0xFFF2EFE8));
      c.drawRect(Rect.fromLTRB(x, top - 5 * u, x + block, top - 2 * u), Paint()..color = const Color(0x33FFFFFF));
      c.drawRect(Rect.fromLTRB(x, bottom - 3 * u, x + block, bottom), Paint()..color = const Color(0x33000000));
    }
    for (var i = (dist / (300 * u)).floor() - 1; i * 300 * u - dist < w + 40 * u; i++) {
      _lamp(c, Offset(i * 300 * u - dist + 60 * u, top - 4 * u), u, 150 * u);
    }

    // Le trou dans la voie de l'avion, signalé par une branche et un vieux pneu.
    final holeX = plane.dx + holeAt * u - dist;
    if (holeX > -160 * u && holeX < w + 160 * u) pothole(c, Offset(holeX, h * (planeLane - 0.012)), u * 1.25);

    // Une jeep roule sur la voie du fond, à côté de la séparation.
    final jeep = w * 1.02 - 36 * u * st - lead;
    car(c, Offset(jeep, h * (nearRoad + 0.075)), u * 0.86, t, color: const Color(0xFF2F3E46), taxi: false);

    // L'ombre de l'avion sur sa voie.
    final alt = ((h * planeLane - plane.dy) / (h * 0.4)).clamp(0.0, 1.0);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(plane.dx - planeLength * 0.04, h * planeLane - 3 * u),
        width: planeLength * (0.92 - 0.4 * alt),
        height: 13 * u * (1 - 0.4 * alt),
      ),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, 0.42 - 0.3 * alt)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * u),
    );
  }

  static void _streetFront(Canvas c, double w, double h, double u, double dist, double st, double t, double lead) {
    // Le Wewa roule sur la voie de devant, à côté de l'avion : la voie de l'avion reste libre devant lui.
    // Il s'en approche un moment (« tu vas cogner un Wewa ! »), puis le chauffeur voit l'avion et reste bouche bée.
    final wx = wewaX(w, u, st, lead), drift = math.sin(((st - 12) / 12).clamp(0.0, 1.0) * math.pi);
    final amazed = _ease((st - amazedAt) / 0.6) * (1 - _ease((st - amazedAt - 6) / 0.8));
    wewa(
      c,
      Offset(wx, h * (frontLane - 0.035 * drift)),
      u * 1.22,
      t,
      lean: -0.06 * drift + 0.05 * math.sin(st * 3) * amazed,
      amazed: amazed,
    );

    // Le taxi jaune, puis le 207, sur la voie de devant.
    car(c, Offset(w * 0.84 - 45 * u * st - lead, h * frontLane), u * 1.2, t);
    final bx = w * 1.14 - 84 * u * (st - 5) - lead;
    // Le 207 serre l'avion, puis s'écarte : « Esprit de mort ».
    final by = h * (frontLane - 0.03 * math.sin(((st - 7) / 6).clamp(0.0, 1.0) * math.pi));
    bus207(c, Offset(bx, by), u * 1.24, t);
    // Un autre taxi, plus tard.
    car(c, Offset(w * 1.5 - 62 * u * (st - 38) - lead, h * frontLane), u * 1.2, t);

    // Le bord du trottoir : rouge et blanc, comme sur le boulevard.
    final top = h * kerb, block = 34 * u;
    for (var i = (dist * 1.06 / block).floor() - 1; i * block - dist * 1.06 < w; i++) {
      final x = i * block - dist * 1.06;
      c.drawRect(
        Rect.fromLTRB(x, top, x + block, top + 7 * u),
        Paint()..color = i.isEven ? const Color(0xFFC9372B) : const Color(0xFFF2EFE8),
      );
    }
    c.drawRect(Rect.fromLTRB(0, top + 7 * u, w, h * 1.3), Paint()..color = const Color(0xFFBEB29A));
    c.drawRect(Rect.fromLTRB(0, top + 7 * u, w, top + 9 * u), Paint()..color = const Color(0x33000000));
    // Les lampadaires du premier plan filent plus vite que la rue.
    final near = dist * 1.3;
    for (var i = (near / (980 * u)).floor() - 1; i * 980 * u - near < w + 60 * u; i++) {
      _lamp(c, Offset(i * 980 * u - near + 700 * u, h * 1.04), u * 1.9, 250 * u, single: true);
    }
  }

  /// La place du Wewa devant l'avion, à l'écran.
  static double wewaX(double w, double u, double st, double lead) {
    final arrive = w * 1.12 - 70 * u * (st - 10);
    final gone = math.max(0.0, st - amazedAt - 6.5) * 110 * u;
    return math.max(arrive, w * 0.58) - gone - lead;
  }

  static void _buildings(Canvas c, double w, double u, double base, double scroll) {
    final period = 138 * u;
    for (var i = (scroll / period).floor() - 1; i * period - scroll < w + period; i++) {
      final x = i * period - scroll, k = _rnd(i, 1), k2 = _rnd(i, 2), k3 = _rnd(i, 3);
      final bw = (84 + 46 * k) * u, bh = (52 + 96 * k2 * k2) * u;
      final wall = _walls[(k3 * _walls.length).floor() % _walls.length];
      final r = Rect.fromLTRB(x, base - bh, x + bw, base);
      c.drawRect(r, Paint()..color = wall);
      // Le côté à l'ombre, la corniche.
      c.drawRect(Rect.fromLTRB(r.right - 9 * u, r.top, r.right, r.bottom), Paint()..color = const Color(0x2A000000));
      c.drawRect(
        Rect.fromLTRB(r.left - 2 * u, r.top - 3 * u, r.right + 2 * u, r.top + 2 * u),
        Paint()..color = Color.lerp(wall, Colors.black, 0.25)!,
      );
      // Les fenêtres, étage par étage.
      final shop = 22 * u, floors = ((bh - shop - 8 * u) / (19 * u)).floor(), cols = ((bw - 14 * u) / (17 * u)).floor();
      for (var f = 0; f < floors; f++) {
        final y = r.bottom - shop - (f + 1) * 19 * u + 4 * u;
        for (var j = 0; j < cols; j++) {
          final wx = r.left + 8 * u + j * (bw - 16 * u) / cols, open = _rnd(i * 31 + f * 7 + j, 4);
          c.drawRect(
            Rect.fromLTWH(wx, y, 10 * u, 11 * u),
            Paint()
              ..color = open < 0.2
                  ? const Color(0xFFE9D9A8)
                  : (open < 0.3 ? const Color(0xFFB3472F) : const Color(0xFF46586A)),
          );
          c.drawRect(Rect.fromLTWH(wx, y, 10 * u, 2 * u), Paint()..color = const Color(0x33FFFFFF));
        }
        if (k3 > 0.5) {
          c.drawRect(
            Rect.fromLTWH(r.left + 5 * u, y + 12.5 * u, bw - 12 * u, 1.6 * u),
            Paint()..color = const Color(0x55000000),
          );
        }
      }
      // Le rez-de-chaussée : les boutiques, leurs stores et leurs enseignes.
      final awning = _awnings[(i % _awnings.length).abs()];
      c.drawRect(
        Rect.fromLTRB(r.left, r.bottom - shop, r.right, r.bottom),
        Paint()..color = Color.lerp(wall, Colors.black, 0.45)!,
      );
      c.drawRect(
        Rect.fromLTRB(r.left + 4 * u, r.bottom - shop - 5 * u, r.right - 4 * u, r.bottom - shop + 4 * u),
        Paint()..color = awning,
      );
      for (var j = 0; j < 4; j++) {
        c.drawRect(
          Rect.fromLTWH(r.left + 8 * u + j * (bw - 16 * u) / 4, r.bottom - shop - 5 * u, (bw - 16 * u) / 8, 9 * u),
          Paint()..color = const Color(0x55FFFFFF),
        );
      }
      // Sur le toit : une citerne bleue, une antenne, ou les fers d'un étage en attente.
      if (k < 0.34) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + bw * 0.55, r.top - 16 * u, 16 * u, 14 * u),
            Radius.circular(3 * u),
          ),
          Paint()..color = const Color(0xFF2B6CB0),
        );
      } else if (k < 0.62) {
        final p = Paint()
          ..color = const Color(0xFF5B5F66)
          ..strokeWidth = 1.2 * u;
        c.drawLine(Offset(r.left + bw * 0.3, r.top), Offset(r.left + bw * 0.3, r.top - 26 * u), p);
        c.drawLine(
          Offset(r.left + bw * 0.3 - 6 * u, r.top - 20 * u),
          Offset(r.left + bw * 0.3 + 6 * u, r.top - 20 * u),
          p,
        );
      } else if (k < 0.8) {
        final p = Paint()
          ..color = const Color(0xFF7A5A44)
          ..strokeWidth = u;
        for (var j = 0; j < 5; j++) {
          final px = r.left + 8 * u + j * (bw - 16 * u) / 4;
          c.drawLine(Offset(px, r.top), Offset(px, r.top - 12 * u), p);
        }
      }
      // Un panneau d'affichage entre deux immeubles : des formes, pas de marque.
      if (k2 > 0.6) {
        final px = r.right + 8 * u, board = Rect.fromLTWH(px, base - 74 * u, 34 * u, 24 * u);
        c.drawRect(Rect.fromLTWH(px + 15 * u, base - 50 * u, 3 * u, 50 * u), Paint()..color = const Color(0xFF5B5F66));
        c.drawRect(board, Paint()..color = _awnings[((i * 2 + 1) % _awnings.length).abs()]);
        c.drawCircle(board.center.translate(-7 * u, 0), 6 * u, Paint()..color = const Color(0xDDFFFFFF));
        c.drawRect(
          Rect.fromLTWH(board.center.dx + 2 * u, board.center.dy - 5 * u, 10 * u, 2.4 * u),
          Paint()..color = const Color(0xDDFFFFFF),
        );
        c.drawRect(
          Rect.fromLTWH(board.center.dx + 2 * u, board.center.dy + 1 * u, 7 * u, 2.4 * u),
          Paint()..color = const Color(0xAAFFFFFF),
        );
      }
    }
  }

  static void _tree(Canvas c, Offset base, double size) {
    c.drawRect(
      Rect.fromLTWH(base.dx - size * 0.035, base.dy - size * 0.5, size * 0.07, size * 0.5),
      Paint()..color = const Color(0xFF5A4030),
    );
    for (final (dx, dy, r, col) in const [
      (0.0, -0.66, 0.3, Color(0xFF2F6B35)),
      (-0.2, -0.56, 0.22, Color(0xFF3C7C3E)),
      (0.2, -0.58, 0.24, Color(0xFF28602F)),
      (-0.05, -0.78, 0.2, Color(0xFF4A8A3C)),
    ]) {
      c.drawCircle(base + Offset(dx * size, dy * size), r * size, Paint()..color = col);
    }
  }

  /// Un étal sous son parasol, comme sur les trottoirs de Kinshasa.
  static void _stall(Canvas c, Offset base, double u, Color color) {
    c.drawRect(
      Rect.fromLTWH(base.dx - 9 * u, base.dy - 11 * u, 18 * u, 11 * u),
      Paint()..color = const Color(0xFF8A6A48),
    );
    c.drawRect(
      Rect.fromLTWH(base.dx - 0.8 * u, base.dy - 30 * u, 1.6 * u, 20 * u),
      Paint()..color = const Color(0xFF4A4A4A),
    );
    c.drawPath(
      Path()
        ..moveTo(base.dx - 17 * u, base.dy - 26 * u)
        ..quadraticBezierTo(base.dx, base.dy - 42 * u, base.dx + 17 * u, base.dy - 26 * u)
        ..close(),
      Paint()..color = color,
    );
    c.drawPath(
      Path()
        ..moveTo(base.dx - 6 * u, base.dy - 26 * u)
        ..quadraticBezierTo(base.dx, base.dy - 40 * u, base.dx + 6 * u, base.dy - 26 * u)
        ..close(),
      Paint()..color = const Color(0x55FFFFFF),
    );
  }

  static void _walker(Canvas c, Offset feet, double u, double t, Color shirt) {
    final swing = math.sin(t * 5) * 3 * u;
    final leg = Paint()
      ..color = const Color(0xFF2B2B33)
      ..strokeWidth = 2.6 * u
      ..strokeCap = StrokeCap.round;
    c.drawLine(feet + Offset(0, -11 * u), feet + Offset(swing, 0), leg);
    c.drawLine(feet + Offset(0, -11 * u), feet + Offset(-swing, 0), leg);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(feet.dx - 3.4 * u, feet.dy - 23 * u, 6.8 * u, 13 * u),
        Radius.circular(2.4 * u),
      ),
      Paint()..color = shirt,
    );
    c.drawCircle(feet + Offset(0, -26.5 * u), 3.4 * u, Paint()..color = const Color(0xFF5A3A26));
  }

  static void _lamp(Canvas c, Offset base, double u, double height, {bool single = false}) {
    final pole = Paint()
      ..color = const Color(0xFF8F979E)
      ..strokeWidth = 2.6 * u
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(base, base.translate(0, -height), pole);
    for (final side in single ? const [1.0] : const [-1.0, 1.0]) {
      final arm = Path()
        ..moveTo(base.dx, base.dy - height)
        ..quadraticBezierTo(
          base.dx + side * 4 * u,
          base.dy - height - 9 * u,
          base.dx + side * 22 * u,
          base.dy - height - 8 * u,
        );
      c.drawPath(arm, pole);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(base.dx + side * 25 * u, base.dy - height - 7 * u),
            width: 13 * u,
            height: 4.4 * u,
          ),
          Radius.circular(2 * u),
        ),
        Paint()..color = const Color(0xFFDDE3E6),
      );
    }
    c.drawRect(
      Rect.fromCenter(center: base.translate(0, -3 * u), width: 6 * u, height: 7 * u),
      Paint()..color = const Color(0xFF6E757B),
    );
  }

  /// Le trou : la boue autour, l'eau au fond, une branche et un pneu pour prévenir.
  static void pothole(Canvas c, Offset at, double u) {
    c.save();
    c.translate(at.dx, at.dy);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 132 * u, height: 22 * u),
      Paint()..color = const Color(0xFF8A6E4E),
    );
    final hole = Path();
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2, k = 0.82 + 0.3 * _rnd(i, 61);
      final p = Offset(math.cos(a) * 54 * u * k, math.sin(a) * 7.6 * u * k);
      i == 0 ? hole.moveTo(p.dx, p.dy) : hole.lineTo(p.dx, p.dy);
    }
    hole.close();
    c.drawPath(hole, Paint()..color = const Color(0xFF2B211A));
    c.drawOval(
      Rect.fromCenter(center: Offset(4 * u, 1.4 * u), width: 70 * u, height: 7 * u),
      Paint()..color = const Color(0xFF6E5A46),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(-6 * u, 1 * u), width: 30 * u, height: 2.4 * u),
      Paint()..color = const Color(0x66D8E6EE),
    );
    // Des fissures qui partent du bord.
    final crack = Paint()
      ..color = const Color(0xFF3A3432)
      ..strokeWidth = 1.2 * u;
    for (final (a, b) in const [(-66.0, -4.0), (70.0, 3.0), (-40.0, 10.0), (38.0, -10.0)]) {
      c.drawLine(Offset(a * 0.84 * u, b * 0.5 * u), Offset(a * 1.25 * u, b * 1.3 * u), crack);
    }
    // Le vieux pneu debout dans le trou, et la branche plantée dedans.
    c.drawOval(
      Rect.fromCenter(center: Offset(-30 * u, -9 * u), width: 15 * u, height: 22 * u),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.6 * u
        ..color = const Color(0xFF1B1B1D),
    );
    final branch = Paint()
      ..color = const Color(0xFF5A4030)
      ..strokeWidth = 2 * u
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(14 * u, 1 * u), Offset(20 * u, -34 * u), branch);
    c.drawLine(Offset(18 * u, -20 * u), Offset(28 * u, -30 * u), branch);
    for (final p in const [Offset(20, -36), Offset(29, -32), Offset(15, -30), Offset(24, -26)]) {
      c.drawOval(
        Rect.fromCenter(center: p * u, width: 11 * u, height: 6 * u),
        Paint()..color = const Color(0xFF3C7C3E),
      );
    }
    c.restore();
  }

  // ------------------------------------------------------------- ce qui roule

  static void _wheel(Canvas c, Offset at, double r, double t) {
    c.drawCircle(at, r, Paint()..color = const Color(0xFF17171A));
    c.drawCircle(at, r * 0.52, Paint()..color = const Color(0xFF9AA0A6));
    final spoke = Paint()
      ..color = const Color(0xFF4A4E54)
      ..strokeWidth = r * 0.16;
    for (var i = 0; i < 3; i++) {
      final a = t * 16 + i * math.pi / 3;
      c.drawLine(
        at + Offset(math.cos(a), math.sin(a)) * r * 0.5,
        at - Offset(math.cos(a), math.sin(a)) * r * 0.5,
        spoke,
      );
    }
  }

  static void _shadow(Canvas c, double half, double u) => c.drawOval(
    Rect.fromCenter(center: Offset(0, 1.5), width: half * 2.1, height: 8),
    Paint()..color = const Color(0x55000000),
  );

  static void _begin(Canvas c, Offset base, double k, bool flip, [double lean = 0]) {
    c.save();
    c.translate(base.dx, base.dy);
    c.scale(flip ? -k : k, k);
    if (lean != 0) c.rotate(lean);
  }

  static const _skins = [Color(0xFF5A3A26), Color(0xFF6B4530), Color(0xFF4A2E1E), Color(0xFF7A4E34)];

  static TextPainter? _slogan;

  /// Le « 207 » : le minibus Mercedes bleu en haut, jaune en bas, plein à craquer, le receveur à la porte.
  static void bus207(Canvas c, Offset base, double k, double t, {bool flip = false}) {
    _begin(c, base, k, flip);
    _shadow(c, 64, 1);
    // Il tremble sur ses vieux amortisseurs.
    c.translate(0, math.sin(t * 13) * 0.6);
    final body = Path()
      ..moveTo(-62, -9)
      ..lineTo(-62, -58)
      ..quadraticBezierTo(-62, -67, -53, -67)
      ..lineTo(30, -67)
      ..quadraticBezierTo(37, -67, 41, -60)
      ..lineTo(50, -42)
      ..lineTo(61, -39)
      ..quadraticBezierTo(64, -38, 64, -33)
      ..lineTo(64, -9)
      ..close();
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTRB(-70, -70, 70, 0), Paint()..color = const Color(0xFFF2C230));
    c.drawRect(const Rect.fromLTRB(-70, -70, 70, -37), Paint()..color = const Color(0xFF2E9BD6));
    c.drawRect(const Rect.fromLTRB(-70, -70, 70, -62), Paint()..color = const Color(0xFF6FC0EA));
    c.drawRect(const Rect.fromLTRB(-70, -22, 70, -18), Paint()..color = const Color(0xFF2E9BD6));
    // La rouille et la poussière du bas de caisse.
    c.drawRect(const Rect.fromLTRB(-70, -13, 70, 0), Paint()..color = const Color(0x448A5A2B));
    for (final (x, y, r) in const [(-40.0, -30.0, 5.0), (12.0, -14.0, 4.0), (-12.0, -50.0, 3.0), (48.0, -24.0, 3.5)]) {
      c.drawCircle(Offset(x, y), r, Paint()..color = const Color(0x557A4A26));
    }
    c.restore();
    c.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF1F4E6B),
    );
    // Le pare-brise et les vitres : des têtes à chaque fenêtre.
    const glass = Color(0xFF22323C);
    c.drawPath(
      Path()
        ..moveTo(33, -62)
        ..lineTo(38, -61)
        ..lineTo(47, -43)
        ..lineTo(33, -43)
        ..close(),
      Paint()..color = glass,
    );
    c.drawCircle(const Offset(37, -49), 4, Paint()..color = _skins[0]);
    for (var i = 0; i < 4; i++) {
      if (i == 3) continue; // la porte
      final x = -56.0 + i * 21;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, -61, 18, 19), const Radius.circular(2)),
        Paint()..color = glass,
      );
      for (var j = 0; j < 2; j++) {
        final bob = math.sin(t * 9 + i * 2 + j) * 0.7;
        c.drawCircle(Offset(x + 5 + j * 8, -48 + bob + j * 1.5), 3.9, Paint()..color = _skins[(i + j) % _skins.length]);
        c.drawRect(
          Rect.fromLTWH(x + 1.5 + j * 8, -44.5 + bob, 7, 3),
          Paint()..color = _awnings[(i * 2 + j) % _awnings.length],
        );
      }
      c.drawRect(Rect.fromLTWH(x, -61, 18, 2.5), Paint()..color = const Color(0x33FFFFFF));
    }
    // La porte coulissante ouverte, et le receveur accroché dehors qui appelle les clients.
    c.drawRect(const Rect.fromLTRB(8, -61, 28, -11), Paint()..color = const Color(0xFF141C22));
    final wave = math.sin(t * 6) * 4;
    final limb = Paint()
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(19, -30), const Offset(18, -11), limb..color = const Color(0xFF2B2B33));
    c.drawLine(const Offset(22, -30), const Offset(24, -11), limb);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(15, -48, 11, 19), const Radius.circular(3)),
      Paint()..color = const Color(0xFFC0392B),
    );
    c.drawLine(const Offset(24, -45), Offset(36, -52 + wave), limb..color = _skins[1]);
    c.drawLine(const Offset(17, -45), const Offset(12, -58), limb);
    c.drawCircle(const Offset(21, -53), 4.6, Paint()..color = _skins[1]);
    // Le phare, le pare-chocs, le feu arrière.
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(58, -34, 6, 7), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFF2B0),
    );
    c.drawRect(const Rect.fromLTRB(52, -13, 67, -8), Paint()..color = const Color(0xFF3A3F45));
    c.drawRect(const Rect.fromLTRB(-64, -13, -56, -8), Paint()..color = const Color(0xFF3A3F45));
    c.drawRect(const Rect.fromLTRB(-63, -34, -60, -26), Paint()..color = const Color(0xFFC0392B));
    // Son nom de guerre, peint sur le flanc.
    if (!flip) {
      final p = _slogan ??= TextPainter(
        text: const TextSpan(
          text: 'ESPRIT DE MORT',
          style: TextStyle(color: Color(0xFF14324A), fontSize: 6.4, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(c, const Offset(-56, -34));
    }
    c.drawCircle(const Offset(-36, -9), 11.5, Paint()..color = const Color(0xFF1A2A33));
    c.drawCircle(const Offset(40, -9), 11.5, Paint()..color = const Color(0xFF1A2A33));
    _wheel(c, const Offset(-36, -9), 9.5, t);
    _wheel(c, const Offset(40, -9), 9.5, t);
    c.restore();
  }

  /// Une voiture : le taxi jaune de Kinshasa par défaut, ou une voiture d'une autre couleur.
  static void car(
    Canvas c,
    Offset base,
    double k,
    double t, {
    bool flip = false,
    Color color = const Color(0xFFF4C20D),
    bool taxi = true,
  }) {
    _begin(c, base, k, flip);
    _shadow(c, 43, 1);
    final body = Path()
      ..moveTo(-42, -8)
      ..lineTo(-42, -24)
      ..quadraticBezierTo(-41, -29, -36, -30)
      ..lineTo(-27, -41)
      ..quadraticBezierTo(-25, -43, -21, -43)
      ..lineTo(5, -43)
      ..quadraticBezierTo(9, -43, 12, -40)
      ..lineTo(23, -29)
      ..lineTo(37, -26)
      ..quadraticBezierTo(43, -24, 43, -18)
      ..lineTo(43, -8)
      ..close();
    c.drawPath(body, Paint()..color = color);
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTRB(-50, -50, 50, -36), Paint()..color = const Color(0x33FFFFFF));
    c.drawRect(const Rect.fromLTRB(-50, -14, 50, 0), Paint()..color = const Color(0x2A000000));
    c.restore();
    // Les vitres, le montant, le chauffeur.
    c.drawPath(
      Path()
        ..moveTo(-33, -30)
        ..lineTo(-25, -40)
        ..lineTo(4, -40)
        ..lineTo(18, -29)
        ..close(),
      Paint()..color = const Color(0xFF22323C),
    );
    c.drawRect(const Rect.fromLTRB(-9, -40, -6.5, -29), Paint()..color = color);
    c.drawCircle(const Offset(3, -33.5), 3.6, Paint()..color = _skins[2]);
    if (taxi) c.drawCircle(const Offset(-17, -33.5), 3.4, Paint()..color = _skins[0]);
    final line = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 0.7;
    c.drawLine(const Offset(-8, -29), const Offset(-8, -10), line);
    c.drawLine(const Offset(18, -29), const Offset(19, -10), line);
    c.drawRect(const Rect.fromLTRB(-3, -25, 2, -23.6), Paint()..color = const Color(0x77000000));
    // Les feux, les pare-chocs.
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(37, -24, 6, 4.5), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFFFFF7D0),
    );
    c.drawRect(const Rect.fromLTRB(-43, -25, -40, -19), Paint()..color = const Color(0xFFC0392B));
    c.drawRect(const Rect.fromLTRB(34, -12, 45, -8), Paint()..color = const Color(0xFF3A3F45));
    c.drawRect(const Rect.fromLTRB(-45, -12, -36, -8), Paint()..color = const Color(0xFF3A3F45));
    if (!taxi) {
      // La roue de secours à l'arrière.
      c.drawOval(const Rect.fromLTRB(-48, -30, -42, -12), Paint()..color = const Color(0xFF2A2A2E));
    }
    c.drawCircle(const Offset(-26, -8), 9.6, Paint()..color = const Color(0xFF1E1E22));
    c.drawCircle(const Offset(27, -8), 9.6, Paint()..color = const Color(0xFF1E1E22));
    _wheel(c, const Offset(-26, -8), 7.8, t);
    _wheel(c, const Offset(27, -8), 7.8, t);
    c.restore();
  }

  /// Le Wewa : la moto-taxi (un modèle chinois de 125 cm³, comme sur le boulevard), son chauffeur penché sur
  /// le guidon et ses clients serrés derrière lui. Elle roule : les rayons tournent, le pot fume, l'air file.
  /// [amazed] : le chauffeur voit l'avion, tourne la tête et lève le bras, bouche ouverte.
  static void wewa(
    Canvas c,
    Offset base,
    double k,
    double t, {
    bool flip = false,
    int riders = 3,
    double lean = 0,
    double amazed = 0,
  }) {
    _begin(c, base, k, flip, lean);
    _shadow(c, 36, 1);
    // L'air qui file derrière : la moto avance.
    for (final (y, len) in const [(-8.0, 16.0), (-21.0, 11.0), (-36.0, 13.0)]) {
      final off = (t * 90 + y * 7) % 24;
      c.drawLine(
        Offset(-38 - off, y),
        Offset(-38 - off - len, y),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
    // La fumée du pot, en petites bouffées.
    for (var i = 0; i < 3; i++) {
      final age = (t * 1.6 + i / 3) % 1.0;
      c.drawCircle(
        Offset(-32 - age * 22, -12 - age * 6),
        2 + age * 4,
        Paint()..color = Color.fromRGBO(170, 170, 170, 0.35 * (1 - age)),
      );
    }
    c.translate(0, math.sin(t * 17) * 0.45);

    const rear = Offset(-23, -10), front = Offset(24, -10);
    final dark = Paint()
      ..color = const Color(0xFF26292E)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final chrome = Paint()
      ..color = const Color(0xFFC9CED3)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const blue = Color(0xFF1F5E96), blueLight = Color(0xFF3F86C6);

    void wheel(Offset at) {
      c.drawCircle(at, 10, Paint()..color = const Color(0xFF151618));
      c.drawCircle(at, 7.6, Paint()..color = const Color(0xFF2E3136));
      c.drawCircle(
        at,
        7.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFB8BEC4),
      );
      final spoke = Paint()
        ..color = const Color(0xAAD5DADF)
        ..strokeWidth = 0.45;
      for (var i = 0; i < 9; i++) {
        final a = t * 22 + i * math.pi / 4.5;
        c.drawLine(at, at + Offset(math.cos(a), math.sin(a)) * 7, spoke);
      }
      c.drawCircle(at, 1.9, Paint()..color = const Color(0xFF9AA0A6));
    }

    // La roue arrière, le bras oscillant, l'amortisseur à ressort jaune.
    wheel(rear);
    c.drawLine(rear, const Offset(-1, -15), dark..strokeWidth = 3);
    c.drawLine(
      const Offset(-19, -13),
      const Offset(-15, -26),
      Paint()
        ..color = const Color(0xFF3A3F45)
        ..strokeWidth = 1.6,
    );
    for (var i = 0; i < 5; i++) {
      final y = -14.5 - i * 2.3, x = -18.6 + i * 0.75;
      c.drawLine(
        Offset(x - 1.8, y),
        Offset(x + 1.8, y - 0.8),
        Paint()
          ..color = const Color(0xFFF2C230)
          ..strokeWidth = 1.1,
      );
    }
    // Le garde-boue arrière, le porte-bagages, le feu rouge.
    c.drawArc(
      Rect.fromCircle(center: rear, radius: 12.5),
      math.pi * 1.05,
      math.pi * 0.62,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = blue,
    );
    c.drawLine(const Offset(-20, -27.5), const Offset(-33, -27), chrome);
    c.drawLine(const Offset(-33, -27), const Offset(-31, -21), chrome);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-35.5, -26, 4.5, 3.2), const Radius.circular(1)),
      Paint()..color = const Color(0xFFD6302A),
    );
    // Le moteur et ses ailettes, la chaîne, le pot d'échappement chromé.
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -20, 13, 11), const Radius.circular(2.6)),
      Paint()..color = const Color(0xFF6E757C),
    );
    for (var i = 0; i < 4; i++) {
      c.drawLine(
        Offset(-3 + i * 3.0, -19),
        Offset(-3 + i * 3.0, -11),
        Paint()
          ..color = const Color(0xFF4A4F55)
          ..strokeWidth = 1,
      );
    }
    c.drawCircle(const Offset(-1, -12.5), 2.6, Paint()..color = const Color(0xFF8E959C));
    c.drawLine(
      const Offset(-1, -12.5),
      rear + const Offset(0, -2),
      Paint()
        ..color = const Color(0xFF1B1C1F)
        ..strokeWidth = 1.4,
    );
    final pipe = Path()
      ..moveTo(4, -12)
      ..quadraticBezierTo(0, -6, -10, -7)
      ..lineTo(-24, -9);
    c.drawPath(pipe, chrome..strokeWidth = 2.6);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-33, -12, 15, 5.2), const Radius.circular(2.4)),
      Paint()..color = const Color(0xFFD5DADF),
    );
    c.drawRect(const Rect.fromLTWH(-31, -11, 11, 1.2), Paint()..color = const Color(0x66FFFFFF));
    // Le cadre, le cache latéral bleu sous la selle.
    c.drawLine(const Offset(-1, -15), const Offset(14, -31), dark..strokeWidth = 3.2);
    c.drawPath(
      Path()
        ..moveTo(-17, -26)
        ..lineTo(-2, -26)
        ..lineTo(1, -19)
        ..lineTo(-12, -19)
        ..close(),
      Paint()..color = blue,
    );
    c.drawLine(
      const Offset(-14, -23),
      const Offset(-3, -23),
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..strokeWidth = 0.9,
    );
    // La selle longue, le réservoir bleu avec son filet blanc.
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -30.5, 26, 5), const Radius.circular(2.5)),
      Paint()..color = const Color(0xFF17181B),
    );
    final tank = Path()
      ..moveTo(1, -26)
      ..quadraticBezierTo(2, -33, 9, -33)
      ..quadraticBezierTo(15, -33, 16, -28)
      ..lineTo(13, -24)
      ..close();
    c.drawPath(tank, Paint()..color = blue);
    c.drawPath(
      Path()
        ..moveTo(3, -29)
        ..quadraticBezierTo(8, -32, 14, -30),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xDDFFFFFF),
    );
    c.drawOval(const Rect.fromLTWH(5, -32.5, 6, 2), Paint()..color = blueLight);
    // La roue avant, sa fourche chromée, son garde-boue, le phare et le guidon.
    wheel(front);
    c.drawLine(front, const Offset(17.5, -33), dark..strokeWidth = 3);
    c.drawLine(front + const Offset(-0.6, -2), const Offset(18.6, -26), chrome..strokeWidth = 1.6);
    c.drawArc(
      Rect.fromCircle(center: front, radius: 12),
      math.pi * 1.15,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = blue,
    );
    c.drawPath(
      Path()
        ..moveTo(17, -36)
        ..quadraticBezierTo(25, -35, 24.5, -29)
        ..lineTo(19, -28)
        ..close(),
      Paint()..color = blue,
    );
    c.drawOval(const Rect.fromLTWH(21, -34, 4.4, 5), Paint()..color = const Color(0xFFFFF4C2));
    c.drawLine(const Offset(17.5, -34), const Offset(12, -38.5), dark..strokeWidth = 2);
    c.drawLine(
      const Offset(12, -38.5),
      const Offset(10, -38.5),
      Paint()
        ..color = const Color(0xFF111111)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      const Offset(17, -35),
      const Offset(19, -41),
      Paint()
        ..color = const Color(0xFF9AA0A6)
        ..strokeWidth = 0.9,
    );
    c.drawCircle(const Offset(19.3, -41.5), 1.3, Paint()..color = const Color(0xFFC9CED3));

    // Les gens : d'abord les passagers (derrière), puis le chauffeur.
    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void head(Offset at, Color skin, int hat, {bool turned = false}) {
      c.drawCircle(at, 4.4, Paint()..color = skin);
      // Le nez et l'oreille : on voit le profil (ou le visage tourné vers l'avion).
      if (turned) {
        c.drawCircle(at + const Offset(-1.6, -0.6), 0.75, Paint()..color = Colors.white);
        c.drawCircle(at + const Offset(1.2, -0.6), 0.75, Paint()..color = Colors.white);
        c.drawCircle(at + const Offset(-1.6, -0.6), 0.4, Paint()..color = Colors.black);
        c.drawCircle(at + const Offset(1.2, -0.6), 0.4, Paint()..color = Colors.black);
        c.drawOval(
          Rect.fromCenter(center: at + const Offset(-0.2, 2.2), width: 1.8, height: 2.2),
          Paint()..color = const Color(0xFF2A0E0A),
        );
      } else {
        c.drawCircle(at + const Offset(4.3, 0.4), 1.2, Paint()..color = skin);
        c.drawCircle(at + const Offset(2.2, -1), 0.55, Paint()..color = Colors.black);
        c.drawCircle(at + const Offset(-1.2, 0.3), 1.1, Paint()..color = Color.lerp(skin, Colors.black, 0.25)!);
      }
      switch (hat) {
        case 1:
          c.drawArc(
            Rect.fromCircle(center: at + const Offset(0, -0.4), radius: 4.7),
            math.pi,
            math.pi,
            true,
            Paint()..color = const Color(0xFF1B1B1D),
          );
          c.drawLine(
            at + Offset(turned ? -4 : 3, -1.2),
            at + Offset(turned ? -8.5 : 8, -0.8),
            Paint()
              ..color = const Color(0xFF1B1B1D)
              ..strokeWidth = 1.4,
          );
        case 2:
          c.drawArc(
            Rect.fromCircle(center: at + const Offset(-0.5, -0.5), radius: 5),
            math.pi * 0.85,
            math.pi * 1.25,
            true,
            Paint()..color = const Color(0xFF3A2A44),
          );
          c.drawRect(Rect.fromLTWH(at.dx + 0.6, at.dy - 1.6, 4, 1.8), Paint()..color = const Color(0xFF0E0E10));
        case 3:
          c.drawArc(
            Rect.fromCircle(center: at, radius: 4.7),
            math.pi * 1.05,
            math.pi * 0.9,
            true,
            Paint()..color = const Color(0xFF2456A6),
          );
          c.drawLine(
            at + const Offset(3, -2),
            at + const Offset(8, -1.6),
            Paint()
              ..color = const Color(0xFF2456A6)
              ..strokeWidth = 1.3,
          );
      }
    }

    void passenger(double x, Color top, Color legs, Color skin, int hat) {
      final hip = Offset(x, -30), shoulder = Offset(x + 1.5, -45), knee = Offset(x + 8, -27);
      // La jambe : la cuisse vers l'avant, le tibia vers le repose-pied.
      c.drawLine(
        hip,
        knee,
        limb
          ..strokeWidth = 4.2
          ..color = legs,
      );
      c.drawLine(knee, Offset(x + 5, -14), limb..strokeWidth = 3.4);
      c.drawLine(
        Offset(x + 4, -13.5),
        Offset(x + 8.5, -13),
        limb
          ..strokeWidth = 2.6
          ..color = const Color(0xFFF1EEE6),
      );
      // Le buste droit, la main sur la taille de celui de devant.
      c.drawLine(
        hip,
        shoulder,
        limb
          ..strokeWidth = 7
          ..color = top,
      );
      c.drawLine(shoulder + const Offset(0.5, 2), Offset(x + 7, -36), limb..strokeWidth = 2.8);
      head(shoulder + const Offset(1.4, -6.6), skin, hat);
    }

    if (riders >= 3) passenger(-19, const Color(0xFF2456A6), const Color(0xFF2456A6), _skins[2], 3);
    if (riders >= 2) passenger(-11, const Color(0xFF8A5A3B), const Color(0xFF1B1B1D), _skins[3], 2);
    // Le chauffeur : penché sur le guidon, les mains sur les poignées, les pieds sur les repose-pieds.
    final skin = _skins[0];
    const hip = Offset(-2, -30), knee = Offset(9, -28), shoulder = Offset(5, -45);
    c.drawLine(
      hip,
      knee,
      limb
        ..strokeWidth = 4.4
        ..color = const Color(0xFF4A4238),
    );
    c.drawLine(knee, const Offset(4, -14), limb..strokeWidth = 3.6);
    c.drawLine(
      const Offset(3, -13.5),
      const Offset(8.5, -13),
      limb
        ..strokeWidth = 2.8
        ..color = const Color(0xFF111111),
    );
    c.drawLine(
      hip,
      shoulder,
      limb
        ..strokeWidth = 7.6
        ..color = const Color(0xFFB3261E),
    );
    c.drawLine(
      const Offset(0, -40),
      const Offset(7, -41),
      limb
        ..strokeWidth = 1.2
        ..color = const Color(0x66000000),
    );
    if (amazed > 0) {
      // Il lève le bras vers l'avion, l'autre main reste sur le guidon.
      final up = Offset.lerp(const Offset(10, -38), const Offset(-4, -60), amazed)!;
      c.drawLine(
        shoulder + const Offset(0, 1),
        up,
        limb
          ..strokeWidth = 2.8
          ..color = const Color(0xFFB3261E),
      );
      c.drawCircle(up, 1.7, Paint()..color = skin);
    }
    c.drawLine(
      shoulder + const Offset(1, 2),
      const Offset(10.5, -38.3),
      limb
        ..strokeWidth = 2.8
        ..color = const Color(0xFFB3261E),
    );
    c.drawCircle(const Offset(11, -38.4), 1.6, Paint()..color = skin);
    head(shoulder + const Offset(2.6, -6.2), skin, 1, turned: amazed > 0.5);
    c.restore();
  }

  // ------------------------------------------------------------ le pare-brise

  /// Le nez de l'avion vu de tout près : derrière le pare-brise, le commandant, son casque et son micro,
  /// et le copilote à côté. [talk] ouvre la bouche du commandant quand il parle.
  static void cockpit(
    Canvas c,
    Size s,
    double t,
    double fade, {
    required Color skin,
    required Color band,
    double talk = 0,
  }) {
    if (fade <= 0) return;
    final layered = fade < 1;
    if (layered) c.saveLayer(Offset.zero & s, Paint()..color = Color.fromRGBO(255, 255, 255, fade.clamp(0.0, 1.0)));
    c.save();
    // Un dessin de 1000 × 460 qui couvre l'écran ; on arrive en avançant vers la vitre.
    final k = math.max(s.width / 1000, s.height / 460) * (1.18 - 0.18 * _ease(fade));
    c.translate(s.width / 2, s.height / 2);
    c.scale(k);
    // L'avion est secoué.
    c.translate(-500 + math.sin(t * 23) * 1.6, -230 + math.sin(t * 31 + 1) * 1.8);
    // Les vitres prennent presque tout l'écran ; le haut reste libre pour la bulle de la réplique.
    c.translate(500, 205 + 34);
    c.scale(1.22);
    c.translate(-500, -205);

    // La peau du nez : claire en haut, à l'ombre en bas, la bande de la compagnie sous les vitres.
    const full = Rect.fromLTRB(-200, -200, 1200, 700);
    c.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(skin, Colors.white, 0.35)!, skin, Color.lerp(skin, const Color(0xFF3A4654), 0.4)!],
          stops: const [0.2, 0.55, 0.95],
        ).createShader(const Rect.fromLTRB(0, 0, 1000, 460)),
    );
    c.drawPath(
      Path()
        ..moveTo(-200, 372)
        ..quadraticBezierTo(500, 330, 1200, 372)
        ..lineTo(1200, 412)
        ..quadraticBezierTo(500, 372, -200, 412)
        ..close(),
      Paint()..color = band,
    );
    // Les lignes de tôle et les rivets.
    final seam = Paint()
      ..color = const Color(0x33203040)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    c.drawPath(
      Path()
        ..moveTo(-200, 62)
        ..quadraticBezierTo(500, 22, 1200, 62),
      seam,
    );
    c.drawLine(const Offset(500, -200), const Offset(500, 78), seam);
    for (var i = 0; i < 40; i++) {
      final x = 20.0 + i * 25, y = 70 - 40 * math.sin(x / 1000 * math.pi);
      c.drawCircle(Offset(x, y), 1.6, Paint()..color = const Color(0x44203040));
    }

    // Les quatre vitres du pare-brise.
    final panes = [
      Path()..addPolygon(const [Offset(96, 150), Offset(226, 112), Offset(196, 312), Offset(44, 296)], true),
      Path()..addPolygon(const [Offset(250, 106), Offset(490, 92), Offset(490, 318), Offset(218, 314)], true),
      Path()..addPolygon(const [Offset(510, 92), Offset(750, 106), Offset(782, 314), Offset(510, 318)], true),
      Path()..addPolygon(const [Offset(774, 112), Offset(904, 150), Offset(956, 296), Offset(804, 312)], true),
    ];
    final glassArea = Path();
    for (final p in panes) {
      glassArea.addPath(p, Offset.zero);
    }
    // Le cadre sombre autour des vitres.
    c.drawPath(
      glassArea,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF23272E),
    );
    c.save();
    c.clipPath(glassArea);
    // Dedans : la pénombre du poste, le panneau du plafond et ses voyants.
    c.drawRect(
      const Rect.fromLTRB(0, 60, 1000, 340),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C1420), Color(0xFF1B2A3E), Color(0xFF22344A)],
        ).createShader(const Rect.fromLTRB(0, 60, 1000, 340)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(400, 84, 600, 132), const Radius.circular(8)),
      Paint()..color = const Color(0xFF2A3442),
    );
    for (var i = 0; i < 18; i++) {
      final on = math.sin(t * (2 + i % 4) + i) > -0.2;
      c.drawCircle(
        Offset(414.0 + (i % 9) * 21.5, 98.0 + (i ~/ 9) * 19),
        3.2,
        Paint()
          ..color =
              (i % 5 == 0 ? const Color(0xFFFF5A4A) : (i.isEven ? const Color(0xFFFFC857) : const Color(0xFF6FE08A)))
                  .withValues(alpha: on ? 0.95 : 0.25),
      );
    }
    // L'alarme : la lumière rouge bat dans le poste.
    final alarm = 0.5 + 0.5 * math.sin(t * 7);
    c.drawRect(const Rect.fromLTRB(0, 60, 1000, 340), Paint()..color = Color.fromRGBO(255, 60, 40, 0.1 * alarm));

    _pilot(c, const Offset(362, 240), 1.0, t, captain: false, talk: 0);
    _pilot(c, const Offset(640, 238), 1.2, t, captain: true, talk: talk);

    // La casquette du tableau de bord, en bas des vitres, avec ses cadrans.
    c.drawPath(
      Path()
        ..moveTo(0, 300)
        ..quadraticBezierTo(500, 268, 1000, 300)
        ..lineTo(1000, 360)
        ..lineTo(0, 360)
        ..close(),
      Paint()..color = const Color(0xFF10151C),
    );
    for (var i = 0; i < 9; i++) {
      c.drawCircle(
        Offset(260.0 + i * 60, 299 - 12 * math.sin((260 + i * 60) / 1000 * math.pi)),
        3,
        Paint()
          ..color = (i == 4 ? const Color(0xFFFF5A4A) : const Color(0xFF6FE08A)).withValues(
            alpha: i == 4 ? alarm : 0.7,
          ),
      );
    }
    // Les reflets du ciel sur la vitre.
    c.drawRect(const Rect.fromLTRB(0, 60, 1000, 340), Paint()..color = const Color(0x1A9CCBFF));
    for (final (x, wdt) in const [(140.0, 34.0), (330.0, 60.0), (410.0, 18.0), (700.0, 48.0), (860.0, 26.0)]) {
      c.drawPath(
        Path()..addPolygon([
          Offset(x + 70, 60),
          Offset(x + 70 + wdt, 60),
          Offset(x - 50 + wdt, 340),
          Offset(x - 50, 340),
        ], true),
        Paint()..color = const Color(0x16FFFFFF),
      );
    }
    c.restore();
    // Les montants entre les vitres et les essuie-glaces.
    final frame = Paint()
      ..color = const Color(0xFF2E333B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeJoin = StrokeJoin.round;
    for (final p in panes) {
      c.drawPath(p, frame);
    }
    final wiper = Paint()
      ..color = const Color(0xFF14171B)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(300, 322), const Offset(452, 296), wiper);
    c.drawLine(const Offset(700, 322), const Offset(548, 296), wiper);
    c.restore();
    if (layered) c.restore();
  }

  /// Un pilote derrière la vitre : la casquette, le casque sur les oreilles, le micro devant la bouche,
  /// la chemise blanche et les galons. Le commandant fronce les sourcils ; le copilote ouvre de grands yeux.
  static void _pilot(Canvas c, Offset at, double k, double t, {required bool captain, required double talk}) {
    c.save();
    c.translate(at.dx, at.dy + math.sin(t * 9 + (captain ? 0 : 2)) * 1.5);
    c.scale(k);
    const face = Color(0xFF7A4B2A), shade = Color(0xFF5E381E), light = Color(0xFF94603A);
    // Le dossier du siège.
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(-58, -40, 58, 130), const Radius.circular(22)),
      Paint()..color = const Color(0xFF26364A),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(-34, -64, 34, -18), const Radius.circular(14)),
      Paint()..color = const Color(0xFF2E4058),
    );
    // Les épaules : la chemise blanche, la cravate, les galons dorés.
    c.drawPath(
      Path()
        ..moveTo(-82, 130)
        ..quadraticBezierTo(-78, 52, -30, 44)
        ..lineTo(30, 44)
        ..quadraticBezierTo(78, 52, 82, 130)
        ..close(),
      Paint()..color = const Color(0xFFF4F4F0),
    );
    c.drawPath(
      Path()
        ..addPolygon(const [Offset(-7, 46), Offset(7, 46), Offset(10, 110), Offset(0, 122), Offset(-10, 110)], true),
      Paint()..color = const Color(0xFF16233A),
    );
    c.drawPath(
      Path()..addPolygon(const [Offset(-30, 44), Offset(-7, 46), Offset(-16, 70)], true),
      Paint()..color = const Color(0xFFDADAD4),
    );
    c.drawPath(
      Path()..addPolygon(const [Offset(30, 44), Offset(7, 46), Offset(16, 70)], true),
      Paint()..color = const Color(0xFFDADAD4),
    );
    for (final side in const [-1.0, 1.0]) {
      c.save();
      c.translate(side * 56, 58);
      c.rotate(side * 0.2);
      c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(-17, -8, 17, 8), const Radius.circular(3)),
        Paint()..color = const Color(0xFF16233A),
      );
      for (var i = 0; i < (captain ? 4 : 3); i++) {
        c.drawRect(Rect.fromLTWH(-13.0 + i * 7, -6, 3.6, 12), Paint()..color = const Color(0xFFF2C230));
      }
      c.restore();
    }
    // Le cou, puis le visage.
    c.drawRect(const Rect.fromLTRB(-14, 22, 14, 50), Paint()..color = shade);
    c.drawOval(const Rect.fromLTRB(-37, -42, 37, 40), Paint()..color = face);
    c.drawOval(const Rect.fromLTRB(-37, -10, -20, 30), Paint()..color = shade.withValues(alpha: 0.5));
    c.drawOval(const Rect.fromLTRB(-10, -8, 22, 12), Paint()..color = light.withValues(alpha: 0.35));
    // Les yeux et les sourcils.
    final wide = captain ? 1.0 : 1.35;
    for (final side in const [-1.0, 1.0]) {
      final eye = Offset(side * 14, -6);
      c.drawOval(Rect.fromCenter(center: eye, width: 15, height: 9.5 * wide), Paint()..color = const Color(0xFFF7F4EC));
      c.drawCircle(eye.translate(captain ? 1.5 : -1, captain ? 1 : 0.5), 3.9, Paint()..color = const Color(0xFF1B120C));
      c.drawCircle(eye.translate(captain ? 2.4 : 0, -0.6), 1.1, Paint()..color = Colors.white);
      final brow = Paint()
        ..color = const Color(0xFF120B07)
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round;
      captain
          // En colère : les sourcils plongent vers le nez.
          ? c.drawLine(eye + Offset(side * 10, -13), eye + Offset(-side * 7, -8), brow)
          // Effrayé : ils montent.
          : c.drawLine(eye + Offset(side * 9, -13), eye + Offset(-side * 7, -17), brow);
    }
    c.drawPath(
      Path()
        ..moveTo(-3, -2)
        ..quadraticBezierTo(-8, 12, 0, 14)
        ..quadraticBezierTo(8, 12, 4, 6),
      Paint()
        ..color = shade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    // La bouche : elle s'ouvre quand il parle (ou reste ronde de peur).
    final open = captain ? talk : 0.55 + 0.15 * math.sin(t * 3);
    final mouth = Rect.fromCenter(center: const Offset(0, 25), width: captain ? 24 : 15, height: 3 + 13 * open);
    c.drawOval(mouth, Paint()..color = const Color(0xFF2A0E0A));
    if (open > 0.25) {
      c.drawRect(
        Rect.fromLTRB(mouth.left + 4, mouth.top + 1, mouth.right - 4, mouth.top + 4),
        Paint()..color = const Color(0xFFF7F4EC),
      );
    }
    // Une goutte de sueur.
    final drop = (t * 0.5 + (captain ? 0 : 0.5)) % 1.0;
    c.drawOval(
      Rect.fromCenter(center: Offset(captain ? 30 : -30, -18 + drop * 34), width: 5, height: 8),
      Paint()..color = Color.fromRGBO(190, 225, 255, 0.85 * (1 - drop)),
    );

    // La casquette : la coiffe bleu nuit, l'insigne doré, la visière.
    c.drawPath(
      Path()
        ..moveTo(-42, -32)
        ..quadraticBezierTo(-46, -72, 0, -74)
        ..quadraticBezierTo(46, -72, 42, -32)
        ..close(),
      Paint()..color = const Color(0xFF16233A),
    );
    c.drawRect(const Rect.fromLTRB(-40, -40, 40, -31), Paint()..color = const Color(0xFF0C1524));
    c.drawPath(
      Path()
        ..moveTo(-40, -32)
        ..quadraticBezierTo(0, -16, 40, -32)
        ..quadraticBezierTo(0, -26, -40, -32)
        ..close(),
      Paint()..color = const Color(0xFF05080E),
    );
    c.drawOval(const Rect.fromLTRB(-9, -62, 9, -44), Paint()..color = const Color(0xFFF2C230));
    c.drawPath(
      Path()..addPolygon(const [Offset(-17, -52), Offset(-8, -56), Offset(-8, -49)], true),
      Paint()..color = const Color(0xFFF2C230),
    );
    c.drawPath(
      Path()..addPolygon(const [Offset(17, -52), Offset(8, -56), Offset(8, -49)], true),
      Paint()..color = const Color(0xFFF2C230),
    );
    // Le casque : l'arceau par-dessus la casquette, les deux coques, le bras du micro.
    c.drawArc(
      const Rect.fromLTRB(-45, -84, 45, 6),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF0A0C10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    for (final side in const [-1.0, 1.0]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(side * 43, -2), width: 21, height: 36),
        const Radius.circular(9),
      );
      c.drawRRect(cup, Paint()..color = const Color(0xFF15181D));
      c.drawRRect(cup.deflate(4), Paint()..color = const Color(0xFF3A4048));
      c.drawCircle(Offset(side * 43, -2), 3, Paint()..color = const Color(0xFF6FE08A));
    }
    c.drawPath(
      Path()
        ..moveTo(-43, 12)
        ..quadraticBezierTo(-40, 36, -15, 31),
      Paint()
        ..color = const Color(0xFF0A0C10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );
    c.drawOval(const Rect.fromLTRB(-21, 25, -8, 37), Paint()..color = const Color(0xFF15181D));
    // Les mains crispées sur le manche.
    c.drawPath(
      Path()
        ..moveTo(-44, 120)
        ..lineTo(-44, 98)
        ..lineTo(-30, 98)
        ..lineTo(-30, 112)
        ..lineTo(30, 112)
        ..lineTo(30, 98)
        ..lineTo(44, 98)
        ..lineTo(44, 120)
        ..close(),
      Paint()..color = const Color(0xFF0B0E12),
    );
    for (final side in const [-1.0, 1.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(side * 37, 96), width: 21, height: 17),
          const Radius.circular(7),
        ),
        Paint()..color = face,
      );
      for (var i = 0; i < 3; i++) {
        c.drawLine(
          Offset(side * 37 - 6 + i * 6, 89),
          Offset(side * 37 - 6 + i * 6, 97),
          Paint()
            ..color = shade
            ..strokeWidth = 1.4,
        );
      }
    }
    c.restore();
  }
}
