import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/chacha_game.dart';
import '../game/duel.dart';
import '../game/telemetry.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';
import 'soft_dialog.dart';

const _dots = [Color(0xFFFFD34D), Color(0xFF7CF0A6), Color(0xFF6CC4FF), Color(0xFFFF9A9A)];

/// Ce qui s'ajoute à l'écran pendant un duel : une fine barre en haut qui montre où en sont les amis,
/// un panneau qui s'ouvre d'un toucher (sans pauser le vol), et l'écran de fin.
class DuelOverlay extends StatefulWidget {
  const DuelOverlay({super.key, required this.net, required this.game, required this.pauseLeft, required this.onQuit});

  final DuelNet net;
  final ChachaGame game;

  /// Les secondes de pause qui restent (null quand le vol n'est pas en pause).
  final ValueNotifier<int?> pauseLeft;
  final VoidCallback onQuit;

  @override
  State<DuelOverlay> createState() => _DuelOverlayState();
}

class _DuelOverlayState extends State<DuelOverlay> {
  bool _open = false, _sent = false, _frozen = false;
  String? _toast;
  Timer? _toastTimer, _watch;
  final _states = <String, Pilot>{};
  int _lastReport = 0;

  DuelNet get net => widget.net;
  ChachaGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    game.hud.addListener(_onHud);
    net.addListener(_onNet);
    // Même sans nouvelle image du jeu, l'état part une fois par seconde.
    _watch = Timer.periodic(const Duration(seconds: 1), (_) => _onHud(force: true));
    for (final p in net.players) {
      _states[p.id] = p.state;
    }
  }

  @override
  void dispose() {
    game.hud.removeListener(_onHud);
    net.removeListener(_onNet);
    _toastTimer?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  /// Ce que je suis en train de vivre, d'après le jeu.
  Pilot _mine() {
    final h = game.hud.value;
    if (h == null) return Pilot.flying;
    final t = net.rules.target;
    if (h.phase == FlightPhase.finished || game.homecoming.value) return Pilot.arrived;
    if (t < 2027 && h.year >= t && h.phase != FlightPhase.crashed) return Pilot.arrived;
    if (h.phase == FlightPhase.crashed && game.crashShown) return Pilot.crashed;
    if (game.stranded) return Pilot.crashed;
    return Pilot.flying;
  }

  void _onHud({bool force = false}) {
    final h = game.hud.value;
    if (h == null || net.me.out || net.outcome != null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final st = _mine();
    if (!force && st == Pilot.flying && now - _lastReport < 500) return;
    _lastReport = now;
    net.report(year: h.year, lives: h.lives, state: st);
  }

  void _onNet() {
    for (final p in net.players) {
      final before = _states[p.id];
      _states[p.id] = p.state;
      if (before != null && before != p.state && p.id != net.myId) {
        final what = switch (p.state) {
          Pilot.crashed => 'a échoué',
          Pilot.arrived => 'est arrivé',
          Pilot.stopped => 's\'est arrêté',
          Pilot.won => 'termine : il gagne',
          Pilot.lost => 'a perdu la connexion',
          Pilot.flying => null,
        };
        if (what != null) _say('${p.name} $what');
      }
    }
    // Sorti du duel ou duel fini : mon avion s'arrête, on regarde les autres.
    if ((net.me.out || net.outcome != null) && !_frozen) {
      _frozen = true;
      game.paused = true;
      HapticFeedback.mediumImpact();
    }
    if (net.outcome != null && !_sent) {
      _sent = true;
      Telemetry.sendDuel({'kind': 'result', ...net.result()});
    }
    if (mounted) setState(() {});
  }

  void _say(String t) {
    _toastTimer?.cancel();
    setState(() => _toast = t);
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  double _pct(DuelPlayer p) {
    final span = net.rules.target - net.rules.start;
    return ((p.year - net.rules.start) / span).clamp(0.0, 1.0);
  }

  Future<void> _stop() async {
    final alone = !net.players.any((p) => p.id != net.myId && p.state == Pilot.flying);
    final course = net.rules.mode == DuelMode.course;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => SoftDialog(
        title: alone && course ? 'Terminer et gagner ?' : 'T\'arrêter ?',
        actions: [
          SoftButton('Non', quiet: true, onTap: () => Navigator.pop(context, false)),
          SoftButton(alone && course ? 'Je gagne' : 'Je m\'arrête', onTap: () => Navigator.pop(context, true)),
        ],
        children: [
          Text(
            alone && course
                ? 'Tous les autres sont sortis : tu gagnes le duel maintenant.'
                : net.rules.mode == DuelMode.equipe
                ? 'En équipe, si tu t\'arrêtes, le duel est perdu pour tout le monde.'
                : 'Tu sors du duel : les autres continuent sans toi.',
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    net.report(
      year: game.hud.value?.year ?? net.me.year,
      lives: game.hud.value?.lives ?? 0,
      state: alone && course ? Pilot.won : Pilot.stopped,
    );
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final over = net.me.out || net.outcome != null;
    return Stack(
      children: [
        if (!over) _bar(),
        ValueListenableBuilder<int?>(
          valueListenable: widget.pauseLeft,
          builder: (_, left, _) => left == null || over
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 54),
                    child: Text(
                      'Pause · le duel continue ! $left s',
                      style: const TextStyle(
                        color: ChachaColors.yellow,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
        ),
        if (over) _end(),
      ],
    );
  }

  Widget _bar() {
    final ps = net.players;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _open = !_open),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: SizedBox(
                      height: 22,
                      child: LayoutBuilder(
                        builder: (_, c) => Stack(
                          alignment: Alignment.centerLeft,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.white24, width: 0.5),
                              ),
                            ),
                            for (var i = 0; i < ps.length; i++)
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOut,
                                left: (c.maxWidth - 14) * _pct(ps[i]),
                                child: _dot(ps[i], i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_toast != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xCC400008), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _toast!,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (_open) _panel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(DuelPlayer p, int i) {
    final me = p.id == net.myId;
    final gone = p.state == Pilot.crashed || p.state == Pilot.lost;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gone ? Colors.grey : _dots[i % _dots.length],
        border: Border.all(color: me ? Colors.white : Colors.black54, width: me ? 2 : 1),
      ),
      child: gone ? const Icon(Icons.close_rounded, size: 10, color: Colors.black87) : null,
    );
  }

  Widget _panel() {
    final ps = net.players;
    final myOut = net.me.out;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Glass(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${net.rules.mode == DuelMode.course ? 'Course' : 'Équipe'} · ${net.rules.start} → ${net.rules.target}',
              style: const TextStyle(color: ChachaColors.yellow, fontSize: 11, fontWeight: FontWeight.w900),
            ),
            for (var i = 0; i < ps.length; i++) _line(ps[i], i),
            if (!myOut)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _stop,
                  child: Text(
                    net.rules.mode == DuelMode.course && !ps.any((p) => p.id != net.myId && p.state == Pilot.flying)
                        ? 'Terminer · je gagne'
                        : 'Je m\'arrête',
                    style: const TextStyle(color: Color(0xFFFF9A9A), fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _stateText(Pilot s) => switch (s) {
    Pilot.flying => 'en vol',
    Pilot.crashed => 'échoué',
    Pilot.arrived => 'arrivé',
    Pilot.stopped => 'arrêté',
    Pilot.won => 'gagne',
    Pilot.lost => 'déconnecté',
  };

  Widget _line(DuelPlayer p, int i) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      children: [
        _dot(p, i),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${p.name}${p.id == net.myId ? ' (toi)' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${p.year.floor()} · ${(_pct(p) * 100).round()} % · ${p.lives}♥ · ${_stateText(p.state)}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
        ),
      ],
    ),
  );

  String _title() {
    final o = net.outcome;
    if (o == null) {
      return switch (net.me.state) {
        Pilot.crashed => 'Ton avion est tombé',
        Pilot.stopped => 'Tu t\'es arrêté',
        Pilot.arrived => 'Tu es arrivé !',
        Pilot.won => 'Tu as gagné !',
        _ => 'Tu es sorti du duel',
      };
    }
    final names = {for (final p in net.players) p.id: p.name};
    switch (o.end) {
      case DuelEnd.win:
        if (net.rules.mode == DuelMode.equipe) return 'Toute l\'équipe est arrivée !';
        return o.winners.contains(net.myId) ? 'Tu as gagné !' : '${names[o.winners.first] ?? 'Un pilote'} gagne';
      case DuelEnd.draw:
        return 'Égalité';
      case DuelEnd.teamFail:
        return 'Équipe : le duel est perdu';
      case DuelEnd.voided:
        return 'Connexion perdue : duel interrompu';
    }
  }

  Widget _end() {
    final ps = [...net.players]..sort((a, b) => b.year.compareTo(a.year));
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xAA000814),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Glass(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    if (net.outcome == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Les autres continuent : tu suis leur vol.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < ps.length; i++) _line(ps[i], net.players.indexOf(ps[i])),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SoftButton('Quitter le duel', onTap: widget.onQuit),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
