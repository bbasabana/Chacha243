import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../data/aircraft_types.dart';
import '../game/duel.dart';
import '../game/music.dart';
import '../game/telemetry.dart';
import '../theme/chacha_colors.dart';
import 'game_screen.dart';
import 'glass.dart';
import 'guide.dart';
import 'soft_dialog.dart';

const _guideKey = 'chacha243.guide';
const _termsKey = 'chacha243.duelTerms';

/// Marque le guide du pilote comme lu : le duel ne s'ouvre qu'après.
Future<void> markGuideRead() async {
  try {
    (await SharedPreferences.getInstance()).setBool(_guideKey, true);
  } catch (_) {}
}

/// Le duel entre amis : le guide lu, les conditions acceptées, puis on crée une salle ou on rejoint celle d'un ami.
class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

enum _Step { loading, guide, terms, menu, create, join, lobby, countdown }

class _DuelScreenState extends State<DuelScreen> {
  _Step _step = _Step.loading;
  bool _agreed = false, _busy = false, _wifi = true;
  String? _error;
  DuelNet? _net;
  final _finder = DuelFinder();
  final _stake = TextEditingController(), _addr = TextEditingController(), _code = TextEditingController();
  DuelMode _mode = DuelMode.course;
  int _start = 1960, _target = 2027, _count = 3;
  Timer? _tick;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gone = true;
    _tick?.cancel();
    _finder.dispose();
    _stake.dispose();
    _addr.dispose();
    _code.dispose();
    // Une salle laissée sans duel lancé se ferme ; un duel lancé continue dans l'écran de vol.
    if (_net != null && !_net!.started) _net!.close();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final read = p.getBool(_guideKey) ?? false;
    final terms = p.getInt(_termsKey) ?? 0;
    _wifi = (await wifiAddresses()).isNotEmpty;
    if (!mounted) return;
    setState(() => _step = !read ? _Step.guide : (terms != duelTerms ? _Step.terms : _Step.menu));
  }

  Future<void> _openGuide() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (c) => Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [ChachaColors.skyDeep, ChachaColors.night]),
            ),
            child: GuideView(onClose: () => Navigator.of(c).pop()),
          ),
        ),
      ),
    );
    await markGuideRead();
    _load();
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      (await SharedPreferences.getInstance()).setInt(_termsKey, duelTerms);
    } catch (_) {}
    // Le tableau de bord garde que ce pilote a accepté, avec la version des conditions.
    Telemetry.sendDuel({'kind': 'terms', 'v': duelTerms});
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.menu;
    });
  }

  // ------------------------------------------------------------- créer

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = await Telemetry.playerId();
    final net = await DuelNet.host(
      myId: id,
      myName: pilotName.value ?? 'Pilote',
      rules: DuelRules(mode: _mode, start: _start, target: _target, stake: _stake.text.trim()),
    );
    if (!mounted) return net?.close();
    if (net == null) {
      return setState(() {
        _busy = false;
        _error = 'Impossible d\'ouvrir la salle : vérifie le Wi-Fi.';
      });
    }
    _enter(net, host: true);
  }

  void _enter(DuelNet net, {required bool host}) {
    _net = net;
    net.addListener(_onNet);
    // Le tableau de bord garde que ce pilote est entré dans ce duel.
    Telemetry.sendDuel({
      'kind': 'join',
      'duel': net.duelId,
      'host': host,
      'mode': net.rules.mode.index,
      'start': net.rules.start,
      'target': net.rules.target,
      'v': duelTerms,
    });
    setState(() {
      _busy = false;
      _step = _Step.lobby;
    });
  }

  void _onNet() {
    final net = _net;
    if (net == null || _gone) return;
    if (net.started && _step == _Step.lobby) {
      _count = 3;
      setState(() => _step = _Step.countdown);
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        if (_count <= 1) {
          t.cancel();
          net.removeListener(_onNet);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => GameScreen(type: aircraftById('dc6'), duel: net),
            ),
          );
          return;
        }
        setState(() => _count--);
      });
      Music.instance.stop();
      return;
    }
    // L'organisateur est parti avant le départ.
    if (!net.isHost && !net.started && net.outcome != null) {
      net.close();
      setState(() {
        _net = null;
        _error = 'L\'organisateur a fermé la salle.';
        _step = _Step.menu;
      });
      return;
    }
    setState(() {});
  }

  // ------------------------------------------------------------ rejoindre

  Future<void> _openJoin() async {
    setState(() {
      _step = _Step.join;
      _error = null;
    });
    await _finder.start();
    if (mounted) setState(() {});
  }

  /// L'invitation d'un ami : on voit les règles, on accepte ou on refuse.
  Future<void> _invitation(DuelRoom r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => SoftDialog(
        title: '${r.host} t\'invite',
        actions: [
          SoftButton('Refuser', quiet: true, onTap: () => Navigator.pop(context, false)),
          SoftButton('Accepter', onTap: () => Navigator.pop(context, true)),
        ],
        children: [
          Text(_rulesText(r.rules), style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
          if (r.rules.stake.isNotEmpty && !appStoreRules) ...[
            const SizedBox(height: 8),
            Text(
              'Enjeu écrit : « ${r.rules.stake} »',
              style: const TextStyle(color: ChachaColors.yellow, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Cet enjeu reste entre vous : le jeu ne le gère pas.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ],
      ),
    );
    if (ok == true) _joinRoom(r.address, r.port, r.code);
  }

  Future<void> _joinRoom(String address, int port, String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = await Telemetry.playerId();
    final net = await DuelNet.join(
      myId: id,
      myName: pilotName.value ?? 'Pilote',
      address: address,
      port: port,
      code: code,
    );
    if (!mounted) return net?.close();
    if (net == null) {
      return setState(() {
        _busy = false;
        _error = 'Impossible d\'entrer dans la salle : même Wi-Fi, bon code ?';
      });
    }
    _finder.stop();
    _enter(net, host: false);
  }

  void _manual() {
    final parts = _addr.text.trim().split(':');
    final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (parts.length != 2 || port == null || _code.text.trim().length != 4) {
      return setState(
        () =>
            _error = 'Écris l\'adresse comme sur l\'écran de l\'ami (ex. 192.168.1.5:40123) et son code à 4 chiffres.',
      );
    }
    _joinRoom(parts[0], port, _code.text.trim());
  }

  String _rulesText(DuelRules r) =>
      '${r.mode == DuelMode.course ? 'Course : le premier arrivé gagne, celui qui échoue sort.' : 'Équipe : tous doivent arriver, un seul échec et c\'est perdu pour tous.'}\n'
      'De ${r.start} à ${r.target == 2027 ? 'Kinshasa, le 30 juin 2027' : r.target}.\n'
      'Mêmes vies, même carburant, même départ pour tous.';

  // ------------------------------------------------------------------ écran

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GlassButton(
                      onTap: _back,
                      padding: const EdgeInsets.all(10),
                      radius: 16,
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Duel entre amis',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SingleChildScrollView(child: _body()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _back() {
    switch (_step) {
      case _Step.create || _Step.join:
        _finder.stop();
        setState(() {
          _step = _Step.menu;
          _error = null;
        });
      case _Step.lobby:
        _net?.close();
        _net = null;
        setState(() => _step = _Step.menu);
      case _Step.countdown:
        break;
      default:
        Navigator.of(context).pop();
    }
  }

  Widget _body() => switch (_step) {
    _Step.loading => const Center(child: CircularProgressIndicator()),
    _Step.guide => _guide(),
    _Step.terms => _terms(),
    _Step.menu => _menu(),
    _Step.create => _create_(),
    _Step.join => _join(),
    _Step.lobby => _lobby(),
    _Step.countdown => _countdown(),
  };

  Widget _text(String t, {double size = 14.5, Color? color, FontWeight? weight}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        color: color ?? Colors.white.withValues(alpha: 0.92),
        fontSize: size,
        height: 1.42,
        fontWeight: weight,
      ),
    ),
  );

  Widget _errorLine() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 13)),
        );

  Widget _guide() => Glass(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Lis d\'abord le guide du pilote', size: 18, weight: FontWeight.w900),
        _text(
          'Avant un duel, chaque pilote doit connaître les symboles du ciel, les boutons et les monnaies. Ça prend deux minutes.',
        ),
        const SizedBox(height: 6),
        SoftButton('Ouvrir le guide', onTap: _openGuide),
      ],
    ),
  );

  Widget _terms() => Glass(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Les règles du duel', size: 18, weight: FontWeight.w900),
        _text('• Il faut être sur le même Wi-Fi que ton ami. Entre deux et quatre pilotes.'),
        _text('• On peut refuser une invitation. Rien ne t\'oblige à jouer.'),
        _text('• Tout le monde part du même point, avec les mêmes vies, le même carburant et le même argent.'),
        _text(
          '• Course : le premier arrivé gagne. Si tu échoues, tu sors ; les autres continuent. Le dernier en vol peut s\'arrêter et gagner.',
        ),
        _text('• Équipe : tous doivent arriver. Dès qu\'un seul échoue ou s\'arrête, le duel est perdu pour tous.'),
        _text(
          '• Si tu mets le jeu en pause, le duel continue sans toi : tu perds du temps. Une minute de pause au total, puis le vol reprend.',
        ),
        if (!appStoreRules)
          _text(
            '• L\'enjeu (un repas, un gage, de l\'argent) est écrit par vous et reste entre vous : Chacha243 ne le gère pas, ne le garde pas et n\'en est pas responsable.',
          ),
        _text(
          '• Tricher (modifier le jeu, l\'horloge ou les messages) est interdit. Les résultats de chaque pilote sont comparés, et un duel douteux est signalé.',
        ),
        _text(
          '• Chacha243 garde seulement que tu as accepté ces règles, et le résultat final du duel (les pilotes, l\'année atteinte, le gagnant). Rien d\'autre : ni l\'historique, ni l\'écran de la partie.',
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => _agreed = !_agreed),
          child: Row(
            children: [
              Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
              const Expanded(
                child: Text(
                  'J\'ai lu les règles et je les accepte.',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SoftButton('Accepter', onTap: _agreed && !_busy ? _accept : null),
      ],
    ),
  );

  Widget _menu() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!_wifi)
        Glass(
          tint: const Color(0x55400008),
          padding: const EdgeInsets.all(12),
          child: _text('Pas de Wi-Fi détecté. Connecte-toi au même Wi-Fi que ton ami pour jouer ensemble.'),
        ),
      _bigButton(Icons.add_circle_outline_rounded, 'Créer un duel', 'Tu choisis le défi, tes amis te rejoignent', () {
        setState(() {
          _step = _Step.create;
          _error = null;
        });
      }),
      const SizedBox(height: 10),
      _bigButton(
        Icons.wifi_find_rounded,
        'Rejoindre un ami',
        'Les salles ouvertes sur ton Wi-Fi apparaissent',
        _openJoin,
      ),
      _errorLine(),
    ],
  );

  Widget _bigButton(IconData icon, String title, String sub, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Glass(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: ChachaColors.yellow, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      ),
    ),
  );

  Widget _create_() {
    final targets = [
      for (final t in duelTargets)
        if (t > _start) t,
    ];
    if (!targets.contains(_target)) _target = targets.last;
    return Glass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text('Le défi', size: 17, weight: FontWeight.w900),
          SegmentedButton<DuelMode>(
            segments: const [
              ButtonSegment(value: DuelMode.course, label: Text('Course'), icon: Icon(Icons.flag_rounded)),
              ButtonSegment(value: DuelMode.equipe, label: Text('Équipe'), icon: Icon(Icons.groups_rounded)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 6),
          _text(
            _mode == DuelMode.course
                ? 'Le premier arrivé gagne. Celui qui échoue sort, les autres continuent.'
                : 'Tous doivent arriver. Un seul échec, et c\'est perdu pour tous.',
            size: 12.5,
          ),
          Row(
            children: [
              Expanded(child: _pick('Départ', _start, duelStarts, (v) => setState(() => _start = v))),
              const SizedBox(width: 12),
              Expanded(child: _pick('Arrivée', _target, targets, (v) => setState(() => _target = v))),
            ],
          ),
          const SizedBox(height: 10),
          if (!appStoreRules) ...[
            TextField(
              controller: _stake,
              maxLength: 80,
              style: const TextStyle(color: Colors.white),
              decoration: softField('Enjeu écrit (facultatif) : un repas, un gage…'),
            ),
            _text('L\'enjeu reste entre vous : le jeu ne le gère pas.', size: 12, color: Colors.white60),
          ],
          SoftButton(_busy ? 'Ouverture…' : 'Ouvrir la salle', onTap: _busy ? null : _create),
          _errorLine(),
        ],
      ),
    );
  }

  Widget _pick(String label, int value, List<int> items, ValueChanged<int> on) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      DropdownButton<int>(
        value: value,
        isExpanded: true,
        dropdownColor: ChachaColors.night,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        items: [for (final y in items) DropdownMenuItem(value: y, child: Text(y == 2027 ? '2027 · Kinshasa' : '$y'))],
        onChanged: (v) => v == null ? null : on(v),
      ),
    ],
  );

  Widget _join() => ListenableBuilder(
    listenable: _finder,
    builder: (_, _) {
      final rooms = _finder.rooms;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rooms.isEmpty)
            Glass(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: _text('Je cherche les salles ouvertes sur ce Wi-Fi…', size: 14)),
                ],
              ),
            ),
          for (final r in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: _busy ? null : () => _invitation(r),
                child: Glass(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.flight_rounded, color: ChachaColors.yellow),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.host,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            Text(
                              '${r.rules.mode == DuelMode.course ? 'Course' : 'Équipe'} · ${r.rules.start} → ${r.rules.target} · ${r.count}/$duelMaxPlayers',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Glass(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _text(
                  'Rien ne s\'affiche ? Certains Wi-Fi bloquent la recherche. Entre l\'adresse et le code écrits sur le téléphone de ton ami.',
                  size: 12.5,
                ),
                TextField(
                  controller: _addr,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: Colors.white),
                  decoration: softField('Adresse (192.168.1.5:40123)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: softField('Code à 4 chiffres').copyWith(counterText: ''),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SoftButton(_busy ? 'Connexion…' : 'Entrer', onTap: _busy ? null : _manual),
                ),
              ],
            ),
          ),
          _errorLine(),
        ],
      );
    },
  );

  Widget _lobby() {
    final net = _net!;
    return Glass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text(net.isHost ? 'Ta salle est ouverte' : 'Tu es dans la salle', size: 18, weight: FontWeight.w900),
          _text(_rulesText(net.rules), size: 13.5),
          if (net.rules.stake.isNotEmpty && !appStoreRules)
            _text('Enjeu écrit : « ${net.rules.stake} »', size: 13.5, color: ChachaColors.yellow),
          if (net.isHost)
            FutureBuilder(
              future: wifiAddresses(),
              builder: (_, snap) {
                final ip = snap.data?.firstOrNull?.address;
                final port = net.hostPort;
                return _text(
                  ip == null || port == null
                      ? 'Code : ${net.code}'
                      : 'Si un ami ne te voit pas : $ip:$port · code ${net.code}',
                  size: 12.5,
                  color: Colors.white70,
                );
              },
            ),
          const SizedBox(height: 4),
          for (final p in net.players)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF7CF0A6), size: 18),
                  const SizedBox(width: 4),
                  Text('accepté', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          if (net.isHost)
            SoftButton(
              net.players.length < 2 ? 'En attente d\'un ami…' : 'Lancer le duel',
              onTap: net.players.length < 2 ? null : net.launch,
            )
          else
            _text('L\'organisateur lance quand tout le monde est là.', size: 13),
        ],
      ),
    );
  }

  Widget _countdown() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          _text('Prépare-toi', size: 18, weight: FontWeight.w900),
          Text(
            '$_count',
            style: const TextStyle(color: ChachaColors.yellow, fontSize: 90, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}
