import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/chacha_game.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';

/// Le tableau de bord : assiette, altitude, kérosène, vitesse et état de l'avion.
///
/// En zone de turbulence, il passe au rouge ; kérosène bas, l'aiguille clignote.
class CockpitPanel extends StatelessWidget {
  const CockpitPanel({super.key, required this.hud});

  final HudState hud;

  @override
  Widget build(BuildContext context) {
    final war = hud.inZone;
    final low = hud.fuel < 25;
    return Glass(
      tint: war ? const Color(0x55400008) : const Color(0x40001A40),
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // À gauche : l'assiette et l'altitude en haut, le réservoir en dessous.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Les deux cadrans sur la même ligne : le cadran, sa valeur, puis son nom.
                  _Dial(
                    label: 'ASSIETTE',
                    value: '${(-hud.pitch * 57.3).round() >= 0 ? '+' : ''}${(-hud.pitch * 57.3).round()}°',
                    painter: _HorizonPainter(hud.pitch),
                  ),
                  _Dial(
                    label: 'ALTITUDE',
                    value: '${(hud.altitude / 100).round() * 100} ft',
                    painter: _AltimeterPainter(hud.altitude),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _Tank(fuel: hud.fuel, reserve: hud.reserve, low: low),
            ],
          ),
          const SizedBox(width: 12),
          // À droite : les chiffres du vol, bien lisibles.
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (war)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0x55CE1021), borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                    'ALERTE GUERRE',
                    style: TextStyle(
                      color: Color(0xFFFF9A9A),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              _small('VITESSE', '${hud.speedKmh.round()} km/h', hot: hud.boost ? 'TURBO' : null),
              const SizedBox(height: 6),
              _small('PASSAGERS', '${hud.passengers} / ${hud.seats}'),
              const SizedBox(height: 6),
              // Sous 25 %, l'état passe en rouge et demande la réparation : un choc de plus peut faire tomber l'avion.
              _small(
                'ÉTAT',
                '${hud.condition.round()} %',
                hot: hud.condition <= 25 ? 'RÉPARER' : null,
                color: hud.condition <= 25 ? const Color(0xFFFF8A8A) : Colors.white,
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (hud.condition / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: AlwaysStoppedAnimation(hud.condition < 35 ? ChachaColors.red : const Color(0xFF7CF0A6)),
                  ),
                ),
              ),
              if (hud.armor > 0) ...[
                const SizedBox(height: 6),
                _small('PROTECTION', '${(hud.armor * 100).round()} %', color: const Color(0xFF8FD0FF)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Widget _small(String label, String value, {String? hot, Color color = Colors.white}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              height: 1.15,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (hot != null) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(5)),
              child: Text(
                hot,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

/// Le réservoir, vu comme une vraie jauge : il se vide de droite à gauche, vert, puis orange, puis rouge.
/// La réserve s'écrit dessous : elle se verse toute seule quand le réservoir tombe à 12 %.
class _Tank extends StatelessWidget {
  const _Tank({required this.fuel, required this.reserve, required this.low});

  final double fuel;
  final double reserve;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final f = (fuel / 100).clamp(0.0, 1.0);
    final color = fuel < 25
        ? ChachaColors.red
        : fuel < 50
        ? const Color(0xFFFFA62B)
        : const Color(0xFF3DDC84);
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.local_gas_station_rounded, size: 12, color: low ? const Color(0xFFFF7A7A) : Colors.white70),
              const SizedBox(width: 3),
              Text(
                'KÉROSÈNE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF0B1424),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: low ? const Color(0xFFFF7A7A) : const Color(0x88FFFFFF), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.5),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: f,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                        ),
                      ),
                    ),
                  ),
                  // Les repères du quart, de la moitié et des trois quarts.
                  for (final k in const [0.25, 0.5, 0.75])
                    Align(
                      alignment: Alignment(k * 2 - 1, 0),
                      child: Container(width: 1, height: 8, color: const Color(0x66FFFFFF)),
                    ),
                  Center(
                    child: Text(
                      '${fuel.clamp(0, 100).round()} %',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            reserve >= 1 ? '+ réserve ${reserve.round()} %' : 'pas de réserve',
            style: TextStyle(
              color: reserve >= 1 ? const Color(0xFF9CF0B8) : Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.label, required this.painter, this.value});

  final String label;
  final String? value;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 54, height: 54, child: CustomPaint(painter: painter)),
          const SizedBox(height: 2),
          Text(
            value ?? label,
            style: TextStyle(
              color: Colors.white,
              fontSize: value == null ? 8.5 : 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: value == null ? 1 : 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (value != null)
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
        ],
      ),
    );
  }
}

void _bezel(Canvas c, Offset o, double r) {
  c.drawCircle(o, r, Paint()..color = const Color(0xFF0B1424));
  c.drawCircle(
    o,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x88FFFFFF),
  );
}

/// L'horizon artificiel : ciel bleu, terre brune, qui basculent avec l'assiette.
class _HorizonPainter extends CustomPainter {
  _HorizonPainter(this.pitch);

  final double pitch;

  @override
  void paint(Canvas c, Size s) {
    final o = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r)));
    c.translate(o.dx, o.dy);
    c.rotate(-pitch * 0.6);
    final shift = (pitch * r * 1.6).clamp(-r * 0.8, r * 0.8);
    c.drawRect(Rect.fromLTRB(-r * 2, -r * 2, r * 2, shift), Paint()..color = ChachaColors.sky);
    c.drawRect(Rect.fromLTRB(-r * 2, shift, r * 2, r * 2), Paint()..color = const Color(0xFF8A5A2B));
    c.drawLine(
      Offset(-r * 2, shift),
      Offset(r * 2, shift),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
    for (final k in [-1, 1]) {
      c.drawLine(
        Offset(-r * 0.25, shift + k * r * 0.3),
        Offset(r * 0.25, shift + k * r * 0.3),
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..strokeWidth = 1,
      );
    }
    c.restore();
    // La maquette de l'avion, fixe au centre
    final mock = Paint()
      ..color = ChachaColors.yellow
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(o.translate(-r * 0.55, 0), o.translate(-r * 0.18, 0), mock);
    c.drawLine(o.translate(r * 0.18, 0), o.translate(r * 0.55, 0), mock);
    c.drawCircle(o, 2.5, mock);
    c.drawCircle(
      o,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x88FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.pitch != pitch;
}

/// L'altimètre : une grande aiguille pour les milliers de pieds, une petite pour les dizaines de milliers.
class _AltimeterPainter extends CustomPainter {
  _AltimeterPainter(this.feet);

  final double feet;

  @override
  void paint(Canvas c, Size s) {
    final o = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    _bezel(c, o, r);
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      c.drawLine(
        o + Offset(math.cos(a), math.sin(a)) * r * 0.78,
        o + Offset(math.cos(a), math.sin(a)) * r * 0.92,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5,
      );
    }
    void hand(double turns, double len, double width, Color color) {
      final a = -math.pi / 2 + turns * math.pi * 2;
      c.drawLine(
        o,
        o + Offset(math.cos(a), math.sin(a)) * r * len,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand(feet / 100000, 0.45, 3.5, ChachaColors.yellow);
    hand(feet / 10000, 0.75, 2, Colors.white);
    c.drawCircle(o, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AltimeterPainter old) => old.feet != feet;
}
