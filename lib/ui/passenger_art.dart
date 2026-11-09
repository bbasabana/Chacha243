import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Les quatre passagers de la cabine, dessinés de face en illustration nette.
enum PassengerKind { youngMan, youngWoman, mother, grandmother }

class PassengerPainter extends CustomPainter {
  const PassengerPainter(this.kind);

  final PassengerKind kind;

  static const _skins = {
    PassengerKind.youngMan: (Color(0xFF8A5433), Color(0xFF5E3520)),
    PassengerKind.youngWoman: (Color(0xFFA0653E), Color(0xFF6F4227)),
    PassengerKind.mother: (Color(0xFF7A4829), Color(0xFF522D19)),
    PassengerKind.grandmother: (Color(0xFF6E4126), Color(0xFF482816)),
  };

  static const _hairDark = Color(0xFF17110E);

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 100, s.height / 100);
    final (light, shade) = _skins[kind]!;
    if (kind == PassengerKind.youngWoman) _hairBehind(c);
    _body(c);
    _neck(c, light, shade);
    _collar(c);
    _ears(c, shade);
    _face(c, light, shade);
    _eyes(c);
    _nose(c, shade);
    _mouth(c);
    _hairFront(c);
    if (kind == PassengerKind.grandmother) _glasses(c);
    c.restore();
  }

  Path get _facePath => Path()
    ..moveTo(50, 13)
    ..cubicTo(64, 13, 71, 23, 71, 36)
    ..cubicTo(71, 49, 66, 59, 56.5, 65)
    ..cubicTo(52, 67.6, 48, 67.6, 43.5, 65)
    ..cubicTo(34, 59, 29, 49, 29, 36)
    ..cubicTo(29, 23, 36, 13, 50, 13)
    ..close();

  void _face(Canvas c, Color light, Color shade) {
    final face = _facePath;
    c.drawPath(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(light, Colors.white, 0.1)!, light],
        ).createShader(const Rect.fromLTWH(29, 13, 42, 55)),
    );
    c.save();
    c.clipPath(face);
    // Le côté dans l'ombre et un reflet doux sur la joue et le front.
    c.drawPath(
      Path()
        ..moveTo(62, 8)
        ..cubicTo(68, 26, 66, 50, 50, 72)
        ..lineTo(76, 72)
        ..lineTo(76, 8)
        ..close(),
      Paint()..color = shade.withValues(alpha: 0.42),
    );
    for (final (at, r) in const [(Offset(40, 42), 8.0), (Offset(45, 23), 9.0)]) {
      c.drawCircle(
        at,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: at, radius: r)),
      );
    }
    c.restore();
  }

  void _ears(Canvas c, Color shade) {
    for (final x in const [28.6, 71.4]) {
      c.drawOval(Rect.fromCenter(center: Offset(x, 40), width: 6, height: 11), Paint()..color = shade);
    }
    if (kind != PassengerKind.youngMan) {
      for (final x in const [28.6, 71.4]) {
        c.drawCircle(Offset(x, 47.5), 1.5, Paint()..color = const Color(0xFFF2C230));
      }
    }
  }

  void _neck(Canvas c, Color light, Color shade) {
    final neck = Path()
      ..moveTo(41, 58)
      ..lineTo(41, 76)
      ..quadraticBezierTo(50, 86, 59, 76)
      ..lineTo(59, 58)
      ..close();
    c.drawPath(neck, Paint()..color = Color.lerp(light, shade, 0.45)!);
    c.save();
    c.clipPath(neck);
    c.drawOval(Rect.fromCenter(center: const Offset(50, 67), width: 26, height: 12), Paint()..color = shade);
    c.restore();
  }

  Path get _bodyPath => Path()
    ..moveTo(8, 104)
    ..cubicTo(9, 86, 20, 78, 40, 74)
    ..lineTo(60, 74)
    ..cubicTo(80, 78, 91, 86, 92, 104)
    ..close();

  void _body(Canvas c) {
    final body = _bodyPath;
    final (base, trim) = switch (kind) {
      PassengerKind.youngMan => (const Color(0xFFC62F2F), const Color(0xFF1F2F52)),
      PassengerKind.youngWoman => (const Color(0xFFF1F4F8), const Color(0xFF3E6FB0)),
      PassengerKind.mother => (const Color(0xFF17A3C4), const Color(0xFFF2C230)),
      PassengerKind.grandmother => (const Color(0xFF7A2E8E), const Color(0xFFF08A24)),
    };
    c.drawPath(body, Paint()..color = base);
    c.save();
    c.clipPath(body);
    switch (kind) {
      case PassengerKind.youngMan:
        final bar = Paint()..color = trim.withValues(alpha: 0.5);
        final thin = Paint()..color = Colors.white.withValues(alpha: 0.45);
        for (var x = 6.0; x < 96; x += 12) {
          c.drawRect(Rect.fromLTWH(x, 70, 4, 36), bar);
          c.drawRect(Rect.fromLTWH(x + 7, 70, 1.2, 36), thin);
        }
        for (var y = 78.0; y < 104; y += 11) {
          c.drawRect(Rect.fromLTWH(0, y, 100, 3.6), bar);
          c.drawRect(Rect.fromLTWH(0, y + 6.5, 100, 1.2), thin);
        }
      case PassengerKind.youngWoman:
        final stripe = Paint()..color = trim;
        for (var x = 4.0; x < 98; x += 6) {
          c.drawRect(Rect.fromLTWH(x, 70, 2.3, 36), stripe);
        }
      case PassengerKind.mother:
      case PassengerKind.grandmother:
        _wax(c, const Rect.fromLTWH(4, 72, 92, 34), trim, Colors.white, 9);
    }
    // Les épaules s'assombrissent vers l'extérieur : le buste prend du volume.
    c.drawRect(
      const Rect.fromLTWH(0, 70, 100, 36),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.3),
          ],
          stops: const [0, 0.3, 0.65, 1],
        ).createShader(const Rect.fromLTWH(0, 70, 100, 36)),
    );
    c.restore();
  }

  /// Un motif de pagne : des losanges et des points réguliers.
  void _wax(Canvas c, Rect area, Color a, Color b, double step) {
    final fill = Paint()..color = a;
    final dot = Paint()..color = b;
    var row = 0;
    for (var y = area.top; y < area.bottom; y += step * 0.8, row++) {
      for (var x = area.left + (row.isOdd ? step / 2 : 0); x < area.right; x += step) {
        c.drawPath(
          Path()
            ..moveTo(x, y - 3)
            ..lineTo(x + 3, y)
            ..lineTo(x, y + 3)
            ..lineTo(x - 3, y)
            ..close(),
          fill,
        );
        c.drawCircle(Offset(x, y), 1, dot);
      }
    }
  }

  void _collar(Canvas c) {
    final (left, right) = (
      Path()
        ..moveTo(40, 72)
        ..lineTo(50, 86)
        ..lineTo(44, 91)
        ..lineTo(35, 77)
        ..close(),
      Path()
        ..moveTo(60, 72)
        ..lineTo(50, 86)
        ..lineTo(56, 91)
        ..lineTo(65, 77)
        ..close(),
    );
    switch (kind) {
      case PassengerKind.youngMan:
        c.drawPath(
          Path()
            ..moveTo(43, 76)
            ..lineTo(57, 76)
            ..lineTo(50, 92)
            ..close(),
          Paint()..color = Colors.white,
        );
        final p = Paint()..color = const Color(0xFF9E2020);
        c.drawPath(left, p);
        c.drawPath(right, p);
      case PassengerKind.youngWoman:
        final p = Paint()..color = const Color(0xFFDCE4EE);
        c.drawPath(left, p);
        c.drawPath(right, p);
      case PassengerKind.mother:
      case PassengerKind.grandmother:
        c.drawPath(
          Path()
            ..moveTo(39, 74)
            ..quadraticBezierTo(50, 88, 61, 74),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..color = const Color(0xFFF2C230),
        );
    }
  }

  void _eyes(Canvas c) {
    for (final side in const [-1.0, 1.0]) {
      final x = 50 + side * 10;
      const y = 39.0;
      final eye = Path()
        ..moveTo(x - 5, y)
        ..quadraticBezierTo(x, y - 4.6, x + 5, y)
        ..quadraticBezierTo(x, y + 3, x - 5, y)
        ..close();
      c.drawPath(eye, Paint()..color = const Color(0xFFF7F2EA));
      c.save();
      c.clipPath(eye);
      c.drawCircle(Offset(x, y - 0.6), 2.9, Paint()..color = const Color(0xFF3A1F10));
      c.drawCircle(Offset(x, y - 0.6), 1.5, Paint()..color = const Color(0xFF0C0705));
      c.restore();
      c.drawCircle(Offset(x - 0.9, y - 1.7), 0.7, Paint()..color = Colors.white);
      c.drawPath(
        Path()
          ..moveTo(x - 5.4, y + 0.2)
          ..quadraticBezierTo(x, y - 5.2, x + 5.4, y + 0.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.1
          ..color = const Color(0xFF1A0F0A),
      );
      final grey = kind == PassengerKind.grandmother;
      c.drawPath(
        Path()
          ..moveTo(x - 6.5, y - 6.6)
          ..quadraticBezierTo(x, y - 9.6, x + 6.5, y - 6.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = kind == PassengerKind.youngMan ? 1.9 : 1.3
          ..color = grey ? const Color(0xFF9A948E) : _hairDark,
      );
      if (grey) {
        c.drawPath(
          Path()
            ..moveTo(x - 4, y + 4.4)
            ..quadraticBezierTo(x, y + 6, x + 4, y + 4.4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 0.6
            ..color = const Color(0x66000000),
        );
      }
    }
  }

  void _nose(Canvas c, Color shade) {
    c.drawPath(
      Path()
        ..moveTo(52, 38)
        ..quadraticBezierTo(53.5, 45, 56, 49)
        ..quadraticBezierTo(53, 53, 50, 51.5)
        ..close(),
      Paint()..color = shade.withValues(alpha: 0.32),
    );
    c.drawPath(
      Path()
        ..moveTo(44, 50)
        ..quadraticBezierTo(46, 53.4, 50, 52.2)
        ..quadraticBezierTo(54, 53.4, 56, 50),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1
        ..color = shade,
    );
  }

  void _mouth(Canvas c) {
    final (upper, lower) = switch (kind) {
      PassengerKind.youngMan => (const Color(0xFF5A2A24), const Color(0xFF8A4640)),
      PassengerKind.youngWoman => (const Color(0xFF9E2F3F), const Color(0xFFC24A58)),
      PassengerKind.mother => (const Color(0xFF8E2A38), const Color(0xFFAE4350)),
      PassengerKind.grandmother => (const Color(0xFF53261F), const Color(0xFF75403A)),
    };
    final smile = kind == PassengerKind.youngWoman || kind == PassengerKind.youngMan;
    c.drawPath(
      Path()
        ..moveTo(42.5, 57.2)
        ..quadraticBezierTo(50, smile ? 63.8 : 61.5, 57.5, 57.2)
        ..quadraticBezierTo(50, 57.8, 42.5, 57.2)
        ..close(),
      Paint()..color = lower,
    );
    if (smile) {
      c.drawPath(
        Path()
          ..moveTo(44.2, 57.6)
          ..quadraticBezierTo(50, 61.4, 55.8, 57.6)
          ..quadraticBezierTo(50, 58.1, 44.2, 57.6)
          ..close(),
        Paint()..color = Colors.white,
      );
    }
    c.drawPath(
      Path()
        ..moveTo(42, 57.3)
        ..quadraticBezierTo(46, 54, 50, 55.6)
        ..quadraticBezierTo(54, 54, 58, 57.3)
        ..quadraticBezierTo(50, 58, 42, 57.3)
        ..close(),
      Paint()..color = upper,
    );
  }

  void _hairBehind(Canvas c) {
    final p = Paint()..color = _hairDark;
    final rng = math.Random(7);
    c.drawOval(Rect.fromCenter(center: const Offset(50, 36), width: 76, height: 66), p);
    for (var a = 0.0; a < math.pi * 2; a += 0.22) {
      final r = 5.5 + rng.nextDouble() * 3;
      c.drawCircle(Offset(50 + math.cos(a) * 36, 36 + math.sin(a) * 31), r, p);
    }
    c.drawCircle(const Offset(40, 16), 9, Paint()..color = const Color(0xFF2B211C));
  }

  void _hairFront(Canvas c) {
    final hair = Paint()..color = _hairDark;
    switch (kind) {
      case PassengerKind.youngMan:
        c.drawPath(
          Path()
            ..moveTo(29, 34)
            ..cubicTo(27, 12, 40, 6, 50, 6)
            ..cubicTo(60, 6, 73, 12, 71, 34)
            ..cubicTo(68, 26, 66, 23, 62, 21)
            ..cubicTo(55, 24, 45, 24, 38, 21)
            ..cubicTo(34, 23, 32, 26, 29, 34)
            ..close(),
          hair,
        );
        c.drawPath(
          Path()
            ..moveTo(45, 54.4)
            ..quadraticBezierTo(50, 52.7, 55, 54.4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.2
            ..color = _hairDark,
        );
      case PassengerKind.youngWoman:
        c.drawPath(
          Path()
            ..moveTo(28, 40)
            ..cubicTo(25, 15, 40, 8, 50, 10)
            ..cubicTo(60, 8, 75, 15, 72, 40)
            ..cubicTo(70, 28, 63, 20, 50, 18)
            ..cubicTo(37, 20, 30, 28, 28, 40)
            ..close(),
          hair,
        );
      case PassengerKind.mother:
        _headwrap(c, const Color(0xFFD5342F), const Color(0xFFF2C230));
      case PassengerKind.grandmother:
        c.drawPath(
          Path()
            ..moveTo(29, 33)
            ..cubicTo(29, 24, 34, 21, 39, 20)
            ..lineTo(61, 20)
            ..cubicTo(66, 21, 71, 24, 71, 33)
            ..cubicTo(67, 27, 60, 25, 50, 25)
            ..cubicTo(40, 25, 33, 27, 29, 33)
            ..close(),
          Paint()..color = const Color(0xFFC9C5BF),
        );
        _headwrap(c, const Color(0xFF1F7A5A), const Color(0xFFF08A24), low: false);
    }
  }

  void _headwrap(Canvas c, Color a, Color b, {bool low = true}) {
    final top = low ? 26.0 : 23.0;
    final wrap = Path()
      ..moveTo(27.5, top + 8)
      ..cubicTo(25, 6, 42, 0, 52, 1)
      ..cubicTo(68, 1, 76, 12, 72.5, top + 8)
      ..cubicTo(64, top - 2, 36, top - 2, 27.5, top + 8)
      ..close();
    c.drawPath(wrap, Paint()..color = a);
    c.save();
    c.clipPath(wrap);
    _wax(c, const Rect.fromLTWH(22, 0, 56, 36), b, Colors.white, 8);
    c.restore();
    // Le nœud du foulard
    c.drawPath(
      Path()
        ..moveTo(52, 8)
        ..cubicTo(60, -3, 72, -2, 69, 7)
        ..cubicTo(66, 13, 58, 12, 52, 8)
        ..close(),
      Paint()..color = Color.lerp(a, Colors.black, 0.18)!,
    );
    c.drawCircle(const Offset(52, 8.5), 3.2, Paint()..color = b);
  }

  void _glasses(Canvas c) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF26201C);
    for (final x in const [40.0, 60.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 39), width: 15, height: 11.5),
          const Radius.circular(4.5),
        ),
        p,
      );
    }
    c.drawLine(const Offset(47.5, 38.5), const Offset(52.5, 38.5), p);
  }

  @override
  bool shouldRepaint(PassengerPainter old) => old.kind != kind;
}
