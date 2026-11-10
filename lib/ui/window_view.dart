import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/window_animals.dart';

/// Le hublot de l'avion : derrière la vitre, la vraie photo d'un animal du Congo, qui glisse doucement,
/// et le bout de l'aile qui brille.
class WindowView extends StatefulWidget {
  const WindowView({super.key, required this.animal, required this.onClose});

  final WindowAnimal animal;
  final VoidCallback onClose;

  @override
  State<WindowView> createState() => _WindowViewState();
}

class _WindowViewState extends State<WindowView> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: const Color(0xE6D9CFBC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _WallPainter(),
                        foregroundPainter: _GlassPainter(_clock),
                        // La photo remplit juste la vitre : on voit tout l'animal, pas un morceau de son pelage.
                        child: LayoutBuilder(
                          builder: (_, box) {
                            final pane = _pane(box.biggest);
                            return Stack(
                              children: [
                                Positioned.fromRect(
                                  rect: pane.outerRect,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.all(pane.tlRadius),
                                    child: AnimatedBuilder(
                                      animation: _clock,
                                      // L'avion avance : la photo glisse lentement, en respirant un peu.
                                      builder: (_, child) => Transform.scale(
                                        scale: 1.06 + 0.03 * math.sin(_clock.value * 2 * math.pi),
                                        child: Transform.translate(
                                          offset: Offset(3 - 6 * _clock.value, 0),
                                          child: child,
                                        ),
                                      ),
                                      child: Image.asset(
                                        a.asset,
                                        fit: BoxFit.cover,
                                        alignment: a.focus,
                                        width: pane.width,
                                        height: pane.height,
                                        filterQuality: FilterQuality.medium,
                                        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF2F6B35)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, color: Color(0xFF5A5040), size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFF14213A),
            padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À ton hublot · ${a.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
                Text(
                  a.place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFFFD94A), fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La vitre du hublot : un ovale haut, au milieu du mur de la cabine.
RRect _pane(Size s) {
  final glass = Rect.fromCenter(
    center: Offset(s.width / 2, s.height * 0.52),
    width: s.width * 0.6,
    height: s.height * 0.88,
  );
  return RRect.fromRectAndRadius(glass, Radius.elliptical(glass.width * 0.5, glass.height * 0.36));
}

/// Le mur de la cabine et le cadre du hublot, derrière la photo.
class _WallPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final u = s.height / 112;
    final rrect = _pane(s);
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFD9CFBC));
    c.drawRRect(
      rrect.inflate(7 * u),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3EDE0), Color(0xFFB9AE98)],
        ).createShader(rrect.outerRect.inflate(7 * u)),
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) => false;
}

/// Devant la photo : le reflet de la vitre, le bout de l'aile, le creux du cadre et le petit volet.
class _GlassPainter extends CustomPainter {
  _GlassPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  @override
  void paint(Canvas c, Size s) {
    final u = s.height / 112;
    final rrect = _pane(s);
    final glass = rrect.outerRect;
    c.save();
    c.clipRRect(rrect);
    // Un reflet qui passe lentement sur la vitre.
    final x = glass.left + (clock.value * 1.6 - 0.3) * glass.width;
    c.drawPath(
      Path()..addPolygon([
        Offset(x, glass.top),
        Offset(x + 16 * u, glass.top),
        Offset(x - 14 * u, glass.bottom),
        Offset(x - 30 * u, glass.bottom),
      ], true),
      Paint()..color = const Color(0x22FFFFFF),
    );
    // L'aile, en bas à gauche, qui brille.
    final wing = Path()
      ..moveTo(glass.left - 4 * u, glass.bottom - 4 * u)
      ..lineTo(glass.left + 8 * u, glass.bottom - 20 * u)
      ..lineTo(glass.left + glass.width * 0.5, glass.bottom - 9 * u)
      ..lineTo(glass.left + glass.width * 0.44, glass.bottom + 2 * u)
      ..close();
    c.drawPath(
      wing,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFE8EDF2), Color(0xFF9AA5B1)]).createShader(wing.getBounds()),
    );
    // Le bord de la vitre, un peu plus sombre : on regarde à travers un double vitrage.
    c.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * u
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * u)
        ..color = const Color(0x55000000),
    );
    c.restore();
    c.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * u
        ..color = const Color(0x66000000),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s.width / 2, glass.top - 2 * u), width: 34 * u, height: 5 * u),
        Radius.circular(3 * u),
      ),
      Paint()..color = const Color(0xFFBFB4A0),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => false;
}
