import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/achievements.dart';
import '../game/chacha_game.dart';
import '../game/duel.dart';
import '../game/telemetry.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';
import 'soft_dialog.dart';

/// Moi en or, toujours ; les adversaires en bleu, rouge et vert, dans l'ordre de la salle.
const _gold = Color(0xFFFFD34D);
const _rivals = [Color(0xFF6CC4FF), Color(0xFFFF7A7A), Color(0xFF7CF0A6)];

/// Ce qui s'ajoute à l'écran pendant un duel : une fine barre en haut qui montre où en sont les amis,
/// un panneau qui s'ouvre d'un toucher (sans pauser le vol), et l'écran de fin.
class DuelOverlay extends StatefulWidget {
  const DuelOverlay({
    super.key,
    required this.net,
    required this.game,
    required this.pauseLeft,
    required this.onQuit,
    this.onRematch,
  });

  final DuelNet net;
  final ChachaGame game;

  /// Les secondes de pause qui restent (null quand le vol n'est pas en pause).
  final ValueNotifier<int?> pauseLeft;
  final VoidCallback onQuit;

  /// Le duel est fini : on rejoue avec les mêmes amis et les mêmes règles.
  final VoidCallback? onRematch;

  @override
  State<DuelOverlay> createState() => _DuelOverlayState();
}

class _DuelOverlayState extends State<DuelOverlay> {
  bool _open = false, _sent = false, _frozen = false;
  String? _toast;
  Timer? _toastTimer, _watch;
  final _states = <String, Pilot>{};
  int _lastReport = 0;

  /// Celui qui mène la course, et celui qui vient de passer devant (sa pastille grossit un instant).
  String? _leader, _pulse;
  Timer? _pulseTimer;

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
    _pulseTimer?.cancel();
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
    _watchLead();
    // Sorti du duel ou duel fini : mon avion s'arrête, on regarde les autres.
    if ((net.me.out || net.outcome != null) && !_frozen) {
      _frozen = true;
      game.paused = true;
      HapticFeedback.mediumImpact();
    }
    if (net.outcome != null && !_sent) {
      _sent = true;
      Telemetry.sendDuel({'kind': 'result', ...net.result()});
      if (net.outcome!.winners.contains(net.myId)) Achievements.step(Achievement.duel);
    }
    if (mounted) setState(() {});
  }

  /// Quand un pilote en vol passe devant, tout le monde le voit : un message, et sa pastille qui saute.
  void _watchLead() {
    final flying = [
      for (final p in net.players)
        if (p.state == Pilot.flying) p,
    ];
    if (flying.length < 2) return;
    flying.sort((a, b) => b.year.compareTo(a.year));
    // Une petite avance ne compte pas : on ne clignote pas pour une semaine d'écart.
    if (flying[0].year - flying[1].year < 0.05) return;
    final lead = flying[0].id;
    if (lead == _leader) return;
    final had = _leader != null;
    _leader = lead;
    if (!had) return;
    _pulse = lead;
    _pulseTimer?.cancel();
    _pulseTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _pulse = null);
    });
    HapticFeedback.selectionClick();
    _say(lead == net.myId ? 'Tu passes devant !' : '${flying[0].name} passe devant toi !');
  }

  /// La couleur d'un pilote : la mienne est l'or, celle des autres reste la même pendant tout le duel.
  Color _color(DuelPlayer p) {
    if (p.id == net.myId) return _gold;
    final others = [
      for (final o in net.players)
        if (o.id != net.myId) o.id,
    ];
    return _rivals[math.max(0, others.indexOf(p.id)) % _rivals.length];
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
                    padding: const EdgeInsets.only(top: 66),
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
    final me = net.me;
    final rivals = [
      for (final p in ps)
        if (p.id != net.myId) p,
    ];
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _open = !_open),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xB3061430),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 0.7),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _chip(me, rivals),
                            for (final r in rivals) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              _chip(r, rivals),
                            ],
                            const SizedBox(width: 4),
                            Icon(
                              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: Colors.white60,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: 300,
                          height: 14,
                          child: LayoutBuilder(
                            builder: (_, c) => Stack(
                              alignment: Alignment.centerLeft,
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                // Les autres d'abord : ma pastille passe par-dessus quand on est côte à côte.
                                for (final p in [...rivals, me])
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOut,
                                    left: (c.maxWidth - 14) * _pct(p),
                                    child: _dot(p),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_toast != null)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
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

  /// Un pilote en haut de l'écran : son nom à sa couleur, l'année où il est, et pour moi « TOI » et mon écart.
  Widget _chip(DuelPlayer p, List<DuelPlayer> rivals) {
    final mine = p.id == net.myId;
    final color = _color(p);
    final gone = p.state == Pilot.crashed || p.state == Pilot.lost;
    final leads = p.id == _leader && p.state == Pilot.flying;
    String? gap;
    if (mine && !net.me.out) {
      final flying = [
        for (final r in rivals)
          if (r.state == Pilot.flying) r.year,
      ];
      if (flying.isNotEmpty) {
        final d = p.year - flying.reduce(math.max);
        if (d.abs() >= 0.1) {
          final n = d.abs().toStringAsFixed(1).replaceAll('.', ',');
          gap = '${d > 0 ? '+' : '−'}$n an${d.abs() >= 2 ? 's' : ''}';
        }
      }
    }
    return AnimatedScale(
      scale: _pulse == p.id ? 1.14 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 2, 8, 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: mine ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gone ? Colors.white24 : color, width: mine ? 1.6 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine)
              Container(
                margin: const EdgeInsets.only(right: 5),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                child: const Text(
                  'TOI',
                  style: TextStyle(color: Color(0xFF2A1600), fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.flight_rounded, size: 12, color: gone ? Colors.white38 : color),
              ),
            if (leads)
              const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Icon(Icons.emoji_events_rounded, size: 12, color: Color(0xFFFFD34D)),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 82),
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: gone ? Colors.white38 : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  decoration: gone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              gone ? _stateText(p.state) : '${p.year.floor()}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700),
            ),
            if (gap != null) ...[
              const SizedBox(width: 4),
              Text(
                gap,
                style: TextStyle(
                  color: gap.startsWith('+') ? const Color(0xFF7CF0A6) : const Color(0xFFFF9A9A),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dot(DuelPlayer p) {
    final me = p.id == net.myId;
    final gone = p.state == Pilot.crashed || p.state == Pilot.lost;
    final size = me ? 14.0 : 12.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gone ? Colors.grey : _color(p),
        border: Border.all(color: me ? Colors.white : Colors.black54, width: me ? 2 : 1),
        boxShadow: [if (me) BoxShadow(color: _gold.withValues(alpha: 0.6), blurRadius: 6)],
      ),
      child: gone
          ? const Icon(Icons.close_rounded, size: 9, color: Colors.black87)
          : Text(
              p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
              style: TextStyle(color: const Color(0xFF0B1B3A), fontSize: me ? 7.5 : 7, fontWeight: FontWeight.w900),
            ),
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
            for (final p in ps) _line(p),
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

  Widget _line(DuelPlayer p) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      children: [
        _dot(p),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${p.name}${p.id == net.myId ? ' (toi)' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _color(p), fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '${p.year.floor()} · ${(_pct(p) * 100).round()} % · ${p.lives}♥ · ${_stateText(p.state)}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
        ),
      ],
    ),
  );

  String _hostName() => net.players.firstOrNull?.name ?? 'l\'organisateur';

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
                    for (final p in ps) _line(p),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SoftButton(
                          'Quitter le duel',
                          quiet: net.outcome != null && widget.onRematch != null,
                          onTap: widget.onQuit,
                        ),
                        if (net.outcome != null && widget.onRematch != null) ...[
                          const SizedBox(width: 8),
                          SoftButton('Revanche', onTap: widget.onRematch),
                        ],
                      ],
                    ),
                    if (net.outcome != null && widget.onRematch != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          net.isHost
                              ? 'Revanche : ta salle se rouvre, tes amis y entrent d\'eux-mêmes.'
                              : 'Revanche : tu entres dès que ${_hostName()} rouvre sa salle.',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                        ),
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
