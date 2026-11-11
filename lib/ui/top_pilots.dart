import 'dart:async';

import 'package:flutter/material.dart';

import '../game/app_update.dart';
import '../game/telemetry.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';
import 'soft_dialog.dart';

/// At launch, the five best pilots pass one after the other (first, second, third…), then a last word
/// invites the pilot to beat them. Then the band goes away by itself.
class TopPilotsTicker extends StatefulWidget {
  const TopPilotsTicker(this.top, {super.key, required this.onDone});

  final List<TopPilot> top;
  final VoidCallback onDone;

  static const each = Duration(milliseconds: 3600);

  @override
  State<TopPilotsTicker> createState() => _TopPilotsTickerState();
}

class _TopPilotsTickerState extends State<TopPilotsTicker> {
  int _at = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(TopPilotsTicker.each, (_) {
      if (_at >= widget.top.length) {
        _timer?.cancel();
        return widget.onDone();
      }
      setState(() => _at++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Un toucher passe au suivant.
      onTap: () => setState(() => _at = (_at + 1).clamp(0, widget.top.length)),
      child: SizedBox(
        width: 360,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 520),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -0.35), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: _at < widget.top.length ? _pilot(widget.top[_at]) : _challenge(widget.top.first),
        ),
      ),
    );
  }

  static Color placeColor(int place) => switch (place) {
    1 => const Color(0xFFF2C230),
    2 => const Color(0xFFC9D3E6),
    3 => const Color(0xFFC98A4B),
    _ => ChachaColors.sky,
  };

  static String _points(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');

  Widget _pilot(TopPilot p) {
    final c = placeColor(p.place);
    return Glass(
      key: ValueKey(p.place),
      radius: 18,
      tint: const Color(0x66001A40),
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: ChachaColors.night,
                  backgroundImage: p.photo == null ? null : MemoryImage(p.photo!),
                  child: p.photo == null
                      ? Text(
                          p.name.characters.first.toUpperCase(),
                          style: TextStyle(color: c, fontSize: 19, fontWeight: FontWeight.w900),
                        )
                      : null,
                ),
              ),
              Positioned(
                right: -4,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ChachaColors.night, width: 1.5),
                  ),
                  child: Text(
                    p.place == 1 ? '1er' : '${p.place}e',
                    style: const TextStyle(color: ChachaColors.night, fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.place == 1 ? '🏆 LE MEILLEUR PILOTE' : 'LES MEILLEURS PILOTES · ${p.place}/${widget.top.length}',
                  style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
                const SizedBox(height: 1),
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                Text(
                  p.arrived
                      ? 'Arrivé à Kinshasa en 2027 ✓ · ${_points(p.score)} pts'
                      : "Jusqu'en ${p.year} · ${_points(p.score)} pts",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _challenge(TopPilot first) {
    return Glass(
      key: const ValueKey('défi'),
      radius: 18,
      tint: const Color(0x66CE1021),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: [
          const Icon(Icons.flight_takeoff_rounded, color: ChachaColors.yellow, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'À toi de les battre !',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                Text(
                  first.arrived
                      ? 'Arrive en 2027 avec plus de ${_points(first.score)} pts'
                      : "Vole plus loin que ${first.year} et prends la 1re place",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A new version waits on the Play Store: one gentle window, and Google installs it without leaving the game.
Future<void> showUpdateDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => SoftDialog(
    title: 'Nouvelle version de Chacha243',
    actions: [
      SoftButton('Plus tard', quiet: true, onTap: () => Navigator.of(context).pop()),
      SoftButton(
        'Mettre à jour',
        onTap: () {
          Navigator.of(context).pop();
          AppUpdate.start();
        },
      ),
    ],
    children: [
      const Icon(Icons.system_update_rounded, color: ChachaColors.yellow, size: 44),
      const SizedBox(height: 10),
      Text(
        "De nouveaux moments d'histoire, de nouveaux succès et des corrections t'attendent. "
        'La mise à jour se fait ici, en une minute, et ton vol reste sauvegardé.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14.5, height: 1.4),
      ),
    ],
  ),
);
