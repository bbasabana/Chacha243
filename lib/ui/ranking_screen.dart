import 'package:flutter/material.dart';

import '../data/medals.dart';
import '../game/telemetry.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';

/// Le classement du pilote : sa place, sa médaille, jusqu'où il a volé, son meilleur score.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<Standing?> _standing = Telemetry.standing();

  String _clock(int s) =>
      s >= 3600 ? '${s ~/ 3600} h ${(s % 3600 ~/ 60).toString().padLeft(2, '0')}' : '${s ~/ 60} min';

  String _score(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'Mon classement',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    GlassButton(
                      onTap: () => setState(() => _standing = Telemetry.standing()),
                      padding: const EdgeInsets.all(10),
                      radius: 16,
                      child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<Standing?>(
                    future: _standing,
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator(color: ChachaColors.yellow));
                      }
                      final s = snap.data;
                      if (s == null || s.total == 0) {
                        return Center(
                          child: Text(
                            'Vole une première fois, connecté à Internet, pour entrer dans le classement.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
                          ),
                        );
                      }
                      return _content(s);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Standing s) {
    final mine = medalFor(s.bestYear, s.wins);
    final next = nextMedal(s.bestYear, s.wins);
    Widget fact(String label, String value) => Expanded(
      child: Glass(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Glass(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 64, color: mine?.color ?? Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.rank}${s.rank == 1 ? 'er' : 'e'} sur ${s.total} pilote${s.total > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mine == null ? 'Pas encore de médaille' : 'Médaille ${mine.name}',
                      style: TextStyle(color: mine?.color ?? Colors.white70, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (next != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        next == medals.last
                            ? 'Diamant : arrive à Kinshasa le 30 juin 2027'
                            : '${next.name} : vole jusqu\'en ${next.from}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            fact('Plus loin', s.wins > 0 ? '2027 ✓' : '${s.bestYear.floor()}'),
            const SizedBox(width: 10),
            fact('Meilleur score', _score(s.bestScore)),
            const SizedBox(width: 10),
            fact('Vols', '${s.flights}'),
            const SizedBox(width: 10),
            fact('Temps de jeu', _clock(s.seconds)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'LES MÉDAILLES',
          style: const TextStyle(
            color: ChachaColors.yellow,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        for (final m in medals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: m.color),
                const SizedBox(width: 10),
                Text(
                  m.name,
                  style: TextStyle(color: m.color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 10),
                Text(
                  m == medals.last ? 'arriver en 2027' : 'voler jusqu\'en ${m.from}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
                if (m == mine) ...[const Spacer(), const Text('ta médaille ✓', style: TextStyle(color: Colors.white))],
              ],
            ),
          ),
      ],
    );
  }
}
