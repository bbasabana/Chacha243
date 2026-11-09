import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Une marque affichée dans le jeu. [slots] dit où : `p1`, `p2`, `p3` (panneaux de l'aéroport), `kerosene` (bidon en vol).
class Ad {
  Ad({
    required this.id,
    required this.name,
    required this.tagline,
    required this.site,
    required this.color,
    required this.slots,
    this.years = '',
    this.builtin = '',
    this.logoVersion = '',
    this.ends,
  });

  final String id, name, tagline, site, builtin, logoVersion;
  final Color color;
  final Set<String> slots;
  /// Les années du jeu où la marque paraît, ex. « 1960, 2000-2005 » ; vide : toutes.
  final String years;

  /// Dernier jour d'affichage : la marque disparaît ensuite, même sans réseau.
  final DateTime? ends;
  ui.Image? logo;

  bool get running => ends == null || DateTime.now().isBefore(ends!.add(const Duration(days: 1)));

  bool inYear(double year) {
    if (years.trim().isEmpty) return true;
    final y = year.floor();
    for (final part in years.split(',')) {
      final ends = part.split('-').map((e) => int.tryParse(e.trim())).toList();
      if (ends.first == null) continue;
      if (y >= ends.first! && y <= (ends.last ?? ends.first!)) return true;
    }
    return false;
  }

  double _unit = 0;
  late TextPainter _name, _tag, _site, _offered, _toast;
  bool _showSite = true;
  String _said = '';

  void _layout(double unit) {
    if (_unit == unit) return;
    _unit = unit;
    TextPainter text(String s, double size, FontWeight w, Color c, double width, int lines) => TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: c, fontSize: size * unit, fontWeight: w, height: 1.12)),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: width * unit);
    _name = text(name, 17, FontWeight.w800, Colors.white, Ads._textWidth, 1);
    _tag = text(tagline, 9.5, FontWeight.w600, const Color(0xF2FFFFFF), Ads._textWidth, 3);
    _site = text(site, 7.5, FontWeight.w800, const Color(0xFFFFD94A), Ads._textWidth, 1);
    _showSite = site.isNotEmpty && _tag.computeLineMetrics().length < 3;
    _toast = text(name, 14, FontWeight.w800, Colors.white, 150, 1);
  }
}

/// Les publicités : intégrées au décor, elles ne coupent jamais le vol et n'interceptent aucun toucher.
/// La liste vient du tableau de bord ; sans réseau, on garde la dernière reçue, sinon les trois de départ.
class Ads {
  const Ads._();

  static const _url = 'https://waddiel.pro/api/v1/chacha/ads';
  static const _cacheKey = 'chacha243.ads';
  static const _textWidth = 100.0;
  static const panelCount = 7;

  static List<Ad> list = const [];
  static DateTime? _fetched;
  static int _turn = 0;

  static List<Ad> _bundled() => [
    Ad(
      id: 'kairos',
      name: 'KairOS',
      tagline: 'Nettoie, accélère et protège ton appareil.',
      site: 'getkairos.pro',
      color: const Color(0xFF1F73E8),
      slots: {'p1', 'p3', 'kerosene', 'ciel', 'independance', 'arrivee'},
      builtin: 'kairos',
    ),
    Ad(
      id: 'waddiel',
      name: 'Waddiel',
      tagline: 'Sauvegarde et protège tes bases PostgreSQL.',
      site: 'waddiel.pro',
      color: const Color(0xFF5A4BEA),
      slots: {'p2', 'p3', 'kerosene', 'ciel', 'independance', 'arrivee'},
      builtin: 'waddiel',
    ),
    Ad(
      id: 'herozion',
      name: 'Herozion',
      tagline: 'Trouvez vos failles. Corrigez-les aussi.',
      site: 'herozion.io',
      color: const Color(0xFF14171F),
      slots: {'p1', 'p2', 'kerosene', 'ciel', 'independance', 'arrivee'},
      builtin: 'herozion',
    ),
    Ad(
      id: 'murmur',
      name: 'Murmur',
      tagline: 'Le réseau tombe. Le message part quand même.',
      site: 'ondemurmur.com',
      color: const Color(0xFF3A2210),
      slots: {'p2', 'p3', 'kerosene', 'ciel', 'independance', 'arrivee'},
      builtin: 'murmur',
    ),
    Ad(
      id: 'simplypay',
      name: 'SimplyPay',
      tagline: 'Encaissez Orange Money, Airtel Money, M-Pesa et Visa — API',
      site: '',
      color: const Color(0xFF0F3D78),
      slots: {'p1', 'p3', 'kerosene', 'ciel', 'independance', 'arrivee'},
      builtin: 'simplypay',
    ),
    Ad(
      id: 'promptauth',
      name: 'PromptAuth',
      tagline: 'Le login Google en un prompt.',
      site: 'promptauth.dev',
      color: const Color(0xFF0E6F60),
      slots: {'p1', 'p2', 'kerosene', 'ciel', 'independance', 'arrivee'},
      builtin: 'promptauth',
    ),
  ];

  /// Lu une fois au lancement : d'abord ce qu'on a déjà, puis le tableau de bord.
  static Future<void> load() async {
    if (list.isEmpty) {
      final saved = await _saved();
      list = saved ?? await _withBuiltinLogos(_bundled());
    }
    await refresh();
  }

  /// Au plus toutes les cinq minutes, pour qu'un changement du tableau de bord arrive au vol suivant.
  static Future<void> refresh() async {
    if (kIsWeb) return;
    final now = DateTime.now();
    if (_fetched != null && now.difference(_fetched!).inMinutes < 5) return;
    _fetched = now;
    try {
      final r = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return;
      final ads = _parse(r.body);
      await _withBuiltinLogos(ads);
      await _withRemoteLogos(ads);
      list = ads;
      (await SharedPreferences.getInstance()).setString(_cacheKey, r.body);
    } catch (_) {
      // Sans réseau, le jeu garde ce qu'il a.
    }
  }

  static List<Ad> _parse(String body) {
    final raw = (jsonDecode(body) as Map<String, dynamic>)['ads'] as List<dynamic>;
    return [
      for (final a in raw.cast<Map<String, dynamic>>())
        Ad(
          id: '${a['id']}',
          name: a['name'] as String? ?? '',
          tagline: a['tagline'] as String? ?? '',
          site: a['site'] as String? ?? '',
          color: _color(a['color'] as String? ?? ''),
          slots: {...(a['slots'] as List<dynamic>? ?? const []).cast<String>()},
          years: a['years'] as String? ?? '',
          builtin: a['builtin'] as String? ?? '',
          logoVersion: a['logo'] as String? ?? '',
          ends: DateTime.tryParse(a['ends'] as String? ?? ''),
        ),
    ];
  }

  static Color _color(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF14171F) : Color(0xFF000000 | v);
  }

  static Future<List<Ad>?> _saved() async {
    try {
      final body = (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (body == null) return null;
      final ads = _parse(body);
      await _withBuiltinLogos(ads);
      await _withSavedLogos(ads);
      return ads;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async =>
      (await (await ui.instantiateImageCodec(bytes, targetWidth: 256)).getNextFrame()).image;

  static Future<List<Ad>> _withBuiltinLogos(List<Ad> ads) async {
    for (final a in ads) {
      if (a.builtin.isEmpty || a.logoVersion.isNotEmpty) continue;
      try {
        final data = await rootBundle.load('assets/ads/${a.builtin}.png');
        a.logo = await _decode(data.buffer.asUint8List());
      } catch (_) {
        // Sans son image, la marque n'est simplement pas affichée.
      }
    }
    return ads;
  }

  static String _logoKey(Ad a) => 'chacha243.ad.${a.id}';

  static Future<void> _withSavedLogos(List<Ad> ads) async {
    final p = await SharedPreferences.getInstance();
    for (final a in ads.where((a) => a.logoVersion.isNotEmpty)) {
      final s = p.getString(_logoKey(a));
      if (s == null || !s.startsWith('${a.logoVersion}:')) continue;
      a.logo = await _decode(base64Decode(s.substring(a.logoVersion.length + 1)));
    }
  }

  static Future<void> _withRemoteLogos(List<Ad> ads) async {
    final p = await SharedPreferences.getInstance();
    await _withSavedLogos(ads);
    for (final a in ads.where((a) => a.logoVersion.isNotEmpty && a.logo == null)) {
      final r = await http
          .get(Uri.parse('$_url/logo?id=${a.id}&v=${Uri.encodeQueryComponent(a.logoVersion)}'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) continue;
      a.logo = await _decode(r.bodyBytes);
      await p.setString(_logoKey(a), '${a.logoVersion}:${base64Encode(r.bodyBytes)}');
    }
  }

  static List<Ad> _for(String slot, double year) =>
      list.where((a) => a.logo != null && a.running && a.slots.contains(slot) && a.inYear(year)).toList();

  /// La prochaine marque d'un emplacement, à tour de rôle.
  static Ad? next(String slot, double year) {
    final ads = _for(slot, year);
    return ads.isEmpty ? null : ads[_turn++ % ads.length];
  }

  /// Un panneau numérique le long de la piste, sur deux pieds posés en [base]. Il fait défiler les marques
  /// réservées sur son emplacement ; un emplacement libre ne dessine rien.
  static void board(Canvas c, Offset base, double u, double t, int index, double year, double dusk) {
    final ads = _for('p${index % 3 + 1}', year);
    if (ads.isEmpty) return;
    const stay = 5.0, swap = 0.5;
    final clock = t + index * 1.3;
    final n = (clock / stay).floor();
    final phase = clock - n * stay;
    final now = ads[n % ads.length];
    final before = ads[(n - 1) % ads.length];
    final p = ads.length > 1 && phase < swap ? Curves.easeInOut.transform(phase / swap) : 1.0;

    const w = 168.0, h = 66.0, legs = 14.0;
    final frame = Rect.fromLTWH(base.dx - w / 2 * u, base.dy - (h + legs) * u, w * u, h * u);
    final posts = Paint()..color = const Color(0xFF232833);
    for (final x in [-52.0, 52.0]) {
      c.drawRect(Rect.fromLTWH(base.dx + (x - 2.5) * u, frame.bottom, 5 * u, legs * u), posts);
    }
    final rr = RRect.fromRectAndRadius(frame, Radius.circular(6 * u));
    c.drawRRect(
      rr.inflate(2 * u),
      Paint()
        ..color = now.color.withValues(alpha: 0.2 + 0.35 * dusk)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * u),
    );
    c.drawRRect(rr, Paint()..color = const Color(0xFF0B0E14));

    final screen = frame.deflate(3 * u);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(screen, Radius.circular(3.5 * u)));
    if (p < 1) _content(c, screen.shift(Offset(0, -screen.height * p)), before, u);
    _content(c, screen.shift(Offset(0, screen.height * (1 - p))), now, u);
    // La trame des diodes.
    final led = Paint()..color = const Color(0x14000000);
    for (var y = screen.top; y < screen.bottom; y += 2.2 * u) {
      c.drawRect(Rect.fromLTWH(screen.left, y, screen.width, 0.8 * u), led);
    }
    for (var x = screen.left; x < screen.right; x += 2.2 * u) {
      c.drawRect(Rect.fromLTWH(x, screen.top, 0.8 * u, screen.height), led);
    }
    c.restore();
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * u
        ..color = const Color(0x33FFFFFF),
    );
  }

  static void _content(Canvas c, Rect r, Ad a, double u) {
    a._layout(u);
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(a.color, Colors.white, 0.12)!, Color.lerp(a.color, Colors.black, 0.45)!],
        ).createShader(r),
    );
    final size = 46 * u;
    _logo(c, Rect.fromLTWH(r.left + 7 * u, r.center.dy - size / 2, size, size), a, 10 * u);
    final x = r.left + 60 * u;
    final total = a._name.height + 2 * u + a._tag.height + (a._showSite ? 3 * u + a._site.height : 0);
    var y = r.center.dy - total / 2;
    a._name.paint(c, Offset(x, y));
    y += a._name.height + 2 * u;
    a._tag.paint(c, Offset(x, y));
    y += a._tag.height + 3 * u;
    if (a._showSite) a._site.paint(c, Offset(x, y));
  }

  static void _logo(Canvas c, Rect r, Ad a, double radius) {
    final img = a.logo;
    if (img == null) return;
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      r,
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.restore();
  }

  /// Un petit avion qui traverse le ciel en tirant une banderole ; [x] est le nez de l'avion.
  static void towed(Canvas c, double x, double y, double u, Ad a) {
    a._layout(u);
    final plane = Paint()..color = Colors.white;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y - 3.5 * u, 30 * u, 7 * u), Radius.circular(3.5 * u)), plane);
    c.drawPath(
      Path()
        ..moveTo(x + 13 * u, y)
        ..lineTo(x + 20 * u, y + 11 * u)
        ..lineTo(x + 24 * u, y + 11 * u)
        ..lineTo(x + 21 * u, y)
        ..close()
        ..moveTo(x + 25 * u, y - 2 * u)
        ..lineTo(x + 31 * u, y - 10 * u)
        ..lineTo(x + 34 * u, y - 10 * u)
        ..lineTo(x + 31 * u, y + 2 * u)
        ..close(),
      plane,
    );
    final left = x + 66 * u;
    final w = 44 * u + a._toast.width + 14 * u, h = 36 * u;
    c.drawLine(
      Offset(x + 30 * u, y),
      Offset(left, y),
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 1 * u,
    );
    final r = Rect.fromLTWH(left, y - h / 2, w, h);
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(4 * u)),
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(a.color, Colors.white, 0.12)!, Color.lerp(a.color, Colors.black, 0.35)!],
        ).createShader(r),
    );
    _logo(c, Rect.fromLTWH(left + 6 * u, y - 13 * u, 26 * u, 26 * u), a, 6 * u);
    a._toast.paint(c, Offset(left + 40 * u, y - a._toast.height / 2));
  }

  /// Le petit logo au-dessus d'un bidon sponsorisé.
  static void chip(Canvas c, Offset at, double r, Ad a) {
    c.drawCircle(at, r + 1.6, Paint()..color = Colors.white);
    _logo(c, Rect.fromCircle(center: at, radius: r), a, r);
  }

  /// « Kérosène offert par… » : une pastille qui passe puis s'efface, [age] secondes après son arrivée.
  static void thanks(Canvas c, Size s, double u, Ad a, double age, String label, double top) {
    const life = 2.8, edge = 0.3;
    if (age < 0 || age > life) return;
    final fade = math.min(math.min(age / edge, (life - age) / edge), 1.0);
    a._layout(u);
    if (a._said != label) {
      a._said = label;
      a._offered = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: const Color(0xE6FFFFFF), fontSize: 9 * u, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 170 * u);
    }
    final textW = math.max(a._offered.width, a._toast.width);
    final w = 34 * u + 22 * u + textW, h = 42 * u;
    final r = Rect.fromLTWH((s.width - w) / 2, s.height * top - (1 - fade) * 10 * u, w, h);
    c.saveLayer(r.inflate(2), Paint()..color = Color.fromRGBO(255, 255, 255, fade));
    final rr = RRect.fromRectAndRadius(r, Radius.circular(21 * u));
    c.drawRRect(rr, Paint()..color = const Color(0xCC10233F));
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * u
        ..color = const Color(0x55FFFFFF),
    );
    final size = 30 * u;
    _logo(c, Rect.fromLTWH(r.left + 7 * u, r.top + 6 * u, size, size), a, 8 * u);
    final x = r.left + 44 * u;
    final y = r.center.dy - (a._offered.height + a._toast.height) / 2;
    a._offered.paint(c, Offset(x, y));
    a._toast.paint(c, Offset(x, y + a._offered.height));
    c.restore();
  }
}
