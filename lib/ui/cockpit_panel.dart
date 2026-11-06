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
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dial(label: 'ASSIETTE', painter: _HorizonPainter(hud.pitch)),
          _Dial(
            label: 'ALTITUDE',
            value: '${(hud.altitude / 100).round() * 100} ft',
            painter: _AltimeterPainter(hud.altitude),
          ),
          _Dial(
            label: 'KÉROSÈNE',
            value: '${hud.fuel.clamp(0, 100).round()} %',
            alert: low,
            painter: _FuelPainter(hud.fuel / 100, low),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (war)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0x55CE1021), borderRadius: BorderRadius.circular(6)),
                  child: const Text('ALERTE GUERRE',
                      style: TextStyle(color: Color(0xFFFF9A9A), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              _small('VITESSE', '${hud.speedKmh.round()} km/h'),
              const SizedBox(height: 5),
              _small('PASSAGERS', '${hud.passengers} / ${hud.seats}'),
              const SizedBox(height: 5),
              _small('ÉTAT', '${hud.condition.round()} %'),
              const SizedBox(height: 3),
              SizedBox(
                width: 78,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (hud.condition / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: AlwaysStoppedAnimation(
                        hud.condition < 35 ? ChachaColors.red : const Color(0xFF7CF0A6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _small(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      );
}

class _Dial extends StatelessWidget {
  const _Dial({required this.label, required this.painter, this.value, this.alert = false});

  final String label;
  final String? value;
  final bool alert;
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
          Text(value ?? label,
              style: TextStyle(
                  color: alert ? const Color(0xFFFF7A7A) : Colors.white,
                  fontSize: value == null ? 8.5 : 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: value == null ? 1 : 0,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          if (value != null)
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
        ..color = const Color(0x88FFFFFF));
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
    c.drawLine(Offset(-r * 2, shift), Offset(r * 2, shift), Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5);
    for (final k in [-1, 1]) {
      c.drawLine(Offset(-r * 0.25, shift + k * r * 0.3), Offset(r * 0.25, shift + k * r * 0.3), Paint()
        ..color = const Color(0xAAFFFFFF)
        ..strokeWidth = 1);
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
          ..color = const Color(0x88FFFFFF));
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
      c.drawLine(o + Offset(math.cos(a), math.sin(a)) * r * 0.78, o + Offset(math.cos(a), math.sin(a)) * r * 0.92,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5);
    }
    void hand(double turns, double len, double width, Color color) {
      final a = -math.pi / 2 + turns * math.pi * 2;
      c.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * r * len, Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round);
    }

    hand(feet / 100000, 0.45, 3.5, ChachaColors.yellow);
    hand(feet / 10000, 0.75, 2, Colors.white);
    c.drawCircle(o, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AltimeterPainter old) => old.feet != feet;
}

/// La jauge de kérosène : de V (vide) à P (plein), zone rouge sous 25 %.
class _FuelPainter extends CustomPainter {
  _FuelPainter(this.level, this.low);

  final double level;
  final bool low;

  @override
  void paint(Canvas c, Size s) {
    final o = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    _bezel(c, o, r);
    const start = math.pi * 0.75, sweep = math.pi * 1.5;
    final arc = Rect.fromCircle(center: o, radius: r * 0.78);
    c.drawArc(arc, start, sweep, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x33FFFFFF));
    c.drawArc(arc, start, sweep * 0.25, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = ChachaColors.red);
    c.drawArc(arc, start, sweep * level.clamp(0, 1), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = low ? ChachaColors.red : ChachaColors.yellow);
    final a = start + sweep * level.clamp(0, 1);
    c.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * r * 0.62, Paint()
      ..color = low ? const Color(0xFFFF7A7A) : Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
    c.drawCircle(o, 3, Paint()..color = Colors.white);
    for (final (t, label) in [(0.0, 'V'), (1.0, 'P')]) {
      final la = start + sweep * t;
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, o + Offset(math.cos(la), math.sin(la)) * r * 0.5 - Offset(tp.width / 2, tp.height / 2 - r * 0.25));
    }
    // La pompe au centre bas
    final icon = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(Icons.local_gas_station_rounded.codePoint),
          style: TextStyle(fontSize: r * 0.5, fontFamily: Icons.local_gas_station_rounded.fontFamily, color: Colors.white70)),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(c, o + Offset(-icon.width / 2, r * 0.3));
  }

  @override
  bool shouldRepaint(_FuelPainter old) => old.level != level || old.low != low;
}
