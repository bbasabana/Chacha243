import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/medals.dart';
import '../game/achievements.dart';
import '../game/play_games.dart';
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
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    // Hors connexion, on redemande tout seul : dès que le réseau revient, la vraie place s'affiche.
    _retry = Timer.periodic(const Duration(seconds: 12), (_) async {
      final s = await _standing;
      if (!mounted || (s != null && !s.stale)) return;
      setState(() => _standing = Telemetry.standing());
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

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
                      if (s == null || s.total == 0) return _offline();
                      return Column(
                        children: [
                          if (s.stale) _banner(),
                          Expanded(child: _content(s)),
                        ],
                      );
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

  /// Hors connexion : un bandeau doux, les données gardées sur le téléphone, et une nouvelle demande toute seule.
  Widget _banner() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Glass(
      radius: 14,
      tint: const Color(0x55F7D618),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pas de connexion : voici ta dernière place connue. Elle se met à jour toute seule dès que tu es en ligne.',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  /// Jamais classé en ligne et pas de connexion : on montre au moins ce que le téléphone sait de ses vols.
  Widget _offline() {
    final list = flights.value;
    final best = list.isEmpty ? null : list.map((f) => f.year).reduce(math.max);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Glass(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: ChachaColors.yellow, size: 34),
              const SizedBox(height: 8),
              const Text(
                'Pas de connexion',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                best == null
                    ? 'Vole une première fois, puis connecte-toi à Internet : ta place dans le classement apparaîtra toute seule.'
                    : 'Ton meilleur vol : ${best.floor()} · ${list.length} vol${list.length > 1 ? 's' : ''}.\n'
                          'Ta place dans le classement apparaîtra toute seule dès que tu seras en ligne.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.4),
              ),
            ],
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
        const SizedBox(height: 16),
        const AchievementsPanel(),
      ],
    );
  }
}

/// Les succès du pilote : gagnés en couleur, les autres en gris avec où il en est.
/// Avec Play Jeux, un bouton ouvre ses succès Google (ceux que ses amis voient).
class AchievementsPanel extends StatelessWidget {
  const AchievementsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Achievements.earned, Achievements.progress, PlayGames.player]),
      builder: (_, _) {
        final got = Achievements.earned.value;
        final points = got.fold(0, (n, a) => n + a.points);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'MES SUCCÈS · ${got.length}/${Achievement.values.length} · $points/1000 PTS',
                  style: const TextStyle(
                    color: ChachaColors.yellow,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                if (PlayGames.player.value != null)
                  GlassButton(
                    onTap: PlayGames.showAchievements,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    radius: 14,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_esports_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Voir dans Play Jeux', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final a in Achievement.values) _tile(a, got.contains(a))],
            ),
          ],
        );
      },
    );
  }

  Widget _tile(Achievement a, bool won) {
    final done = Achievements.progress.value[a] ?? 0;
    return SizedBox(
      width: 214,
      child: Glass(
        radius: 16,
        tint: won ? a.color.withValues(alpha: 0.22) : ChachaColors.glassFill,
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: won
                    ? RadialGradient(colors: [Color.lerp(a.color, Colors.white, 0.35)!, a.color])
                    : null,
                color: won ? null : Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: won ? Colors.white.withValues(alpha: 0.7) : Colors.white24, width: 1.5),
              ),
              child: Icon(won ? a.icon : Icons.lock_rounded, color: won ? ChachaColors.night : Colors.white38, size: 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: won ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    won
                        ? '+${a.points} pts ✓'
                        : a.goal > 1
                        ? '$done/${a.goal} · ${a.how}'
                        : a.how,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: won ? 0.85 : 0.6), fontSize: 11, height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
