import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../data/aircraft_types.dart';
import '../data/eras.dart';
import '../game/checkpoint.dart';
import '../game/music.dart';
import '../game/scenery.dart';
import '../game/telemetry.dart';
import '../painting/aircraft_painter.dart';
import '../painting/flag_painter.dart';
import '../theme/chacha_colors.dart';
import 'about_screen.dart';
import 'game_screen.dart';
import 'duel_screen.dart';
import 'glass.dart';
import 'hangar_screen.dart';
import 'ranking_screen.dart';
import 'timeline_screen.dart';

/// L'accueil : l'avion dessine la diagonale du drapeau dans le ciel, comme sur l'icône.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  Checkpoint? _saved;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    // « Indépendance Cha Cha » à l'ouverture du jeu ; elle s'arrête au décollage.
    Music.instance.play('chacha', loop: true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (pilotName.value == null) await _askName();
      if (mounted && !kIsWeb) await _showNews();
      // Un don fait pendant que l'app était fermée : le merci arrive à l'ouverture.
      if (mounted && !kIsWeb && await Telemetry.newGift() && mounted) await showGiftThanks(context);
    });
  }

  Future<void> _askName() async {
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: pilotName.value != null,
      builder: (_) => const _NameDialog(),
    );
    if (name != null && name.isNotEmpty) {
      await savePilotName(name);
      // Le nouveau nom part aussi au classement.
      if (!kIsWeb) Telemetry.hello();
    }
  }

  /// Le message envoyé à tous les pilotes depuis le tableau de bord : le champion, les récompenses.
  Future<void> _showNews() async {
    final n = await Telemetry.news();
    if (n == null || !mounted) return;
    await showDialog<void>(context: context, builder: (_) => _NewsDialog(n));
    await Telemetry.newsSeen(n.id);
  }

  void _volume() => showDialog<void>(context: context, builder: (_) => const _VolumeDialog());

  Future<void> _loadSaved() async {
    final cp = await Checkpoint.load();
    if (mounted) setState(() => _saved = cp);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Future<void> _play({Checkpoint? from}) async {
    await Music.instance.stop();
    if (!mounted) return;
    await Navigator.of(context).push(_fade(GameScreen(type: selectedAircraft.value, resume: from)));
    _loadSaved();
    Music.instance.play('chacha', loop: true);
  }

  void _hangar() => Navigator.of(context).push(_fade(const HangarScreen()));

  static PageRoute<void> _fade(Widget page) => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder(
            valueListenable: selectedAircraft,
            builder: (_, type, _) => AnimatedBuilder(
              animation: _clock,
              builder: (_, _) => CustomPaint(painter: _HomeSky(_clock.value * 30, type)),
            ),
          ),
          SafeArea(
            // Dessiné pour au moins 800 × 360 points : sur un écran plus petit (iPhone avec son îlot,
            // petit Android), l'accueil entier se réduit d'un bloc au lieu de déborder.
            child: LayoutBuilder(
              builder: (_, box) {
                final w = math.max(box.maxWidth, 800.0), h = math.max(box.maxHeight, 360.0);
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: SizedBox(width: w, height: h, child: _content()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ValueListenableBuilder(
                  valueListenable: pilotName,
                  builder: (_, name, _) => name == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: _askName,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Glass(
                              radius: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ValueListenableBuilder(
                                    valueListenable: pilotPhoto,
                                    builder: (_, photo, _) => photo == null
                                        ? const Icon(Icons.badge_rounded, color: ChachaColors.yellow, size: 18)
                                        : CircleAvatar(radius: 13, backgroundImage: MemoryImage(photo)),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Commandant $name · ${pilotRank(missionsDone.value)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Le nom et la photo se changent ici, à tout moment.
                                  const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 3),
                                  const Text('Nom et photo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                // Un championnat ouvert depuis le tableau de bord : son nom, son prix, sa date de fin.
                ValueListenableBuilder(
                  valueListenable: Telemetry.championship,
                  builder: (_, ch, _) => ch == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Glass(
                            radius: 14,
                            tint: const Color(0x40F7D618),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text(
                              '🏆 ${ch.title}${ch.prize.isEmpty ? '' : ' · prix ${ch.prize}'} · '
                              '${ch.first ? 'le premier' : 'le plus rapide'} jusqu\'en 2027 gagne'
                              '${ch.ends == null ? '' : ' · jusqu\'au ${ch.ends!.day}/${ch.ends!.month}'}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                ),
                const _Title(),
                const SizedBox(height: 10),
                Text(
                  "Pilote l'avion du Congo, de l'Indépendance à aujourd'hui.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    shadows: const [Shadow(color: Color(0x66001433), blurRadius: 12)],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Une reprise en dette n'est pas possible : il faut recommencer et récolter.
                    if (_saved case final cp? when cp.money >= 0)
                      _Pill(
                        icon: Icons.play_arrow_rounded,
                        label: 'Continuer',
                        sub: 'Reprendre en ${cp.year.floor()}',
                        primary: true,
                        onTap: () => _play(from: cp),
                      ),
                    _Pill(
                      icon: Icons.flight_takeoff_rounded,
                      label: _saved == null ? 'Décoller' : 'Recommencer',
                      sub: '30 juin 1960',
                      primary: _saved == null,
                      onTap: _play,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(icon: Icons.warehouse_rounded, label: 'Hangar', onTap: _hangar),
                    if (!kIsWeb)
                      _Pill(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Classement',
                        iconColor: ChachaColors.yellow,
                        onTap: () => Navigator.of(context).push(_fade(const RankingScreen())),
                      ),
                    if (!kIsWeb)
                      _Pill(
                        icon: Icons.sports_score_rounded,
                        label: 'Duel',
                        onTap: () => Navigator.of(context).push(_fade(const DuelScreen())),
                      ),
                    _Pill(
                      icon: Icons.menu_book_rounded,
                      label: 'Les dates',
                      onTap: () => Navigator.of(context).push(_fade(const TimelineScreen())),
                    ),
                    _Pill(
                      icon: Icons.favorite_rounded,
                      label: 'À propos · Soutenir',
                      onTap: () => Navigator.of(context).push(_fade(const AboutScreen())),
                    ),
                    ValueListenableBuilder(
                      valueListenable: musicVolume,
                      builder: (_, v, _) =>
                          _Pill(icon: v == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, onTap: _volume),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ValueListenableBuilder(
            valueListenable: selectedAircraft,
            builder: (_, type, _) => GestureDetector(
              onTap: _hangar,
              child: Glass(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: SizedBox(
                  width: 210,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('TON AVION', style: _label),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${type.maker} ${type.name}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Au Congo : ${type.inCongo}',
                        style: const TextStyle(color: ChachaColors.yellow, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${type.seats} passagers',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                      ),
                      const SizedBox(height: 10),
                      _Bar('Vitesse', type.speed),
                      _Bar('Maniabilité', type.handling),
                      _Bar('Réservoir', type.tank),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un bouton doux : un voile clair, un fin liseré, des bords tout ronds. Le principal est rouge, avec une date dessous.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    this.label,
    this.sub,
    this.onTap,
    this.primary = false,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String? label, sub;
  final VoidCallback? onTap;
  final bool primary;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final big = sub != null;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: primary ? const LinearGradient(colors: [Color(0xCCE5263A), Color(0xCCB3101F)]) : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.13),
          border: Border.all(color: Colors.white.withValues(alpha: primary ? 0.35 : 0.22)),
          boxShadow: primary ? const [BoxShadow(color: Color(0x55B3101F), blurRadius: 18, offset: Offset(0, 6))] : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: label == null ? 14 : (big ? 22 : 18), vertical: big ? 9 : 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: big ? 26 : 20),
                if (label != null) ...[
                  SizedBox(width: big ? 12 : 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: big ? 17 : 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      if (sub != null)
                        Text(sub!, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une jauge de l'avion : vitesse, maniabilité, réservoir.
class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 6, color: const Color(0x33FFFFFF)),
                  FractionallySizedBox(
                    widthFactor: value.clamp(0.05, 1.0),
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [ChachaColors.yellow, ChachaColors.red]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _label = TextStyle(color: Color(0xCCFFFFFF), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6);

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Chacha',
          style: TextStyle(
            color: Colors.white,
            fontSize: 64,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            shadows: [Shadow(color: Color(0x80001433), blurRadius: 24, offset: Offset(0, 6))],
          ),
        ),
        const SizedBox(width: 6),
        Glass(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          tint: const Color(0x66F7D618),
          child: const Text(
            '243',
            style: TextStyle(color: Colors.white, fontSize: 40, height: 1.1, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _HomeSky extends CustomPainter {
  _HomeSky(this.t, this.type);

  final double t;
  final AircraftType type;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ChachaColors.skyLight, ChachaColors.sky, ChachaColors.skyDeep],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    final unit = h / 420;
    for (var i = 0; i < 7; i++) {
      final speed = 8 + i * 5.0;
      final x = (w + 300) - ((t * speed + i * 260) % (w + 600));
      Scenery.cloud(canvas, Offset(x, h * (0.12 + (i * 0.13) % 0.8)), unit * (14 + (i * 7) % 20));
    }

    // L'étoile du drapeau
    final star = Offset(w * 0.14, h * 0.2);
    Scenery.glow(canvas, star, h * 0.02, ChachaColors.yellow);
    canvas.drawPath(FlagPainter.starPath(star, h * 0.09), Paint()..color = ChachaColors.yellow);

    // La traînée dessine la diagonale du drapeau jusqu'à l'avion
    final bob = math.sin(t * 1.2) * h * 0.015;
    final plane = Offset(w * 0.6, h * 0.36 + bob);
    final angle = -math.atan2(h * 0.62, w * 0.7);
    final from = Offset(plane.dx - w * 0.9, plane.dy + w * 0.9 * math.tan(-angle));
    for (final (color, width) in [(ChachaColors.yellow, h * 0.2), (ChachaColors.red, h * 0.15)]) {
      canvas.drawLine(
        from,
        plane,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(
      from + Offset(0, -h * 0.045),
      plane + Offset(-h * 0.08, -h * 0.045),
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..strokeWidth = h * 0.025
        ..strokeCap = StrokeCap.round,
    );

    final len = math.min(w * 0.36, h * 0.8);
    canvas.save();
    canvas.translate(plane.dx + len * 0.2, plane.dy - len * 0.05);
    canvas.rotate(angle * 0.9);
    canvas.translate(-len / 2, -len / 4);
    AircraftPainter.paint(canvas, Size(len, len / 2), type, airlineAt(2025).livery, propPhase: t * 40, blink: t);
    canvas.restore();

    // Reflet de verre sur tout l'écran
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.6, -0.8),
          radius: 1.2,
          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HomeSky old) => old.t != t || old.type != type;
}

/// Le nom du pilote, demandé une fois.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _field = TextEditingController(text: pilotName.value ?? '');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  bool _picking = false;

  Future<void> _pickPhoto(ImageSource from) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final f = await ImagePicker().pickImage(source: from, maxWidth: 320, maxHeight: 320, imageQuality: 78);
      if (f != null) {
        final bytes = await f.readAsBytes();
        await savePilotPhoto(bytes);
        Telemetry.syncPhoto();
      }
    } catch (_) {}
    if (mounted) setState(() => _picking = false);
  }

  void _done() {
    final n = _field.text.trim();
    if (n.isNotEmpty) Navigator.of(context).pop(n.length > 18 ? n.substring(0, 18) : n);
  }

  @override
  Widget build(BuildContext context) {
    // Couché, la place manque : la photo à gauche, le nom à droite, et pas de clavier tant qu'on
    // ne touche pas le nom. Tout défile si le clavier prend de la place.
    final avatar = ValueListenableBuilder(
      valueListenable: pilotPhoto,
      builder: (_, photo, _) => GestureDetector(
        onTap: () => _pickPhoto(ImageSource.gallery),
        child: CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0x33FFFFFF),
          backgroundImage: photo == null ? null : MemoryImage(photo),
          child: _picking
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : photo == null
              ? const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 30)
              : null,
        ),
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Glass(
            tint: const Color(0x66001A40),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    avatar,
                    const SizedBox(height: 10),
                    GlassButton(
                      onTap: () => _pickPhoto(ImageSource.gallery),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: const Text('Choisir une photo', style: TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(height: 6),
                    GlassButton(
                      onTap: () => _pickPhoto(ImageSource.camera),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: const Text('Prendre un selfie', style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pilotName.value == null
                            ? 'Mbote ! Comment t\'appelles-tu, commandant ?'
                            : 'Ton nom et ta photo de pilote',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ils vont au classement des pilotes et restent même si tu réinstalles le jeu.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _field,
                        autofocus: false,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        maxLength: 18,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          hintText: 'Ton nom de pilote',
                          labelText: pilotName.value == null
                              ? 'Ton nom de pilote'
                              : 'Nom de pilote · touche pour le changer',
                          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0x22FFFFFF),
                          prefixIcon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        // Le ✓ du clavier ferme le clavier : on revoit la fenêtre, puis on enregistre.
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (pilotName.value != null) ...[
                            GlassButton(onTap: () => Navigator.of(context).pop(), child: const Text('Fermer')),
                            const SizedBox(width: 10),
                          ],
                          GlassButton(onTap: _done, tint: const Color(0x55CE1021), child: const Text('Enregistrer')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _duration(int s) => s >= 3600
    ? '${s ~/ 3600} h ${((s % 3600) ~/ 60).toString().padLeft(2, '0')}'
    : '${s ~/ 60} min ${(s % 60).toString().padLeft(2, '0')} s';

/// Le message du tableau de bord : un champion en photo, le texte, la récompense.
class _NewsDialog extends StatelessWidget {
  const _NewsDialog(this.news);

  final News news;

  @override
  Widget build(BuildContext context) {
    final n = news;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: MediaQuery.sizeOf(context).height - 40),
        child: SingleChildScrollView(
          child: Glass(
            tint: const Color(0x77001A40),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (n.champion != null) ...[
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: ChachaColors.yellow),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: ChachaColors.night,
                      backgroundImage: n.photo == null ? null : MemoryImage(n.photo!),
                      child: n.photo == null
                          ? const Icon(Icons.emoji_events_rounded, color: ChachaColors.yellow, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🏆 ${n.champion}${n.seconds > 0
                        ? ' · 1960 → 2027 en ${_duration(n.seconds)}'
                        : n.championYear != null
                        ? ' · arrivé en ${n.championYear}'
                        : ''}',
                    style: const TextStyle(color: ChachaColors.yellow, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  n.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                ),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    n.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                  ),
                ],
                if (n.reward.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x33F7D618),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66F7D618)),
                    ),
                    child: Text(
                      '🎁 Récompense : ${n.reward}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                GlassButton(
                  onTap: () => Navigator.of(context).pop(),
                  tint: const Color(0x55CE1021),
                  child: const Text('Mbote ! On décolle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeDialog extends StatelessWidget {
  const _VolumeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Glass(
          tint: const Color(0x66001A40),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: ValueListenableBuilder(
            valueListenable: musicVolume,
            builder: (_, v, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Volume de la musique',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: [
                    const Icon(Icons.volume_mute_rounded, color: Colors.white),
                    Expanded(
                      child: Slider(value: v, onChanged: saveVolume, activeColor: ChachaColors.yellow),
                    ),
                    const Icon(Icons.volume_up_rounded, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
