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
        canvas.drawCircle(r.center, r.height * 0.3, yellow);
        final c = r.center;
        final s = r.height * 0.3;
        canvas.drawLine(
          c + Offset(s * 0.35, s * 0.6),
          c + Offset(-s * 0.05, -s * 0.15),
          Paint()
            ..color = const Color(0xFF6B3E1E)
            ..strokeWidth = s * 0.16
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s * 0.1, c.dy - s * 0.75)
            ..quadraticBezierTo(c.dx + s * 0.25, c.dy - s * 0.3, c.dx - s * 0.05, c.dy - s * 0.1)
            ..quadraticBezierTo(c.dx - s * 0.35, c.dy - s * 0.3, c.dx - s * 0.1, c.dy - s * 0.75),
          Paint()..color = ChachaColors.red,
        );
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
