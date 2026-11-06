import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/scenery.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';

/// Le guide du pilote : ce que veut dire chaque symbole du ciel, chaque bouton, chaque monnaie.
/// Le vol attend pendant qu'on le lit.
class GuideView extends StatelessWidget {
  const GuideView({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000814),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Glass(
            tint: const Color(0x88001A40),
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: ChachaColors.yellow, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Guide du pilote',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    GlassButton(
                      onTap: onClose,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('Reprendre le vol', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section('À ATTRAPER'),
                        _grid([
                          _Item(
                            _Symbol.medal,
                            'Médaillon',
                            'Un moment de l\'histoire du pays. +1 vie, un peu de kérosène, et sa fiche.',
                          ),
                          _Item(
                            _Symbol.fuel,
                            'Bidon rouge · kérosène',
                            '+32 % de kérosène. Sans kérosène, l\'avion tombe en panne sèche.',
                          ),
                          _Item(
                            _Symbol.kit,
                            'Kit d\'entretien',
                            'Le rond bleu avec une clé : l\'avion est révisé en vol et le réservoir refait le plein.',
                          ),
                          _Item(_Symbol.star, 'Étoile', 'Des points. Les points peuvent payer le kérosène.'),
                        ]),
                        _section('À ÉVITER'),
                        _grid([
                          _Item(_Symbol.storm, 'Orage', 'Passe au-dessus ou en dessous : un orage coûte une vie.'),
                          _Item(
                            _Symbol.jet,
                            'Avion de chasse',
                            'Dans les guerres. Le triangle rouge au bord droit annonce sa hauteur : change d\'altitude.',
                          ),
                          _Item(
                            _Symbol.missile,
                            'Missile',
                            'Plus petit et plus rapide, il file vers toi : esquive-le.',
                          ),
                          _Item(_Symbol.birds, 'Oiseaux', 'Ils abîment un peu l\'avion (l\'ÉTAT baisse).'),
                          _Item(
                            _Symbol.airliner,
                            'Avion de ligne étranger',
                            'Ethiopian, Air France… Il passe loin et salue à la radio : aucun danger.',
                          ),
                        ]),
                        _section('LES COMMANDES'),
                        _grid([
                          _Item(
                            _Symbol.arrows,
                            '▲ ▼ ou le doigt',
                            'Monte ou descends. Lâche tout : l\'avion vole tout droit.',
                          ),
                          _Item(
                            _Symbol.turbo,
                            'TURBO',
                            'Maintiens-le sur la piste pour décoller, puis lâche-le. Quand la tour annonce « Ligne droite », maintiens-le et file droit : +400 points.',
                          ),
                          _Item(
                            _Symbol.camera,
                            'Appareil photo',
                            'Attire vers toi les médaillons et les bidons proches, quelques secondes.',
                          ),
                          _Item(
                            _Symbol.land,
                            'ATTERRIR',
                            'Demande l\'atterrissage, puis fais descendre l\'avion doucement jusqu\'à la piste.',
                          ),
                        ]),
                        _section('LE TABLEAU DE BORD'),
                        _grid([
                          _Item(
                            _Symbol.gauge,
                            'Kérosène',
                            'La jauge en bas à gauche. Sous 22 %, la tour propose d\'acheter le plein ou d\'atterrir.',
                          ),
                          _Item(_Symbol.health, 'État', 'L\'usure de l\'avion. Un kit ou une escale le remet à 100 %.'),
                          _Item(_Symbol.hearts, 'Cœurs', 'Tes vies. À zéro, c\'est l\'atterrissage d\'urgence.'),
                        ]),
                        _section('LA MONNAIE DU PAYS'),
                        _grid(const [
                          _Item(_Symbol.money, 'F · francs', 'De 1960 à 1967.'),
                          _Item(_Symbol.money, 'Z · zaïres', 'De 1967 à 1993.'),
                          _Item(_Symbol.money, 'NZ · nouveaux zaïres', 'De 1993 à 1998.'),
                          _Item(_Symbol.money, 'FC · francs congolais', 'Depuis 1998.'),
                        ]),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 6),
                          child: Text(
                            'L\'argent se gagne en volant et en transportant des passagers. Il paie les escales et le kérosène ; s\'il manque, des points sont convertis.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        color: ChachaColors.yellow,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.3,
      ),
    ),
  );

  static Widget _grid(List<_Item> items) => Wrap(spacing: 10, runSpacing: 10, children: items);
}

enum _Symbol {
  medal,
  fuel,
  kit,
  star,
  storm,
  jet,
  missile,
  birds,
  airliner,
  arrows,
  turbo,
  camera,
  land,
  gauge,
  health,
  hearts,
  money,
}

class _Item extends StatelessWidget {
  const _Item(this.symbol, this.title, this.text);

  final _Symbol symbol;
  final String title, text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 46, height: 46, child: _icon ?? CustomPaint(painter: _SymbolPainter(symbol))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? get _icon {
    Widget round(IconData i, {Color color = const Color(0x33FFFFFF)}) => Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(i, color: Colors.white, size: 22),
      ),
    );
    return switch (symbol) {
      _Symbol.arrows => round(Icons.unfold_more_rounded),
      _Symbol.turbo => round(Icons.rocket_launch_rounded, color: const Color(0x99CE1021)),
      _Symbol.camera => round(Icons.photo_camera_rounded),
      _Symbol.land => round(Icons.flight_land_rounded, color: const Color(0x66F7D618)),
      _Symbol.gauge => round(Icons.local_gas_station_rounded),
      _Symbol.health => round(Icons.build_rounded),
      _Symbol.hearts => round(Icons.favorite_rounded, color: const Color(0x66F7D618)),
      _Symbol.money => round(Icons.payments_rounded, color: const Color(0x663E9B5B)),
      _ => null,
    };
  }
}

/// Les symboles dessinés comme dans le ciel du jeu.
class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.symbol);

  final _Symbol symbol;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    switch (symbol) {
      case _Symbol.medal:
        final label = TextPainter(
          text: const TextSpan(
            text: '1960',
            style: TextStyle(color: Color(0xFF5A3A00), fontSize: 9, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        Scenery.medal(canvas, c, r * 0.8, 0, label);
      case _Symbol.fuel:
        Scenery.fuelCan(canvas, c, r * 0.75);
      case _Symbol.kit:
        Scenery.repairKit(canvas, c, r * 0.75, 0);
      case _Symbol.star:
        canvas.drawPath(_star(c, r * 0.7), Paint()..color = ChachaColors.yellow);
      case _Symbol.storm:
        Scenery.cloud(canvas, c, r * 0.5, storm: true);
      case _Symbol.jet:
        _plane(canvas, c, r, const Color(0xFF14171D));
        canvas.drawPath(
          Path()
            ..moveTo(size.width - 2, c.dy + r * 0.7)
            ..lineTo(size.width - 10, c.dy + r * 0.45)
            ..lineTo(size.width - 10, c.dy + r * 0.95)
            ..close(),
          Paint()..color = const Color(0xFFFF7A7A),
        );
      case _Symbol.missile:
        final l = r * 1.6;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.drawOval(Rect.fromLTWH(l * 0.4, -l * 0.06, l * 0.4, l * 0.12), Paint()..color = const Color(0xCCFFA24A));
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-l * 0.4, -l * 0.06, l * 0.85, l * 0.12), Radius.circular(l)),
          Paint()..color = const Color(0xFFD5D9E0),
        );
        canvas.drawPath(
          Path()
            ..moveTo(-l * 0.5, 0)
            ..lineTo(-l * 0.36, -l * 0.06)
            ..lineTo(-l * 0.36, l * 0.06)
            ..close(),
          Paint()..color = const Color(0xFFCE1021),
        );
        canvas.restore();
      case _Symbol.birds:
        final p = Paint()
          ..color = const Color(0xFF2A2A2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (final o in [const Offset(-10, -6), const Offset(6, 0), const Offset(-4, 9)]) {
          final at = c + o;
          canvas.drawPath(
            Path()
              ..moveTo(at.dx - 7, at.dy - 2)
              ..quadraticBezierTo(at.dx - 3, at.dy - 6, at.dx, at.dy)
              ..quadraticBezierTo(at.dx + 3, at.dy - 6, at.dx + 7, at.dy - 2),
            p,
          );
        }
      case _Symbol.airliner:
        _plane(canvas, c, r, Colors.white);
      default:
        break;
    }
  }

  /// Une silhouette d'avion, nez à gauche.
  static void _plane(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 1.8, height: r * 0.3), Radius.circular(r)),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.1, c.dy)
        ..lineTo(c.dx + r * 0.35, c.dy + r * 0.6)
        ..lineTo(c.dx + r * 0.55, c.dy + r * 0.6)
        ..lineTo(c.dx + r * 0.3, c.dy)
        ..close(),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + r * 0.6, c.dy)
        ..lineTo(c.dx + r * 0.8, c.dy - r * 0.55)
        ..lineTo(c.dx + r * 0.92, c.dy - r * 0.55)
        ..lineTo(c.dx + r * 0.9, c.dy)
        ..close(),
      p,
    );
  }

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final d = i.isEven ? r : r * 0.45;
      final pt = c + Offset(math.cos(a) * d, math.sin(a) * d);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_SymbolPainter old) => old.symbol != symbol;
}
