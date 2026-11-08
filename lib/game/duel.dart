import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

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
  });

  final String id, host, code;
  final String address;
  final int port;
  final DuelRules rules;
  int count;
  int seen = 0;

  static DuelRoom? fromAnnounce(Object? j, String address) {
    if (j is! Map || j['c243'] != 1) return null;
    final rules = DuelRules.fromJson(j['r']);
    final id = j['id'], host = j['h'], port = j['p'], code = j['k'], n = j['n'];
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

/// Cherche les salles ouvertes sur le Wi-Fi, comme AirDrop : à l'écoute des annonces de l'organisateur.
class DuelFinder extends ChangeNotifier {
  RawDatagramSocket? _socket;
  Timer? _sweep;
  final _rooms = <String, DuelRoom>{};

  List<DuelRoom> get rooms => _rooms.values.toList();
  bool get listening => _socket != null;

  Future<void> start() async {
    if (_socket != null) return;
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, duelPort, reuseAddress: true);
      s.broadcastEnabled = true;
      _socket = s;
      s.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null || d.data.length > 600) return;
        try {
          final room = DuelRoom.fromAnnounce(jsonDecode(utf8.decode(d.data)), d.address.address);
          if (room == null) return;
          final known = _rooms[room.id];
          room.seen = DateTime.now().millisecondsSinceEpoch;
          final changed = known == null || known.count != room.count;
          _rooms[room.id] = room;
          if (changed) notifyListeners();
        } catch (_) {}
      });
      // Une salle qui n'annonce plus depuis quatre secondes a fermé.
      _sweep = Timer.periodic(const Duration(seconds: 2), (_) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final before = _rooms.length;
        _rooms.removeWhere((_, r) => now - r.seen > 4000);
        if (_rooms.length != before) notifyListeners();
      });
      notifyListeners();
    } catch (_) {
      // Le Wi-Fi bloque l'écoute : on peut toujours entrer l'adresse de l'organisateur à la main.
    }
  }

  void stop() {
    _sweep?.cancel();
    _socket?.close();
    _socket = null;
    _rooms.clear();
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
}

/// Un duel en cours, côté organisateur ou côté invité.
class DuelNet extends ChangeNotifier {
  DuelNet._(this.isHost, this.myId, this.myName, this.rules, this.duelId, this.code);

  /// L'organisateur ouvre la salle et garde le verdict.
  static Future<DuelNet?> host({required String myId, required String myName, required DuelRules rules}) async {
    final rnd = math.Random.secure();
    String hex(int n) => List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    final net = DuelNet._(true, myId, myName, rules, hex(12), (1000 + rnd.nextInt(9000)).toString());
    try {
      net._server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return null;
    }
    net._players[myId] = DuelPlayer(myId, myName)..year = rules.start.toDouble();
    net._server!.listen(net._accept, onError: (_) {});
    await net._announceStart();
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

  /// Pourquoi l'entrée a été refusée.
  String? refusal;

  ServerSocket? _server;
  Socket? _upstream;
  final _clients = <_Conn>[];
  final _players = <String, DuelPlayer>{};
  RawDatagramSocket? _beacon;
  Timer? _announce, _tick;
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

  Future<void> _beaconOnce() async {
    final b = _beacon;
    if (b == null || started || closed) return;
    final data = utf8.encode(
      jsonEncode({
        'c243': 1,
        'id': duelId,
        'h': myName,
        'p': _server!.port,
        'k': code,
        'n': _players.length,
        'r': rules.toJson(),
      }),
    );
    try {
      b.send(data, InternetAddress('255.255.255.255'), duelPort);
      for (final a in await wifiAddresses()) {
        final r = a.rawAddress;
        b.send(data, InternetAddress('${r[0]}.${r[1]}.${r[2]}.255'), duelPort);
      }
    } catch (_) {}
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
    }
    s.setOption(SocketOption.tcpNoDelay, true);
    s.listen((data) => _onData(c, data), onDone: () => _onDrop(c), onError: (_) => _onDrop(c), cancelOnError: true);
  }

  void _onData(_Conn c, List<int> data) {
    c.bytes += data.length;
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
      _clients.remove(c);
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
