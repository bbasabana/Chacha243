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

  /// Les textes des grands panneaux du boulevard, posés une fois à leur taille à eux.
  TextPainter? _bigName, _bigTag, _bigSite;

  void _layoutBig() {
    if (_bigName != null) return;
    TextPainter text(String s, double size, FontWeight w, Color c, int lines) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: c, fontSize: size, fontWeight: w, height: 1.1, letterSpacing: -0.2),
      ),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: BoulevardBoards._textWidth);
    _bigName = text(name, 27, FontWeight.w900, Colors.white, 1);
    _bigTag = text(tagline, 13.5, FontWeight.w600, const Color(0xF2FFFFFF), 2);
    _bigSite = text(site.isEmpty ? name : site, 11.5, FontWeight.w800, const Color(0xFFFFD94A), 1);
  }

  bool _showSite = true;
  String _said = '';

  void _layout(double unit) {
    if (_unit == unit) return;
    _unit = unit;
    TextPainter text(String s, double size, FontWeight w, Color c, double width, int lines) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: c, fontSize: size * unit, fontWeight: w, height: 1.12),
      ),
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

  /// ZwaColis paraît toujours, même quand le tableau de bord n'envoie pas encore cette marque.
  static Ad _zwaColis() => Ad(
    id: 'zwacolis',
    name: 'ZwaColis',
    tagline: 'Envoyez vos colis Europe-Afrique avec des voyageurs.',
    site: '',
    color: const Color(0xFF1B2E24),
    slots: {'p1', 'p2', 'p3', 'kerosene', 'ciel', 'independance', 'arrivee'},
    builtin: 'zwacolis',
  );

  /// L'Académie Digitale (Jompik's technology) paraît toujours, elle aussi.
  static Ad _academie() => Ad(
    id: 'jompiks',
    name: 'Académie Digitale',
    tagline: 'Jompik\'s technology : apprends le numérique, crée ton avenir.',
    site: '',
    color: const Color(0xFF0B5C8E),
    slots: {'p1', 'p2', 'p3', 'kerosene', 'ciel', 'independance', 'arrivee'},
    builtin: 'jompiks',
  );

  static List<Ad> _bundled() => [
    _zwaColis(),
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
    _academie(),
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
    final ads = [
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
    if (!ads.any((a) => a.id == 'zwacolis')) ads.add(_zwaColis());
    if (!ads.any((a) => a.id == 'jompiks')) ads.add(_academie());
    return ads;
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

  static List<Ad> _for(String slot, double year) => list
      .where(
        (a) =>
            a.logo != null &&
            a.running &&
            // Le boulevard montre les marques des panneaux de l'aéroport, sans qu'on ait à les réserver.
            (a.slots.contains(slot) || (slot == 'boulevard' && a.slots.any((s) => s.startsWith('p')))) &&
            a.inYear(year),
      )
      .toList();

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
        text: TextSpan(
          text: label,
          style: TextStyle(color: const Color(0xE6FFFFFF), fontSize: 9 * u, fontWeight: FontWeight.w600),
        ),
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

/// Les grands panneaux numériques du boulevard Lumumba, au-dessus des immeubles, quand l'avion rase la rue
/// (1963, 1990, 1997). Chaque marque y joue une petite animation de son métier — le scan de Herozion qui trouve
/// et corrige les failles, le colis de ZwaColis qui traverse de l'Europe à l'Afrique, la sauvegarde de Waddiel… —
/// puis la suivante glisse à sa place. Le panneau se dessine dans un écran de 320 × 180, puis à sa taille.
abstract final class BoulevardBoards {
  static const _w = 320.0, _h = 180.0, _textWidth = 206.0;
  static const _stay = 7.0, _swap = 0.8;

  /// Les marques de ces panneaux cette année-là ; vide tant qu'aucun logo n'est chargé.
  static List<Ad> ads(double year) => Ads._for('boulevard', year);

  /// La marque qu'affiche le panneau [index] à l'instant [t] (pour sa lueur, le soir).
  static Ad? current(List<Ad> ads, double t, int index) {
    if (ads.isEmpty) return null;
    final n = ((t + index * 2.7) / _stay).floor() + index * 3;
    return ads[n % ads.length];
  }

  /// Le panneau [index] dans [r] : le cadre, l'écran, la marque du moment et celle qui s'en va.
  static void draw(Canvas c, Rect r, List<Ad> ads, double t, int index) {
    if (ads.isEmpty) return;
    final clock = t + index * 2.7;
    final n = (clock / _stay).floor() + index * 3;
    final phase = clock % _stay;
    final now = ads[n % ads.length], before = ads[(n - 1) % ads.length];
    final p = ads.length > 1 && phase < _swap ? Curves.easeInOutCubic.transform(phase / _swap) : 1.0;

    // Le cadre d'acier et sa lueur de la couleur de la marque.
    final frame = RRect.fromRectAndRadius(r.inflate(r.width * 0.025), Radius.circular(r.width * 0.03));
    c.drawRRect(
      frame.inflate(r.width * 0.01),
      Paint()
        ..color = now.color.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.width * 0.04),
    );
    c.drawRRect(frame, Paint()..color = const Color(0xFF12151C));
    c.save();
    c.translate(r.left, r.top);
    c.scale(r.width / _w, r.height / _h);
    c.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, _w, _h), const Radius.circular(6)));
    if (p < 1) {
      c.save();
      c.translate(-_w * 0.35 * p, 0);
      _scene(c, before, t, 1);
      c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = Color.fromRGBO(0, 0, 0, 0.6 * p));
      c.restore();
      c.save();
      c.translate(_w * (1 - p), 0);
      _scene(c, now, t, phase / _stay);
      c.restore();
      // Le bord lumineux qui pousse l'ancienne marque.
      c.drawRect(Rect.fromLTWH(_w * (1 - p) - 3, 0, 3, _h), Paint()..color = const Color(0xCCFFFFFF));
    } else {
      _scene(c, now, t, phase / _stay);
    }
    // La trame des diodes, et un reflet qui passe sur la vitre.
    final led = Paint()..color = const Color(0x16000000);
    for (var y = 0.0; y < _h; y += 3) {
      c.drawRect(Rect.fromLTWH(0, y, _w, 1), led);
    }
    final sweep = (t * 70 + index * 140) % (_w * 3) - _w * 0.5;
    c.drawRect(
      Rect.fromLTWH(sweep, 0, 90, _h),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x1FFFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(sweep, 0, 90, _h)),
    );
    c.restore();
    c.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r.width * 0.008)
        ..color = const Color(0x55FFFFFF),
    );
  }

  /// Une marque à l'écran : son fond qui bouge, son logo qui respire, ses mots, son animation, son temps qui file.
  static void _scene(Canvas c, Ad a, double t, double progress) {
    a._layoutBig();
    const full = Rect.fromLTWH(0, 0, _w, _h);
    c.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(a.color, Colors.white, 0.16)!, Color.lerp(a.color, Colors.black, 0.55)!],
        ).createShader(full),
    );
    // Des bandes de lumière qui glissent lentement derrière tout.
    final band = Paint()..color = const Color(0x0DFFFFFF);
    for (var i = 0; i < 6; i++) {
      final x = (i * 70 + t * 16) % (_w + 140) - 70;
      c.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + 26, 0)
          ..lineTo(x - 34, _h)
          ..lineTo(x - 60, _h)
          ..close(),
        band,
      );
    }
    // « EN DIRECT » : le point rouge qui clignote.
    c.drawCircle(
      const Offset(_w - 14, 12),
      3.2,
      Paint()..color = Color.fromRGBO(255, 70, 70, 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 5))),
    );
    // Le logo et l'onde qui part de lui.
    const logo = Rect.fromLTWH(16, 20, 66, 66);
    final ring = (t * 0.7) % 1;
    c.drawCircle(
      logo.center,
      36 + ring * 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.fromRGBO(255, 255, 255, 0.35 * (1 - ring)),
    );
    c.drawRRect(RRect.fromRectAndRadius(logo.inflate(3), const Radius.circular(17)), Paint()..color = Colors.white);
    final breathe = 1 + 0.03 * math.sin(t * 2.2);
    Ads._logo(c, Rect.fromCenter(center: logo.center, width: 66 * breathe, height: 66 * breathe), a, 15);
    // Les mots : le nom, la promesse, le site.
    var y = 18.0;
    a._bigName!.paint(c, Offset(96, y));
    y += a._bigName!.height + 4;
    a._bigTag!.paint(c, Offset(96, y));
    y += a._bigTag!.height + 5;
    a._bigSite!.paint(c, Offset(96, y));
    // L'animation de la marque, en bas.
    _motif(c, a, const Rect.fromLTWH(16, 118, 288, 44), t);
    // Le temps qui reste à la marque sur l'écran.
    c.drawRect(const Rect.fromLTWH(0, _h - 4, _w, 4), Paint()..color = const Color(0x26FFFFFF));
    c.drawRect(Rect.fromLTWH(0, _h - 4, _w * progress, 4), Paint()..color = const Color(0xFFFFD94A));
  }

  static Paint _fill(Color c) => Paint()..color = c;
  static Paint _line(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = c;

  static void _check(Canvas c, Offset at, double s, Color color) => c.drawPath(
    Path()
      ..moveTo(at.dx - s, at.dy)
      ..lineTo(at.dx - s * 0.3, at.dy + s * 0.7)
      ..lineTo(at.dx + s, at.dy - s * 0.8),
    _line(color, s * 0.45),
  );

  static Offset _arc(Offset a, Offset m, Offset b, double k) =>
      a * ((1 - k) * (1 - k)) + m * (2 * (1 - k) * k) + b * (k * k);

  static void _motif(Canvas c, Ad a, Rect m, double t) {
    const white = Color(0xE6FFFFFF), soft = Color(0x40FFFFFF), green = Color(0xFF3DDC84), red = Color(0xFFFF5252);
    c.drawRRect(RRect.fromRectAndRadius(m, const Radius.circular(8)), _fill(const Color(0x33000000)));
    final key = a.builtin.isNotEmpty ? a.builtin : a.id;
    switch (key) {
      case 'herozion':
        // Le scan passe sur trois lignes de code : chaque faille rouge devient verte, corrigée.
        final k = (t % 6) / 6;
        for (var i = 0; i < 3; i++) {
          final y = m.top + 9 + i * 13.0, len = const [168.0, 122.0, 196.0][i];
          final fixed = k > 0.28 + i * 0.2;
          final blink = 0.5 + 0.5 * math.sin(t * 9);
          c.drawCircle(Offset(m.left + 12, y + 3), 4, _fill(fixed ? green : red.withValues(alpha: 0.5 + 0.5 * blink)));
          c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(m.left + 24, y, len, 6), const Radius.circular(3)),
            _fill(fixed ? const Color(0x553DDC84) : soft),
          );
          if (fixed) _check(c, Offset(m.left + 36 + len, y + 3), 5, green);
        }
        final x = m.left + 20 + (k * 1.6 % 1) * (m.width - 24);
        c.drawRect(Rect.fromLTWH(x, m.top + 3, 3, m.height - 6), _fill(const Color(0xCC5CF2B0)));
      case 'zwacolis':
        // Le colis part d'Europe et arrive en Afrique, le long de la route en pointillés.
        final from = Offset(m.left + 18, m.bottom - 12), to = Offset(m.right - 18, m.bottom - 12);
        final mid = Offset(m.center.dx, m.top - 10);
        for (var i = 0; i <= 18; i++) {
          c.drawCircle(_arc(from, mid, to, i / 18), 1.6, _fill(soft));
        }
        final k = (t * 0.22) % 1, box = _arc(from, mid, to, Curves.easeInOut.transform(k));
        c.drawCircle(from, 6, _fill(const Color(0xFF5B8DEF)));
        c.drawCircle(to, 6, _fill(green));
        if (k > 0.85) {
          final r = (k - 0.85) / 0.15;
          c.drawCircle(to, 6 + r * 12, _line(green.withValues(alpha: 1 - r), 2));
        }
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: box, width: 14, height: 12), const Radius.circular(2)),
          _fill(const Color(0xFFE8B04A)),
        );
        c.drawLine(box.translate(-7, 0), box.translate(7, 0), _line(const Color(0xFF8A5A1E), 1.5));
      case 'waddiel':
        // La base de données se sauvegarde : la barre se remplit, le bouclier se ferme.
        final db = Offset(m.left + 22, m.center.dy);
        for (var i = 2; i >= 0; i--) {
          final r = Rect.fromCenter(center: db.translate(0, -9 + i * 9.0), width: 26, height: 9);
          c.drawRect(Rect.fromLTRB(r.left, r.center.dy, r.right, r.center.dy + 9), _fill(const Color(0xFF8C82FF)));
          c.drawOval(r, _fill(i == 0 ? const Color(0xFFC9C3FF) : const Color(0xFFA79FFF)));
        }
        final k = (t * 0.3) % 1;
        final bar = Rect.fromLTWH(m.left + 50, m.center.dy - 5, m.width - 96, 10);
        c.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(5)), _fill(soft));
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bar.left, bar.top, bar.width * math.min(1, k * 1.25), 10),
            const Radius.circular(5),
          ),
          _fill(const Color(0xFF8C82FF)),
        );
        final shield = Offset(m.right - 22, m.center.dy);
        c.drawPath(
          Path()
            ..moveTo(shield.dx, shield.dy - 13)
            ..lineTo(shield.dx + 11, shield.dy - 8)
            ..quadraticBezierTo(shield.dx + 10, shield.dy + 8, shield.dx, shield.dy + 14)
            ..quadraticBezierTo(shield.dx - 10, shield.dy + 8, shield.dx - 11, shield.dy - 8)
            ..close(),
          _fill(k > 0.8 ? green : soft),
        );
        if (k > 0.8) _check(c, shield, 5, Colors.white);
      case 'murmur':
        // Le réseau tombe au milieu : le message saute par-dessus et arrive quand même.
        final from = Offset(m.left + 16, m.center.dy), to = Offset(m.right - 16, m.center.dy);
        for (var j = 0; j < 3; j++) {
          final k = (t * 0.8 + j / 3) % 1;
          c.drawArc(
            Rect.fromCircle(center: from, radius: 6 + k * 18),
            -0.9,
            1.8,
            false,
            _line(Color.fromRGBO(255, 200, 120, 1 - k), 2),
          );
        }
        c.drawCircle(from, 4, _fill(const Color(0xFFFFB45A)));
        c.drawLine(from.translate(30, 0), Offset(m.center.dx - 16, m.center.dy), _line(soft, 2));
        c.drawLine(Offset(m.center.dx + 16, m.center.dy), to.translate(-14, 0), _line(soft, 2));
        final x = m.center;
        c.drawLine(x.translate(-5, -5), x.translate(5, 5), _line(red, 2.4));
        c.drawLine(x.translate(-5, 5), x.translate(5, -5), _line(red, 2.4));
        final k = (t * 0.35) % 1, bx = from.dx + 30 + (to.dx - from.dx - 44) * k;
        final hop = (bx - x.dx).abs() < 34 ? math.cos((bx - x.dx) / 34 * math.pi / 2) * 16 : 0.0;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(bx, m.center.dy - 2 - hop), width: 20, height: 13),
            const Radius.circular(5),
          ),
          _fill(white),
        );
        c.drawCircle(to, 5, _fill(k > 0.9 ? green : soft));
      case 'simplypay':
        // Orange Money, Airtel Money, M-Pesa et Visa : chaque paiement s'allume et se valide, à tour de rôle.
        const chips = [Color(0xFFFF7900), Color(0xFFE60012), Color(0xFF00A859), Color(0xFF1A1F71)];
        final active = (t * 1.2).floor() % 4, k = (t * 1.2) % 1;
        for (var i = 0; i < 4; i++) {
          final at = Offset(m.left + 36 + i * 72.0, m.center.dy);
          final pop = i == active ? 1 + 0.25 * math.sin(k * math.pi) : 1.0;
          c.drawCircle(at, 13 * pop, _fill(chips[i]));
          c.drawCircle(at, 13 * pop, _line(const Color(0x88FFFFFF), 1.5));
          if (i < active || (i == active && k > 0.5)) _check(c, at, 5, Colors.white);
        }
      case 'promptauth':
        // Le curseur arrive sur « Continuer avec Google », clique : connecté.
        final k = (t % 4) / 4;
        final button = Rect.fromLTWH(m.left + 10, m.top + 8, 176, 28);
        final pressed = k > 0.5 && k < 0.58;
        final done = k >= 0.58;
        c.drawRRect(
          RRect.fromRectAndRadius(pressed ? button.deflate(2) : button, const Radius.circular(14)),
          _fill(done ? green : Colors.white),
        );
        c.drawCircle(
          Offset(button.left + 18, button.center.dy),
          8,
          _fill(done ? Colors.white : const Color(0xFF4285F4)),
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(button.left + 34, button.center.dy - 3, 110, 6),
            const Radius.circular(3),
          ),
          _fill(done ? const Color(0x88FFFFFF) : const Color(0x55000000)),
        );
        if (done) _check(c, Offset(m.right - 40, m.center.dy), 8, green);
        final cursor = Offset.lerp(
          Offset(m.right - 20, m.bottom - 4),
          button.center,
          Curves.easeOut.transform(math.min(1, k * 2)),
        )!;
        c.drawPath(
          Path()
            ..moveTo(cursor.dx, cursor.dy)
            ..lineTo(cursor.dx, cursor.dy + 15)
            ..lineTo(cursor.dx + 4, cursor.dy + 11)
            ..lineTo(cursor.dx + 9, cursor.dy + 14)
            ..lineTo(cursor.dx + 10, cursor.dy + 11)
            ..lineTo(cursor.dx + 6, cursor.dy + 9)
            ..lineTo(cursor.dx + 11, cursor.dy + 8)
            ..close(),
          _fill(Colors.white),
        );
      case 'kairos':
        // L'aiguille passe du rouge au vert, et le cache, la mémoire et le disque se vident.
        final k = Curves.easeInOut.transform(((t % 5) / 5 * 1.4).clamp(0.0, 1.0));
        final center = Offset(m.left + 40, m.bottom - 6);
        final dial = Rect.fromCircle(center: center, radius: 30);
        c.drawArc(dial, math.pi, math.pi, false, _line(soft, 6));
        c.drawArc(dial, math.pi, math.pi * k, false, _line(Color.lerp(red, green, k)!, 6));
        final angle = math.pi + math.pi * k;
        c.drawLine(center, center + Offset(math.cos(angle), math.sin(angle)) * 24, _line(Colors.white, 2.5));
        for (var i = 0; i < 3; i++) {
          final full = 170.0 - i * 30, now = full * (1 - 0.7 * k);
          final y = m.top + 9 + i * 12.0;
          c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(m.left + 92, y, full, 6), const Radius.circular(3)),
            _fill(soft),
          );
          c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(m.left + 92, y, now, 6), const Radius.circular(3)),
            _fill(Color.lerp(red, const Color(0xFF6FB1FF), k)!),
          );
        }
      case 'jompiks':
        // Le code s'écrit tout seul, ligne après ligne, avec son curseur.
        const widths = [
          [30.0, 60.0, 24.0],
          [18.0, 46.0, 70.0],
          [40.0, 30.0, 52.0],
        ];
        const colors = [Color(0xFF7CD4FF), Color(0xFFFFD94A), Color(0xFFB6F09C)];
        final typed = (t * 70) % 520;
        var left = typed;
        for (var i = 0; i < 3; i++) {
          var x = m.left + 12 + (i == 1 ? 14 : 0);
          final y = m.top + 8 + i * 12.0;
          for (var j = 0; j < 3; j++) {
            final seg = math.min(widths[i][j], math.max(0.0, left));
            left -= widths[i][j];
            if (seg > 0) {
              c.drawRRect(
                RRect.fromRectAndRadius(Rect.fromLTWH(x, y, seg, 6), const Radius.circular(3)),
                _fill(colors[j]),
              );
            }
            x += widths[i][j] + 6;
            if (left <= 0 && left > -widths[i][j] && (t * 3).floor().isEven) {
              c.drawRect(Rect.fromLTWH(x - 6 + left, y - 1, 3, 8), _fill(Colors.white));
            }
          }
        }
      default:
        // Une marque venue du tableau de bord : un égaliseur de sa couleur.
        for (var i = 0; i < 24; i++) {
          final hgt = 6 + 28 * (0.5 + 0.5 * math.sin(t * 4 + i * 0.7)) * (0.5 + 0.5 * math.sin(i * 1.3));
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(m.left + 8 + i * 11.6, m.bottom - 5 - hgt, 7, hgt),
              const Radius.circular(2),
            ),
            _fill(Color.lerp(a.color, Colors.white, 0.5)!),
          );
        }
    }
  }
}
