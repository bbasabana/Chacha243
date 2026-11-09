import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/aircraft_types.dart';
import '../data/eras.dart';
import '../painting/aircraft_painter.dart';
import '../theme/chacha_colors.dart';
import 'home_screen.dart';

/// Une explication au lancement : « Continuer » la retire pour de bon, « Passer » la laisse revenir.
class Onboarding {
  Onboarding._();

  static const _done = 'onboarding_done';

  static bool pending = false;

  static Future<void> load() async {
    pending = !((await SharedPreferences.getInstance()).getBool(_done) ?? false);
  }

  static Future<void> finish() async {
    pending = false;
    await (await SharedPreferences.getInstance()).setBool(_done, true);
  }
}

const _message =
    'Commandant, conduisez l\'avion du 30 juin 1960 au 30 juin 2027. '
    'Évitez les avions de guerre : ce sont les moments difficiles du pays.';

const _perLetter = 0.06, _afterText = 3.5, _replayAfter = 7.0;

/// La démonstration joue un peu au ralenti, le temps de lire et de voir.
const _demoPace = 0.72;
const _ink = Color(0xFF0B1B3A);

/// Le début de la démonstration, en secondes.
final double _demo = _message.length * _perLetter + _afterText;

/// Dans la démonstration : l'avion du Zaïre paraît à [_zaire], touché à [_hit], écrasé à [_impact] ;
/// Laurent-Désiré Kabila s'affiche à [_kabila], l'avion du Congo arrive à [_reborn].
const _zaire = 3.8, _hit = 5.6, _fall = 1.5, _impact = _hit + _fall;
const _kabila = _impact + 0.5, _reborn = _kabila + 3.2, _end = _reborn + 1.0;

double _ease(double x) {
  final v = x.clamp(0.0, 1.0);
  return 1 - math.pow(1 - v, 3).toDouble();
}

double _smooth(double x) {
  final v = x.clamp(0.0, 1.0);
  return v * v * (3 - 2 * v);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..forward();
  ui.Image? _skyline;
  bool _shook = false, _leaving = false;

  double get _t => _clock.value * 60;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_watch);
    _loadSkyline();
  }

  Future<void> _loadSkyline() async {
    final data = await rootBundle.load('assets/scenery/kinshasa-skyline.png');
    final frame = await (await ui.instantiateImageCodec(data.buffer.asUint8List())).getNextFrame();
    if (mounted) setState(() => _skyline = frame.image);
  }

  void _watch() {
    final s = (_t - _demo) * _demoPace;
    if (!_shook && s >= _hit) {
      _shook = true;
      HapticFeedback.heavyImpact();
    }
    // Personne n'a touché l'écran : le scénario reprend.
    if (!_leaving && s >= _end + _replayAfter) {
      _shook = false;
      _clock.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const HomeScreen()),
      ),
    );
  }

  void _continue() {
    Onboarding.finish();
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF6FF),
      body: AnimatedBuilder(
        animation: _clock,
        builder: (_, _) {
          final t = _t, s = (t - _demo) * _demoPace;
          final letters = (t / _perLetter).floor().clamp(0, _message.length);
          final textFade = 1 - _smooth(s / 0.5);
          final done = _smooth((s - _end) / 0.6);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _SkyPainter(t, s, _skyline)),
              if (textFade > 0)
                Opacity(
                  opacity: textFade,
                  child: Align(
                    alignment: const Alignment(0, -0.28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _Typed(letters, t)),
                    ),
                  ),
                ),
              _Moment('30 juin 1960 · Sécession du Katanga', 'Il passe : on l\'évite', s, 0.6, 3.5),
              _Moment('1996 · Le Zaïre attaqué par l\'AFDL', 'Touché, c\'est le crash', s, _zaire, _impact),
              _KabilaCard(s),
              if (done > 0)
                Opacity(
                  opacity: done,
                  child: Align(
                    alignment: const Alignment(-0.55, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'À vous de piloter,\ncommandant',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: done > 0.5 ? _leave : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              ),
                              child: const Text('Passer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: done > 0.5 ? _continue : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: ChachaColors.yellow,
                                foregroundColor: _ink,
                                disabledBackgroundColor: ChachaColors.yellow,
                                disabledForegroundColor: _ink,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              ),
                              child: const Text(
                                'Continuer',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (done <= 0)
                Positioned(
                  top: 10,
                  right: 12,
                  child: SafeArea(
                    child: TextButton(
                      onPressed: _leave,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0x33FFFFFF),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                      child: const Text('Passer', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Le texte se tape : la partie pas encore écrite garde sa place, pour que les lignes ne sautent pas.
class _Typed extends StatelessWidget {
  const _Typed(this.letters, this.t);

  final int letters;
  final double t;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 23,
      height: 1.35,
      fontWeight: FontWeight.w800,
      shadows: [Shadow(color: Color(0x55000F3A), blurRadius: 10, offset: Offset(0, 2))],
    );
    final typing = letters < _message.length;
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: _message.substring(0, letters)),
          TextSpan(
            text: '|',
            style: TextStyle(color: (typing || (t * 2).floor().isEven) ? ChachaColors.yellow : Colors.transparent),
          ),
          TextSpan(
            text: _message.substring(letters),
            style: const TextStyle(color: Colors.transparent, shadows: []),
          ),
        ],
      ),
    );
  }
}

/// Le moment d'histoire joué par la démonstration.
class _Moment extends StatelessWidget {
  const _Moment(this.title, this.hint, this.s, this.from, this.to);

  final String title, hint;
  final double s, from, to;

  @override
  Widget build(BuildContext context) {
    final o = math.min(_smooth((s - from) / 0.4), 1 - _smooth((s - to) / 0.4));
    if (o <= 0) return const SizedBox.shrink();
    return Positioned(
      top: 22,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: o,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(30)),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hint,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Après le crash : Laurent-Désiré Kabila, et le pays reprend son nom.
class _KabilaCard extends StatelessWidget {
  const _KabilaCard(this.s);

  final double s;

  @override
  Widget build(BuildContext context) {
    final k = _smooth((s - _kabila) / 0.5), out = _smooth((s - _reborn) / 0.4);
    if (k <= 0 || out >= 1) return const SizedBox.shrink();
    return Opacity(
      opacity: k * (1 - out),
      child: Center(
        child: Transform.scale(
          scale: 0.9 + 0.1 * _ease((s - _kabila) / 0.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ChachaColors.yellow, width: 4),
                  image: const DecorationImage(
                    image: AssetImage('assets/photos/laurent-desire-kabila.jpg'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              const SizedBox(width: 22),
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '17 mai 1997',
                    style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Laurent-Désiré Kabila',
                    style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Le Zaïre redevient le Congo',
                    style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le ciel du site : dégradé bleu vers le blanc, nuages, ville de Kinshasa en bas, et la démonstration.
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t, this.s, this.skyline);

  /// [t] depuis l'ouverture, [s] depuis le début de la démonstration (négatif avant).
  final double t, s;
  final ui.Image? skyline;

  static final _type = aircraftById('b737');
  static final _liveries = [airlineAt(1960).livery, airlineAt(1990).livery, airlineAt(1998).livery];

  Offset _planeAt(double when, Size z) {
    final dodge = _smooth((when - 1.5) / 0.6) - _smooth((when - 2.9) / 0.6);
    var x = -0.3 + 0.7 * _ease(when / 1.4);
    var y = 0.47 - 0.25 * dodge + math.sin(when * 2) * 0.008;
    if (when > _hit) {
      final u = when - _hit;
      x += 0.07 * u;
      y += 0.22 * u * u;
    }
    return Offset(x * z.width, y * z.height);
  }

  Offset _jetAt(double from, double by, double y, Size z) {
    final p = (s - from) / by;
    return Offset((1.25 - 1.6 * p) * z.width, y * z.height);
  }

  @override
  void paint(Canvas c, Size z) {
    final all = Offset.zero & z;
    c.drawRect(
      all,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D7BF5), Color(0xFF4B9FFF), Color(0xFFA9D3FF), Color(0xFFEEF6FF)],
          stops: [0, 0.38, 0.64, 0.88],
        ).createShader(all),
    );
    _clouds(c, z);
    _city(c, z);
    if (s > 0) _demo(c, z);
    final flash = 1 - ((s - _hit) / 0.3).abs();
    if (flash > 0 && flash <= 1) {
      c.drawRect(all, Paint()..color = const Color(0xFFFF5A2A).withValues(alpha: flash * 0.35));
    }
  }

  void _clouds(Canvas c, Size z) {
    for (final (i, (y, r, speed)) in const [(0.16, 0.2, 0.018), (0.33, 0.14, 0.03), (0.52, 0.24, 0.045)].indexed) {
      final x = (1.3 - (t * speed + i * 0.43) % 1.6) * z.width;
      final at = Offset(x, y * z.height);
      final rad = r * z.height * 1.7;
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(1.9, 0.6);
      c.drawCircle(
        Offset.zero,
        rad,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: rad)),
      );
      c.restore();
    }
  }

  void _city(Canvas c, Size z) {
    final img = skyline;
    if (img == null) return;
    final h = z.height * 0.26;
    final w = h * img.width / img.height;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = const Color(0xF2FFFFFF);
    var x = -((t * 26) % w);
    while (x < z.width) {
      c.drawImageRect(img, src, Rect.fromLTWH(x, z.height - h, w, h), paint);
      x += w;
    }
  }

  void _demo(Canvas c, Size z) {
    // L'esquive : un chasseur passe à la hauteur de l'avion.
    if (s > 0.9 && s < 4) _fighter(c, _jetAt(0.9, 2.6, 0.47, z), z);
    // Le crash : deux chasseurs traversent, le premier tire.
    final jetStart = _hit - 2.0;
    if (s > jetStart && s < jetStart + 5) {
      _fighter(c, _jetAt(jetStart, 4.0, 0.24, z), z, afdl: true);
      _fighter(c, _jetAt(jetStart + 0.25, 4.0, 0.68, z), z, afdl: true);
    }
    _missile(c, z);
    _smoke(c, z);
    if (s < _impact) _plane(c, z);
    if (s > _reborn) _congoPlane(c, z);
    _blast(c, _planeAt(_hit, z), s - _hit, z.height * 0.28, 0.7);
    _blast(c, Offset(_planeAt(_impact, z).dx, z.height * 0.9), s - _impact, z.height * 0.5, 1.1);
  }

  void _plane(Canvas c, Size z) {
    final len = z.height * 0.6;
    final at = _planeAt(s, z);
    final tilt = s > _hit
        ? math.min((s - _hit) * 0.45, 0.72)
        : -0.1 * (_smooth((s - 1.5) / 0.6) - _smooth((s - 2.5) / 0.4));
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(tilt);
    c.translate(-len / 2, -len / 4);
    AircraftPainter.paint(c, Size(len, len / 2), _type, _liveries[s < _zaire ? 0 : 1], propPhase: t * 40, blink: t);
    c.restore();
  }

  /// L'avion renaît aux couleurs du Congo et vient se placer à droite du bouton.
  void _congoPlane(Canvas c, Size z) {
    final len = z.height * 0.68;
    final x = -0.35 + 1.05 * _ease((s - _reborn) / 1.1);
    c.save();
    c.translate(x * z.width, (0.47 + math.sin(s * 2) * 0.012) * z.height);
    c.translate(-len / 2, -len / 4);
    AircraftPainter.paint(c, Size(len, len / 2), _type, _liveries[2], propPhase: t * 40, blink: t);
    c.restore();
  }

  void _fighter(Canvas c, Offset at, Size z, {bool afdl = false}) {
    final l = z.height * 0.24;
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(l / 100);
    c.drawPath(
      Path()
        ..moveTo(50, -5)
        ..lineTo(92, -4)
        ..lineTo(108, -3)
        ..lineTo(108, 3)
        ..lineTo(50, 5)
        ..close(),
      Paint()..color = const Color(0xFFFFB020).withValues(alpha: 0.75),
    );
    c.drawPath(
      Path()
        ..moveTo(-50, 0)
        ..cubicTo(-30, -8, -6, -10, 20, -9)
        ..lineTo(52, -7)
        ..lineTo(52, 7)
        ..lineTo(0, 9)
        ..cubicTo(-22, 8, -38, 5, -50, 0)
        ..close(),
      Paint()..color = const Color(0xFF3F4C3B),
    );
    c.drawPath(
      Path()
        ..moveTo(-8, 2)
        ..lineTo(34, 30)
        ..lineTo(44, 30)
        ..lineTo(32, 4)
        ..close(),
      Paint()..color = const Color(0xFF2C362A),
    );
    c.drawPath(
      Path()
        ..moveTo(28, -7)
        ..lineTo(50, -30)
        ..lineTo(58, -30)
        ..lineTo(52, -7)
        ..close(),
      Paint()..color = const Color(0xFF2C362A),
    );
    c.drawPath(
      Path()
        ..moveTo(-26, -6)
        ..quadraticBezierTo(-14, -15, 2, -9)
        ..close(),
      Paint()..color = const Color(0xFF9AD0F0),
    );
    if (afdl) {
      final tag = TextPainter(
        text: const TextSpan(
          text: 'AFDL',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tag.paint(c, const Offset(-8, -7.5));
    }
    c.restore();
  }

  void _missile(Canvas c, Size z) {
    const launch = _hit - 0.8;
    if (s < launch || s >= _hit) return;
    final from = _jetAt(_hit - 2.0, 4.0, 0.24, z).translate(0, 0);
    final start = Offset((1.25 - 1.6 * (1.2 / 4.0)) * z.width, from.dy);
    final to = _planeAt(_hit, z);
    final p = (s - launch) / 0.8;
    final at = Offset.lerp(start, to, p * p)!;
    final dir = (to - start) / (to - start).distance;
    c.drawLine(
      at,
      at - dir * z.height * 0.3 * p,
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(at, at - dir * z.height * 0.3, [Colors.white, Colors.white.withValues(alpha: 0)]),
    );
    c.drawLine(
      at,
      at + dir * z.height * 0.06,
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = ChachaColors.red,
    );
    c.drawCircle(at, 5, Paint()..color = const Color(0xFFFFB020));
  }

  void _smoke(Canvas c, Size z) {
    for (var i = 0; i < 26; i++) {
      final born = _hit + i * 0.06;
      final age = s - born;
      if (age < 0 || age > 1.8 || born > _impact) continue;
      final at = _planeAt(born, z).translate(-z.height * 0.12, -age * z.height * 0.08);
      final k = age / 1.8;
      c.drawCircle(
        at,
        z.height * (0.025 + 0.07 * k),
        Paint()
          ..color = Color.lerp(const Color(0xFF3A3A3A), const Color(0xFFB8B8B8), k)!.withValues(alpha: 0.75 * (1 - k)),
      );
    }
  }

  void _blast(Canvas c, Offset at, double age, double size, double life) {
    if (age < 0 || age > life) return;
    final k = age / life;
    final r = size * _ease(k);
    c.drawCircle(at, r, Paint()..color = const Color(0xFFFF7A1A).withValues(alpha: 0.75 * (1 - k)));
    c.drawCircle(at, r * 0.62, Paint()..color = const Color(0xFFFFD23C).withValues(alpha: 0.9 * (1 - k)));
    final bit = Paint()..color = const Color(0xFF3A2A1E).withValues(alpha: 1 - k);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 + 0.2;
      c.drawCircle(at + Offset(math.cos(a), math.sin(a)) * r * 1.25, 2.8, bit);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t || old.skyline != skyline;
}
