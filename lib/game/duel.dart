import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:bonsoir/bonsoir.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Le Duel : jusqu'à quatre pilotes sur le même Wi-Fi se lancent un défi.
///
/// Rien ne passe par un serveur pendant le duel : chaque téléphone joue sa propre partie et n'envoie aux autres
/// que quelques chiffres (année, vies, état), une fois par seconde, sur le réseau local. À la fin, chacun envoie
/// son résultat au tableau de bord : quelques centaines d'octets, et rien n'est gardé sur les téléphones.

/// Le port où l'organisateur annonce sa salle, sur le Wi-Fi.
const duelPort = 47243;

/// La version des conditions : elle change quand les règles changent, et chacun doit les accepter à nouveau.
const duelTerms = 1;

const duelMaxPlayers = 4;

/// Le temps de pause qu'un pilote a droit de prendre pendant tout un duel, en secondes.
const duelPauseBudget = 60;

/// Les années de départ et d'arrivée que l'organisateur peut choisir.
const duelStarts = <int>[1960, 1990, 2000, 2016, 2023];
const duelTargets = <int>[1970, 1990, 2000, 2016, 2023, 2027];

enum DuelMode {
  /// Le premier arrivé gagne ; celui qui échoue sort, les autres continuent.
  course,

  /// Tous doivent arriver : dès qu'un seul échoue ou s'arrête, c'est perdu pour tous.
  equipe,
}

/// Où en est un pilote. L'ordre ne change pas : l'index part sur le réseau.
enum Pilot { flying, crashed, arrived, stopped, won, lost }

/// Les règles d'un duel, choisies par l'organisateur.
class DuelRules {
  const DuelRules({this.mode = DuelMode.course, this.start = 1960, this.target = 2027, this.stake = ''});

  final DuelMode mode;
  final int start, target;

  /// Ce que les pilotes mettent en jeu, écrit à la main : le jeu ne le gère pas et ne le garde pas.
  final String stake;

  Map<String, Object?> toJson() => {'m': mode.index, 's': start, 'g': target, 'k': stake};

  /// Les règles reçues du réseau ; null si elles n'ont pas de sens.
  static DuelRules? fromJson(Object? j) {
    if (j is! Map) return null;
    final m = j['m'], s = j['s'], g = j['g'], k = j['k'];
    if (m is! int || m < 0 || m >= DuelMode.values.length || s is! int || g is! int) return null;
    if (s < 1960 || s > 2026 || g <= s || g > 2027) return null;
    return DuelRules(mode: DuelMode.values[m], start: s, target: g, stake: k is String ? _clean(k, 80) : '');
  }
}

/// Un texte venu du réseau : sans retour à la ligne, de longueur bornée.
String _clean(String s, int max) {
  final t = s.replaceAll(RegExp(r'[\u0000-\u001f]'), ' ').trim();
  return t.length > max ? t.substring(0, max) : t;
}

class DuelPlayer {
  DuelPlayer(this.id, this.name);

  final String id;
  String name;
  double year = 0;
  int lives = 3;
  int seconds = 0;
  int seq = 0;
  Pilot state = Pilot.flying;

  /// Le moment où l'organisateur a vu ce pilote arriver : il départage deux arrivées proches.
  int arrivedAt = 0;
  int lastSeen = 0;

  bool get out => state != Pilot.flying;

  List<Object> toWire() => [id, name, (year * 100).round(), lives, state.index, seconds];

  static DuelPlayer? fromWire(Object? w) {
    if (w is! List || w.length < 6) return null;
    final id = w[0], name = w[1], y = w[2], l = w[3], f = w[4], s = w[5];
    if (id is! String || name is! String || y is! int || l is! int || f is! int || s is! int) return null;
    if (f < 0 || f >= Pilot.values.length) return null;
    return DuelPlayer(id, _clean(name, 24))
      ..year = y / 100
      ..lives = l.clamp(0, 9)
      ..state = Pilot.values[f]
      ..seconds = s;
  }
}

/// Comment le duel s'est fini.
enum DuelEnd {
  /// Un gagnant (course), ou toute l'équipe à l'arrivée.
  win,

  /// Personne n'est arrivé et les meilleurs sont à égalité.
  draw,

  /// Équipe : l'un des pilotes a échoué ou s'est arrêté.
  teamFail,

  /// La connexion avec l'organisateur est perdue.
  voided,
}

class DuelOutcome {
  const DuelOutcome(this.end, this.winners);

  final DuelEnd end;
  final List<String> winners;

  Map<String, Object?> toJson() => {'e': end.index, 'w': winners};

  static DuelOutcome? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = j['e'], w = j['w'];
    if (e is! int || e < 0 || e >= DuelEnd.values.length || w is! List) return null;
    return DuelOutcome(DuelEnd.values[e], [
      for (final x in w)
        if (x is String) x,
    ]);
  }
}

/// Le verdict d'après les états des pilotes ; null tant que le duel continue.
DuelOutcome? judge(DuelRules rules, List<DuelPlayer> players) {
  if (players.length < 2) return null;
  final broken = players.where((p) => p.state == Pilot.crashed || p.state == Pilot.stopped || p.state == Pilot.lost);
  if (rules.mode == DuelMode.equipe) {
    if (broken.isNotEmpty) return const DuelOutcome(DuelEnd.teamFail, []);
    if (players.every((p) => p.state == Pilot.arrived)) {
      return DuelOutcome(DuelEnd.win, [for (final p in players) p.id]);
    }
    return null;
  }
  // Course : le dernier pilote en vol qui annonce sa victoire, ou le premier arrivé, gagne.
  final won = players.where((p) => p.state == Pilot.won).toList();
  if (won.isNotEmpty) return DuelOutcome(DuelEnd.win, [won.first.id]);
  final arrived = players.where((p) => p.state == Pilot.arrived).toList()
    ..sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
  if (arrived.isNotEmpty) return DuelOutcome(DuelEnd.win, [arrived.first.id]);
  if (players.any((p) => p.state == Pilot.flying)) return null;
  // Plus personne en vol et personne arrivé : le plus loin gagne.
  final far = players.map((p) => p.year).reduce(math.max);
  final best = players.where((p) => (p.year - far).abs() < 0.005).toList();
  return best.length == 1
      ? DuelOutcome(DuelEnd.win, [best.first.id])
      : DuelOutcome(DuelEnd.draw, [for (final p in best) p.id]);
}

/// Une salle vue sur le Wi-Fi.
class DuelRoom {
  DuelRoom({
    required this.id,
    required this.host,
    required this.address,
    required this.port,
    required this.code,
    required this.rules,
    required this.count,
    this.rematchOf = '',
  });

  final String id, host, code;
  final String address;
  final int port;
  final DuelRules rules;
  int count;
  int seen = 0;

  /// La revanche d'un duel : ceux qui l'ont joué y entrent d'eux-mêmes.
  final String rematchOf;

  static DuelRoom? fromAnnounce(Object? j, String address) {
    if (j is! Map || j['c243'] != 1) return null;
    final rules = DuelRules.fromJson(j['r']);
    final id = j['id'], host = j['h'], port = j['p'], code = j['k'], n = j['n'], rv = j['rv'];
    if (rules == null || id is! String || host is! String || port is! int || code is! String || n is! int) return null;
    if (port < 1024 || port > 65535 || id.length > 24) return null;
    return DuelRoom(
      id: id,
      host: _clean(host, 24),
      address: address,
      port: port,
      code: _clean(code, 4),
      rules: rules,
      count: n.clamp(0, duelMaxPlayers),
      rematchOf: rv is String ? _clean(rv, 24) : '',
    );
  }
}

/// L'adresse du téléphone sur le Wi-Fi (réseau privé), ou null s'il n'est pas sur un Wi-Fi.
Future<List<InternetAddress>> wifiAddresses() async {
  try {
    final list = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final i in list)
        for (final a in i.addresses)
          if (!a.isLoopback && _isPrivate(a)) a,
    ];
  } catch (_) {
    return const [];
  }
}

bool _isPrivate(InternetAddress a) {
  final b = a.rawAddress;
  if (b.length != 4) return false;
  return b[0] == 10 || (b[0] == 192 && b[1] == 168) || (b[0] == 172 && b[1] >= 16 && b[1] <= 31);
}

/// L'adresse qui touche tout le Wi-Fi de ce téléphone (un réseau de maison, en x.y.z.255).
String _subnet(InternetAddress a) {
  final r = a.rawAddress;
  return '${r[0]}.${r[1]}.${r[2]}.255';
}

/// Les annonces envoyées à tout le Wi-Fi, à l'adresse générale et à celle du réseau du téléphone.
Future<Set<String>> _everyone() async => {'255.255.255.255', for (final a in await wifiAddresses()) _subnet(a)};

/// Un pilote vu sur le Wi-Fi, l'écran du duel ouvert.
class DuelPeer {
  DuelPeer(this.id, this.name, this.address);

  final String id;
  String name, address;
  int seen = 0;

  /// La salle qu'il a ouverte, s'il en a une.
  DuelRoom? room;
}

/// Qui est là sur le Wi-Fi, comme AirDrop. Chaque téléphone dont l'écran du duel est ouvert se signale
/// toutes les secondes et demie, à tout le Wi-Fi et directement à ceux qu'il a déjà entendus : certains
/// Wi-Fi laissent passer l'un sans l'autre. Les salles ouvertes et les invitations suivent le même chemin.
///
/// L'iPhone n'a pas le droit d'écrire à tout le Wi-Fi : il se fait connaître par Bonjour, comme une
/// imprimante, et Android le comprend aussi. Bonjour donne l'adresse de l'autre, puis on se parle directement.
class DuelFinder extends ChangeNotifier {
  static const _lock = MethodChannel('chacha243/net');

  /// Le nom du service Bonjour, déclaré aussi dans l'Info.plist de l'iPhone (NSBonjourServices).
  static const bonjourType = '_chacha243._tcp';

  BonsoirBroadcast? _shout;
  BonsoirDiscovery? _look;

  /// Les adresses données par Bonjour : on leur écrit directement.
  final _hints = <String>{};

  /// Sans nouvelles depuis sept secondes, un pilote ou une salle est parti.
  static const _forget = 7000;

  RawDatagramSocket? _socket;
  Timer? _pulse;
  bool _binding = false, _stopped = false;
  final _rooms = <String, DuelRoom>{};
  final _peers = <String, DuelPeer>{};
  final _invited = <String>{};
  String _myId = '', _myName = '';

  /// L'annonce de la salle que j'ai ouverte : elle part avec ma présence.
  Map<String, Object?>? room;

  /// Un ami m'invite dans sa salle : l'écran me le montre.
  void Function(DuelRoom room, String from)? onInvite;

  List<DuelRoom> get rooms => _rooms.values.toList();

  /// Les pilotes vus sur le Wi-Fi, moi exclu.
  List<DuelPeer> get peers => _peers.values.toList();
  bool get listening => _socket != null;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> start({required String myId, required String myName}) async {
    _myId = myId;
    _myName = myName;
    _stopped = false;
    if (_pulse != null) return;
    try {
      await _lock.invokeMethod<bool>('hold');
    } catch (_) {}
    _pulse = Timer.periodic(const Duration(milliseconds: 1500), (_) => _beat());
    await _beat();
    _bonjour();
  }

  /// Bonjour : je m'annonce avec mes adresses, et je cherche ceux qui s'annoncent.
  Future<void> _bonjour() async {
    try {
      final ips = [for (final a in await wifiAddresses()) a.address];
      final shout = BonsoirBroadcast(
        service: BonsoirService(
          name: 'Chacha243 ${_myId.length > 10 ? _myId.substring(0, 10) : _myId}',
          type: bonjourType,
          port: duelPort,
          attributes: {'id': _myId, 'ip': ips.join(',')},
        ),
      );
      await shout.initialize();
      await shout.start();
      if (_stopped) return shout.stop();
      _shout = shout;
    } catch (_) {}
    try {
      final look = BonsoirDiscovery(type: bonjourType);
      await look.initialize();
      look.eventStream?.listen((e) {
        switch (e) {
          case BonsoirDiscoveryServiceFoundEvent():
            if (e.service.attributes['id'] != _myId) look.serviceResolver.resolveService(e.service).catchError((_) {});
          case BonsoirDiscoveryServiceResolvedEvent() || BonsoirDiscoveryServiceUpdatedEvent():
            _hint(e.service);
          default:
        }
      });
      await look.start();
      if (_stopped) return look.stop();
      _look = look;
    } catch (_) {}
  }

  void _hint(BonsoirService? s) {
    if (s == null || s.attributes['id'] == _myId) return;
    var fresh = false;
    for (final ip in [...?s.attributes['ip']?.split(','), ?s.host]) {
      final a = InternetAddress.tryParse(ip.trim());
      if (a != null && a.type == InternetAddressType.IPv4 && _isPrivate(a)) fresh = _hints.add(a.address) || fresh;
    }
    // Une nouvelle adresse : on lui dit bonjour tout de suite.
    if (fresh && _socket != null) {
      final hi = _packet({'t': 'hi', 'room': ?room});
      for (final to in _hints) {
        _send(_socket!, hi, to);
      }
    }
  }

  Future<void> _bind() async {
    if (_binding || _socket != null) return;
    _binding = true;
    try {
      // Le port partagé : l'écran d'avant qui se ferme encore ne bloque pas le nouveau.
      RawDatagramSocket s;
      try {
        s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, duelPort, reuseAddress: true, reusePort: true);
      } catch (_) {
        s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, duelPort, reuseAddress: true);
      }
      if (_stopped) return s.close();
      s.broadcastEnabled = true;
      _socket = s;
      s.listen(_read, onError: (_) => _lost(s), onDone: () => _lost(s));
      notifyListeners();
    } catch (_) {
      // Le port est encore pris (l'écran d'avant se ferme) ou le Wi-Fi bloque : on réessaie au prochain battement.
    } finally {
      _binding = false;
    }
  }

  void _lost(RawDatagramSocket s) {
    if (_socket != s) return;
    _socket = null;
    s.close();
  }

  Future<void> _beat() async {
    if (_stopped) return;
    if (_socket == null) await _bind();
    final s = _socket;
    if (s == null) return;
    final now = _now;
    final before = _rooms.length + _peers.length;
    _rooms.removeWhere((_, r) => now - r.seen > _forget);
    _peers.removeWhere((_, p) => now - p.seen > _forget);
    for (final p in _peers.values) {
      if (p.room != null && now - p.room!.seen > _forget) p.room = null;
    }
    if (before != _rooms.length + _peers.length) notifyListeners();
    final hi = _packet({'t': 'hi', 'room': ?room});
    for (final to in {...await _everyone(), ..._hints, for (final p in _peers.values) p.address}) {
      _send(s, hi, to);
    }
  }

  List<int> _packet(Map<String, Object?> m) => utf8.encode(jsonEncode({'c243': 2, 'id': _myId, 'n': _myName, ...m}));

  void _send(RawDatagramSocket s, List<int> data, String to) {
    try {
      s.send(data, InternetAddress(to), duelPort);
    } catch (_) {}
  }

  void _read(RawSocketEvent e) {
    final s = _socket;
    if (e != RawSocketEvent.read || s == null) return;
    for (var d = s.receive(); d != null; d = s.receive()) {
      _take(d);
    }
  }

  void _take(Datagram d) {
    if (d.data.length > 1200) return;
    Object? j;
    try {
      j = jsonDecode(utf8.decode(d.data));
    } catch (_) {
      return;
    }
    if (j is! Map) return;
    final from = d.address.address, now = _now;
    var changed = false;
    // L'annonce d'une salle, venue de l'organisateur (ou d'une version plus ancienne du jeu).
    if (j['c243'] == 1) changed = _seeRoom(j, from, now, null);
    if (j['c243'] == 2) {
      final id = j['id'], n = j['n'];
      if (id is! String || id.isEmpty || id.length > 64 || n is! String || id == _myId) return;
      var p = _peers[id];
      if (p == null) {
        p = _peers[id] = DuelPeer(id, _clean(n, 24), from);
        changed = true;
        // Un nouveau venu : on lui répond tout de suite, sans attendre le prochain battement.
        if (_socket case final s?) _send(s, _packet({'t': 'hi', 'room': ?room}), from);
      } else if (p.name != _clean(n, 24) || p.address != from) {
        p
          ..name = _clean(n, 24)
          ..address = from;
        changed = true;
      }
      p.seen = now;
      if (j['room'] is Map) {
        changed = _seeRoom(j['room'], from, now, p) || changed;
      } else if (p.room != null && j['t'] == 'hi') {
        // Sa salle a fermé (le duel est lancé, ou il est revenu au menu).
        _rooms.remove(p.room!.id);
        p.room = null;
        changed = true;
      }
      if (j['t'] == 'inv' && j['to'] == _myId && p.room != null && _invited.add(p.room!.id)) {
        onInvite?.call(p.room!, p.name);
      }
    }
    if (changed) notifyListeners();
  }

  bool _seeRoom(Object? j, String from, int now, DuelPeer? by) {
    final r = DuelRoom.fromAnnounce(j, from);
    if (r == null || r.id == room?['id']) return false;
    r.seen = now;
    final known = _rooms[r.id];
    _rooms[r.id] = r;
    by?.room = r;
    return known == null || known.count != r.count;
  }

  /// J'invite un pilote vu sur le Wi-Fi dans ma salle : le message part chez lui et à tout le Wi-Fi, trois fois.
  Future<void> invite(DuelPeer p) async {
    final s = _socket;
    if (s == null || room == null) return;
    final data = _packet({'t': 'inv', 'to': p.id, 'room': room});
    final to = {p.address, ...await _everyone()};
    for (final ms in const [0, 350, 1000]) {
      Timer(Duration(milliseconds: ms), () {
        if (_socket != s) return;
        for (final a in to) {
          _send(s, data, a);
        }
      });
    }
  }

  void stop() {
    _stopped = true;
    _pulse?.cancel();
    _pulse = null;
    _socket?.close();
    _socket = null;
    _rooms.clear();
    _peers.clear();
    _hints.clear();
    _shout?.stop().catchError((_) {});
    _look?.stop().catchError((_) {});
    _shout = null;
    _look = null;
    _lock.invokeMethod<void>('release').catchError((_) {});
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class _Conn {
  _Conn(this.socket);

  final Socket socket;
  final buffer = StringBuffer();
  String? player;
  int bytes = 0;

  /// La dernière fois qu'on a eu de ses nouvelles.
  int heard = DateTime.now().millisecondsSinceEpoch;
}

/// Un duel en cours, côté organisateur ou côté invité.
class DuelNet extends ChangeNotifier {
  DuelNet._(this.isHost, this.myId, this.myName, this.rules, this.duelId, this.code, [this.rematchOf = '']);

  /// L'organisateur ouvre la salle et garde le verdict. Une revanche porte le numéro du duel d'avant.
  static Future<DuelNet?> host({
    required String myId,
    required String myName,
    required DuelRules rules,
    String rematchOf = '',
  }) async {
    final rnd = math.Random.secure();
    String hex(int n) => List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    final net = DuelNet._(true, myId, myName, rules, hex(12), (1000 + rnd.nextInt(9000)).toString(), rematchOf);
    try {
      net._server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return null;
    }
    net._players[myId] = DuelPlayer(myId, myName)..year = rules.start.toDouble();
    net._server!.listen(net._accept, onError: (_) {});
    await net._announceStart();
    net._keep();
    return net;
  }

  /// L'invité entre dans une salle vue sur le Wi-Fi (ou dont il a tapé l'adresse).
  static Future<DuelNet?> join({
    required String myId,
    required String myName,
    required String address,
    required int port,
    required String code,
  }) async {
    final net = DuelNet._(false, myId, myName, const DuelRules(), '', code);
    try {
      final s = await Socket.connect(address, port, timeout: const Duration(seconds: 5));
      net._attach(s);
      net._send(s, {'t': 'join', 'id': myId, 'n': myName, 'k': code, 'v': duelTerms});
      // On attend la réponse de l'organisateur : la salle, ou un refus.
      final done = Completer<bool>();
      void check() {
        if (net.refusal != null || net.duelId.isNotEmpty) {
          if (!done.isCompleted) done.complete(net.refusal == null);
        }
      }

      net.addListener(check);
      final ok = await done.future.timeout(const Duration(seconds: 6), onTimeout: () => false);
      net.removeListener(check);
      if (ok) net._keep();
      if (!ok) {
        net.refusal ??= 'La salle ne répond pas.';
        net.close();
        return null;
      }
      return net;
    } catch (_) {
      net.close();
      return null;
    }
  }

  final bool isHost;
  final String myId, myName;
  DuelRules rules;
  String duelId;
  final String code;

  /// Le duel dont celui-ci est la revanche.
  final String rematchOf;

  /// Pourquoi l'entrée a été refusée.
  String? refusal;

  ServerSocket? _server;
  Socket? _upstream;
  final _clients = <_Conn>[];
  final _players = <String, DuelPlayer>{};
  RawDatagramSocket? _beacon;
  Timer? _announce, _tick, _alive;
  _Conn? _host;
  int _seq = 0;

  /// Les pilotes de la salle, dans l'ordre d'arrivée.
  List<DuelPlayer> get players => _players.values.toList();
  DuelPlayer get me => _players[myId] ?? (_players[myId] = DuelPlayer(myId, myName));

  bool started = false;
  DuelOutcome? outcome;

  /// Le port de la salle, pour que les amis puissent l'entrer à la main.
  int? get hostPort => _server?.port;

  /// Dès que l'organisateur lance : la graine et la clé du duel, et l'heure du départ.
  int seed = 0;
  List<int> _key = const [];
  bool closed = false;

  // ------------------------------------------------------------ organisateur

  Future<void> _announceStart() async {
    try {
      _beacon = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _beacon!.broadcastEnabled = true;
    } catch (_) {
      _beacon = null;
    }
    _announce = Timer.periodic(const Duration(seconds: 1), (_) => _beaconOnce());
    _beaconOnce();
  }

  /// L'annonce de la salle, tant qu'elle attend ses pilotes ; null une fois le duel lancé.
  Map<String, Object?>? get announce => !isHost || started || closed || _server == null
      ? null
      : {
          'c243': 1,
          'id': duelId,
          'h': myName,
          'p': _server!.port,
          'k': code,
          'n': _players.length,
          'r': rules.toJson(),
          if (rematchOf.isNotEmpty) 'rv': rematchOf,
        };

  Future<void> _beaconOnce() async {
    final b = _beacon, a = announce;
    if (b == null || a == null) return;
    final data = utf8.encode(jsonEncode(a));
    for (final to in await _everyone()) {
      try {
        b.send(data, InternetAddress(to), duelPort);
      } catch (_) {}
    }
  }

  /// Le fil reste vivant : toutes les deux secondes, chacun donne signe de vie. Un téléphone fermé, sorti
  /// du Wi-Fi ou endormi sans prévenir est oublié de la salle, et peut y revenir à la réouverture du jeu.
  void _keep() {
    _alive = Timer.periodic(const Duration(seconds: 2), (_) {
      if (closed) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (isHost) {
        if (!started) _sendRoom();
        for (final c in [..._clients]) {
          if (now - c.heard > (started ? 20000 : 9000)) _onDrop(c, destroy: true);
        }
      } else if (_host case final h?) {
        if (!started) _send(h.socket, {'t': 'ping'});
        if (now - h.heard > (started ? 15000 : 9000)) _onDrop(h, destroy: true);
      }
    });
  }

  void _accept(Socket s) {
    if (started || _clients.length >= duelMaxPlayers - 1) {
      _send(s, {'t': 'no', 'why': started ? 'Le duel a déjà commencé.' : 'La salle est pleine.'});
      s.destroy();
      return;
    }
    _attach(s);
  }

  /// L'organisateur lance : au moins deux pilotes, et chacun reçoit la graine et la clé.
  bool launch() {
    if (!isHost || started || _players.length < 2) return false;
    final rnd = math.Random.secure();
    seed = rnd.nextInt(1 << 30);
    _key = List.generate(16, (_) => rnd.nextInt(256));
    started = true;
    _announce?.cancel();
    _beacon?.close();
    _broadcast({'t': 'go', 'seed': seed, 'key': base64Encode(_key), 'p': _wirePlayers()});
    _begin();
    notifyListeners();
    return true;
  }

  // ----------------------------------------------------------------- réseau

  void _attach(Socket s) {
    final c = _Conn(s);
    if (isHost) {
      _clients.add(c);
    } else {
      _upstream = s;
      _host = c;
    }
    s.setOption(SocketOption.tcpNoDelay, true);
    s.listen((data) => _onData(c, data), onDone: () => _onDrop(c), onError: (_) => _onDrop(c), cancelOnError: true);
  }

  void _onData(_Conn c, List<int> data) {
    c.bytes += data.length;
    c.heard = DateTime.now().millisecondsSinceEpoch;
    // Un téléphone qui bavarde trop (ou une attaque) est coupé : on reste léger.
    if (c.bytes > 400000) return _onDrop(c, destroy: true);
    final text = utf8.decode(data, allowMalformed: true);
    for (final ch in text.split('')) {
      if (ch == '\n') {
        final line = c.buffer.toString();
        c.buffer.clear();
        if (line.isNotEmpty) _onLine(c, line);
      } else if (c.buffer.length < 2400) {
        c.buffer.write(ch);
      } else {
        c.buffer.clear();
      }
    }
  }

  void _onLine(_Conn c, String line) {
    Object? m;
    try {
      m = jsonDecode(line);
    } catch (_) {
      return;
    }
    if (m is! Map || m['t'] is! String) return;
    isHost ? _hostGets(c, m) : _guestGets(m);
  }

  void _onDrop(_Conn c, {bool destroy = false}) {
    if (destroy) c.socket.destroy();
    if (isHost) {
      if (!_clients.remove(c)) return;
      final id = c.player;
      final p = id == null ? null : _players[id];
      if (p != null && !started) {
        _players.remove(id);
        _sendRoom();
      } else if (p != null && !p.out) {
        p.state = Pilot.lost;
        _decide();
        _sharePlayers();
      }
    } else if (!closed && outcome == null) {
      if (!started && duelId.isEmpty) {
        refusal ??= 'La salle ne répond pas.';
      } else {
        outcome = const DuelOutcome(DuelEnd.voided, []);
        for (final p in _players.values) {
          if (p.state == Pilot.flying && p.id != myId) p.state = Pilot.lost;
        }
      }
    }
    notifyListeners();
  }

  void _send(Socket s, Map<String, Object?> m) {
    try {
      s.write('${jsonEncode(m)}\n');
    } catch (_) {}
  }

  void _broadcast(Map<String, Object?> m) {
    for (final c in _clients) {
      _send(c.socket, m);
    }
  }

  List<Object> _wirePlayers() => [for (final p in _players.values) p.toWire()];

  void _sendRoom() {
    _broadcast({'t': 'room', 'id': duelId, 'r': rules.toJson(), 'p': _wirePlayers()});
    notifyListeners();
  }

  // ------------------------------------------------------- côté organisateur

  void _hostGets(_Conn c, Map m) {
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (m['t']) {
      case 'join':
        final id = m['id'], name = m['n'];
        if (id is! String || id.length < 8 || id.length > 64 || name is! String || m['k'] != code) {
          _send(c.socket, {'t': 'no', 'why': 'Le code ne correspond pas.'});
          return _onDrop(c, destroy: true);
        }
        if (m['v'] != duelTerms) {
          _send(c.socket, {'t': 'no', 'why': 'Les conditions ont changé : mets le jeu à jour.'});
          return _onDrop(c, destroy: true);
        }
        // Le même pilote revient (son jeu s'est fermé, son Wi-Fi a sauté) : l'ancien fil est oublié.
        if (_players.containsKey(id) && id != myId) {
          for (final old in _clients.where((o) => o != c && o.player == id).toList()) {
            _clients.remove(old);
            old.socket.destroy();
          }
          _players.remove(id);
        }
        if (_players.containsKey(id) || _players.length >= duelMaxPlayers) {
          _send(c.socket, {'t': 'no', 'why': 'Tu es déjà dans cette salle, ou elle est pleine.'});
          return _onDrop(c, destroy: true);
        }
        c.player = id;
        _players[id] = DuelPlayer(id, _clean(name, 24))
          ..year = rules.start.toDouble()
          ..lastSeen = now;
        _sendRoom();
      case 'st':
        final p = _players[c.player];
        if (p == null || !started || outcome != null) return;
        _takeState(p, m, now);
    }
  }

  /// Un état reçu d'un pilote : on vérifie la signature, l'ordre et que l'année ne recule pas.
  void _takeState(DuelPlayer p, Map m, int now) {
    final y = m['y'], l = m['l'], f = m['f'], s = m['s'], q = m['q'], g = m['g'];
    if (y is! int || l is! int || f is! int || s is! int || q is! int || g is! String) return;
    if (f < 0 || f >= Pilot.values.length || q <= p.seq || y < (p.year * 100).round() - 1) return;
    if (g != sign(p.id, q, y, l, f, s)) return;
    // Un pilote déjà sorti ne revient pas, et ne gagne que s'il est vraiment le dernier en vol.
    if (p.out) return;
    final next = Pilot.values[f];
    if (next == Pilot.won && _players.values.any((o) => o.id != p.id && o.state == Pilot.flying)) return;
    p
      ..seq = q
      ..year = y / 100
      ..lives = l.clamp(0, 9)
      ..seconds = s
      ..lastSeen = now;
    if (next != p.state) {
      p.state = next;
      if (next == Pilot.arrived) p.arrivedAt = now;
    }
    _decide();
    _sharePlayers();
  }

  int _lastShare = 0;

  /// Partage les états avec tout le monde, au plus une fois par seconde, sauf quand quelque chose change.
  void _sharePlayers({bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final urgent = force || outcome != null || _players.values.any((p) => p.out);
    if (!urgent && now - _lastShare < 900) {
      notifyListeners();
      return;
    }
    _lastShare = now;
    _broadcast({'t': 'pr', 'p': _wirePlayers(), if (outcome != null) 'o': outcome!.toJson()});
    notifyListeners();
  }

  void _decide() {
    if (outcome != null) return;
    outcome = judge(rules, players);
  }

  // ---------------------------------------------------------- côté invité

  void _guestGets(Map m) {
    switch (m['t']) {
      case 'no':
        refusal = m['why'] is String ? _clean(m['why'] as String, 80) : 'Refusé.';
      case 'room':
        final r = DuelRules.fromJson(m['r']), id = m['id'];
        if (r == null || id is! String) return;
        rules = r;
        duelId = id;
        _readPlayers(m['p']);
      case 'go':
        final key = m['key'], sd = m['seed'];
        if (key is! String || sd is! int) return;
        try {
          _key = base64Decode(key);
        } catch (_) {
          return;
        }
        seed = sd;
        _readPlayers(m['p']);
        started = true;
        _begin();
      case 'pr':
        _readPlayers(m['p']);
        final o = DuelOutcome.fromJson(m['o']);
        if (o != null && outcome == null) outcome = o;
    }
    notifyListeners();
  }

  void _readPlayers(Object? list) {
    if (list is! List) return;
    final seen = <String>{};
    for (final w in list.take(duelMaxPlayers)) {
      final n = DuelPlayer.fromWire(w);
      if (n == null) continue;
      seen.add(n.id);
      final mine = n.id == myId;
      final p = _players.putIfAbsent(n.id, () => n);
      p.name = n.name;
      // Mon propre état est celui que je connais : l'organisateur ne l'écrase pas.
      if (!mine) {
        p
          ..year = n.year
          ..lives = n.lives
          ..state = n.state
          ..seconds = n.seconds;
      } else if (n.state == Pilot.lost) {
        p.state = Pilot.lost;
      }
    }
    _players.removeWhere((id, _) => !seen.contains(id));
  }

  // --------------------------------------------------------------- pendant

  /// Signature d'un état : seuls les pilotes de ce duel connaissent la clé.
  String sign(String id, int q, int y, int l, int f, int s) {
    final mac = Hmac(sha256, _key).convert(utf8.encode('$duelId|$id|$q|$y|$l|$f|$s'));
    return mac.toString().substring(0, 20);
  }

  DateTime? beganAt;

  void _begin() {
    beganAt = DateTime.now();
    for (final p in _players.values) {
      p.year = rules.start.toDouble();
    }
    // Chaque seconde : l'état part, et l'organisateur coupe les pilotes qui ne répondent plus.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _heartbeat());
  }

  void _heartbeat() {
    if (closed) return;
    if (isHost) {
      final now = DateTime.now().millisecondsSinceEpoch;
      me.lastSeen = now;
      for (final p in _players.values) {
        if (!p.out && p.id != myId && now - p.lastSeen > 20000) p.state = Pilot.lost;
      }
      _decide();
      _sharePlayers(force: true);
    } else {
      _pushMine();
    }
  }

  int _lastSent = 0;

  /// Mon état de pilote, appelé par le jeu ; il part tout de suite si l'état change.
  void report({required double year, required int lives, required Pilot state}) {
    final mine = me;
    final seconds = beganAt == null ? 0 : DateTime.now().difference(beganAt!).inSeconds;
    final changed = mine.state != state;
    if (mine.out) return;
    if (state == Pilot.won && _players.values.any((o) => o.id != myId && o.state == Pilot.flying)) return;
    mine
      ..year = math.max(mine.year, year)
      ..lives = lives
      ..seconds = seconds;
    if (changed) {
      mine.state = state;
      if (state == Pilot.arrived) mine.arrivedAt = DateTime.now().millisecondsSinceEpoch;
    }
    if (isHost) {
      _decide();
      if (changed) _sharePlayers(force: true);
    } else if (changed) {
      _pushMine();
    }
    notifyListeners();
  }

  void _pushMine() {
    final up = _upstream;
    if (up == null || !started) return;
    final mine = me;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSent < 400) return;
    _lastSent = now;
    final q = ++_seq;
    final y = (mine.year * 100).round(), l = mine.lives, f = mine.state.index, s = mine.seconds;
    _send(up, {'t': 'st', 'q': q, 'y': y, 'l': l, 'f': f, 's': s, 'g': sign(myId, q, y, l, f, s)});
  }

  /// Ce qu'on envoie au tableau de bord à la fin : mon résultat, et ce que j'ai vu des autres.
  Map<String, Object?> result() => {
    'duel': duelId,
    'mode': rules.mode.index,
    'start': rules.start,
    'target': rules.target,
    'n': _players.length,
    'state': me.state.index,
    'year': me.year,
    'lives': me.lives,
    'secs': me.seconds,
    'end': outcome?.end.index ?? DuelEnd.voided.index,
    'win': outcome?.winners.contains(myId) ?? false,
    'seen': [
      for (final p in _players.values)
        if (p.id != myId) [p.id, (p.year * 100).round(), p.state.index],
    ],
  };

  void close() {
    closed = true;
    _announce?.cancel();
    _tick?.cancel();
    _alive?.cancel();
    _beacon?.close();
    for (final c in [..._clients]) {
      c.socket.destroy();
    }
    _upstream?.destroy();
    _server?.close();
    _clients.clear();
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
