import 'package:flutter/material.dart';

import '../data/history_events.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';

/// Les dates à retenir, de 1960 à 2027 : une frise à relire après le vol, pour les élèves.
///
/// [caught] = les titres des médaillons attrapés pendant le vol, cochés dans la liste.
class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key, this.caught = const {}});

  final Set<String> caught;

  static const _finale = HistoryEvent(2027.5, EventKind.glory, '30 juin 2027', 'Tout le pays', '67 ans d\'indépendance',
      'Le vol s\'achève : le Congo fête ses 67 ans au son d\'« Indépendance Cha Cha ».');

  @override
  Widget build(BuildContext context) {
    final events = [...historyEvents, _finale];
    final decades = <int, List<HistoryEvent>>{};
    for (final e in events) {
      decades.putIfAbsent(e.year ~/ 10 * 10, () => []).add(e);
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ChachaColors.skyDeep, ChachaColors.night],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GlassButton(
                      onTap: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.all(10),
                      radius: 16,
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Les dates à retenir · 1960 – 2027',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    if (caught.isNotEmpty)
                      Text('${caught.length} médaillons attrapés',
                          style: const TextStyle(color: ChachaColors.yellow, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final MapEntry(key: decade, value: list) in decades.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 0, 8),
                          child: Text('Années $decade',
                              style: const TextStyle(
                                  color: ChachaColors.yellow, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                        ),
                        for (final e in list) _Row(event: e, caught: caught.contains(e.title)),
                      ],
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

class _Row extends StatelessWidget {
  const _Row({required this.event, required this.caught});

  final HistoryEvent event;
  final bool caught;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final (icon, color) = switch (e.kind) {
      EventKind.glory => (Icons.emoji_events_rounded, ChachaColors.yellow),
      EventKind.life => (Icons.star_rounded, ChachaColors.skyLight),
      EventKind.obstacle => (e.war ? Icons.warning_amber_rounded : Icons.thunderstorm_rounded, const Color(0xFFFF7A7A)),
      EventKind.memory => (Icons.local_florist_rounded, Colors.white),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(e.city, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
            ),
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(e.text, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                ],
              ),
            ),
            if (caught) const Icon(Icons.check_circle_rounded, color: Color(0xFF7CF0A6), size: 20),
          ],
        ),
      ),
    );
  }
}
