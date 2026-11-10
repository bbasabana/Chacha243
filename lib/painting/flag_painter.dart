import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/eras.dart';
import '../theme/chacha_colors.dart';

/// Dessine les drapeaux successifs du pays, de 1960 à aujourd'hui.
class FlagPainter extends CustomPainter {
  FlagPainter(this.style);

  final FlagStyle style;

  static Path starPath(Offset c, double r, {double inner = 0.4}) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  /// L'emblème du Zaïre : un disque jaune, le bras brun qui monte du bas à droite et tient la torche,
  /// et la flamme rouge dont les langues s'étirent vers la droite.
  static void paintTorch(Canvas canvas, Offset c, double r) {
    Offset p(double x, double y) => c + Offset(x * r, y * r);
    canvas.drawCircle(c, r, Paint()..color = ChachaColors.yellow);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    const brown = Color(0xFF7A4A1C);
    final wood = Paint()..color = brown;

    // Le bras, du bord du disque jusqu'au poing.
    final arm = Path()
      ..moveTo(p(-0.42, 0.74).dx, p(-0.42, 0.74).dy)
      ..lineTo(p(0.02, 1.08).dx, p(0.02, 1.08).dy)
      ..lineTo(p(0.52, 1.08).dx, p(0.52, 1.08).dy)
      ..lineTo(p(0.44, 0.9).dx, p(0.44, 0.9).dy)
      ..quadraticBezierTo(p(0.1, 0.78).dx, p(0.1, 0.78).dy, p(-0.12, 0.56).dx, p(-0.12, 0.56).dy)
      ..quadraticBezierTo(p(-0.18, 0.4).dx, p(-0.18, 0.4).dy, p(-0.3, 0.36).dx, p(-0.3, 0.36).dy)
      ..lineTo(p(-0.52, 0.38).dx, p(-0.52, 0.38).dy)
      ..quadraticBezierTo(p(-0.64, 0.5).dx, p(-0.64, 0.5).dy, p(-0.56, 0.64).dx, p(-0.56, 0.64).dy)
      ..close();
    canvas.drawPath(arm, wood);

    // La torche : une coupe évasée en haut, le manche qui descend dans le poing.
    final torch = Path()
      ..moveTo(p(-0.58, -0.14).dx, p(-0.58, -0.14).dy)
      ..lineTo(p(-0.14, -0.04).dx, p(-0.14, -0.04).dy)
      ..lineTo(p(-0.36, 0.5).dx, p(-0.36, 0.5).dy)
      ..lineTo(p(-0.48, 0.47).dx, p(-0.48, 0.47).dy)
      ..close();
    canvas.drawPath(torch, wood);
    // Les rainures de la torche et les doigts, en plus foncé.
    final groove = Paint()
      ..color = const Color(0xFF4E2C0E)
      ..strokeWidth = r * 0.035
      ..style = PaintingStyle.stroke;
    for (final y in [0.06, 0.18, 0.3]) {
      final k = (y + 0.1) / 0.6;
      canvas.drawLine(p(-0.56 + k * 0.1, y), p(-0.16 - k * 0.18, y + 0.06), groove);
    }
    for (final y in [0.44, 0.52, 0.6]) {
      canvas.drawLine(p(-0.56, y), p(-0.4, y + 0.03), groove);
    }

    // La flamme : une base sur la coupe et cinq langues qui partent vers le haut et la droite.
    final flame = Path()
      ..moveTo(p(-0.56, -0.16).dx, p(-0.56, -0.16).dy)
      ..quadraticBezierTo(p(-0.62, -0.36).dx, p(-0.62, -0.36).dy, p(-0.42, -0.42).dx, p(-0.42, -0.42).dy)
      ..quadraticBezierTo(p(-0.36, -0.58).dx, p(-0.36, -0.58).dy, p(-0.16, -0.62).dx, p(-0.16, -0.62).dy)
      ..quadraticBezierTo(p(-0.12, -0.52).dx, p(-0.12, -0.52).dy, p(-0.06, -0.5).dx, p(-0.06, -0.5).dy)
      ..quadraticBezierTo(p(0.02, -0.66).dx, p(0.02, -0.66).dy, p(0.2, -0.7).dx, p(0.2, -0.7).dy)
      ..quadraticBezierTo(p(0.16, -0.6).dx, p(0.16, -0.6).dy, p(0.18, -0.54).dx, p(0.18, -0.54).dy)
      ..quadraticBezierTo(p(0.34, -0.72).dx, p(0.34, -0.72).dy, p(0.52, -0.78).dx, p(0.52, -0.78).dy)
      ..quadraticBezierTo(p(0.38, -0.62).dx, p(0.38, -0.62).dy, p(0.36, -0.5).dx, p(0.36, -0.5).dy)
      ..quadraticBezierTo(p(0.48, -0.56).dx, p(0.48, -0.56).dy, p(0.6, -0.54).dx, p(0.6, -0.54).dy)
      ..quadraticBezierTo(p(0.44, -0.44).dx, p(0.44, -0.44).dy, p(0.38, -0.32).dx, p(0.38, -0.32).dy)
      ..quadraticBezierTo(p(0.5, -0.32).dx, p(0.5, -0.32).dy, p(0.62, -0.26).dx, p(0.62, -0.26).dy)
      ..quadraticBezierTo(p(0.44, -0.22).dx, p(0.44, -0.22).dy, p(0.34, -0.14).dx, p(0.34, -0.14).dy)
      ..quadraticBezierTo(p(0.46, -0.1).dx, p(0.46, -0.1).dy, p(0.54, -0.04).dx, p(0.54, -0.04).dy)
      ..quadraticBezierTo(p(0.3, -0.02).dx, p(0.3, -0.02).dy, p(0.1, -0.08).dx, p(0.1, -0.08).dy)
      ..quadraticBezierTo(p(-0.02, -0.04).dx, p(-0.02, -0.04).dy, p(-0.14, -0.04).dx, p(-0.14, -0.04).dy)
      ..close();
    canvas.drawPath(flame, Paint()..color = ChachaColors.red);
    canvas.restore();
  }

  static void paintFlag(Canvas canvas, Rect r, FlagStyle style) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.12)));
    final yellow = Paint()..color = ChachaColors.yellow;
    switch (style) {
      case FlagStyle.star1960:
      case FlagStyle.star1997:
        canvas.drawRect(r, Paint()..color = style == FlagStyle.star1960 ? const Color(0xFF0B5CC9) : ChachaColors.sky);
        canvas.drawPath(starPath(r.center, r.height * 0.32), yellow);
        for (var i = 0; i < 6; i++) {
          canvas.drawPath(
            starPath(Offset(r.left + r.width * 0.09, r.top + r.height * (0.1 + i * 0.16)), r.height * 0.065),
            yellow,
          );
        }
      case FlagStyle.diagonal1963:
      case FlagStyle.current2006:
        canvas.drawRect(
          r,
          Paint()..color = style == FlagStyle.diagonal1963 ? const Color(0xFF0B5CC9) : ChachaColors.sky,
        );
        canvas.save();
        canvas.translate(r.center.dx, r.center.dy);
        canvas.rotate(-math.atan2(r.height, r.width));
        final d = r.width * 1.3;
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: d, height: r.height * 0.3), yellow);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: d, height: r.height * 0.22),
          Paint()..color = ChachaColors.red,
        );
        canvas.restore();
        canvas.drawPath(starPath(Offset(r.left + r.width * 0.18, r.top + r.height * 0.27), r.height * 0.2), yellow);
      case FlagStyle.zaire1971:
        canvas.drawRect(r, Paint()..color = ChachaColors.zaireGreen);
        paintTorch(canvas, r.center, r.height * 0.32);
    }
    // Reflet de verre
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF), Color(0x22000000)],
        ).createShader(r),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) => paintFlag(canvas, Offset.zero & size, style);

  @override
  bool shouldRepaint(FlagPainter old) => old.style != style;
}
