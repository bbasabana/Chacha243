import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../data/history_events.dart';
import 'checkpoint.dart';

/// Tells the Chacha 243 board on waddiel.pro how a flight goes: takeoff, each new year, a failure, the arrival.
/// It also keeps a copy of the pilot's name and resume point there, so a reinstalled game finds them again.
/// The player id comes from the phone (Android keeps it across reinstalls). Never blocks the game.
class Telemetry {
  Telemetry._();

  static const _url = 'https://waddiel.pro/api/v1/chacha';
  static const _version = '1.0.0';
  static const _channel = MethodChannel('chacha243/device');
  static const _keptId = 'chacha243.pilot_id';
  static String? _id;
  static Map<String, String> _device = const {};

  /// The phone's id and details, read once.
  static Future<String> _playerId() async {
    if (_id != null) return _id!;
    // Un pilote retrouvé par son code garde son identifiant, sur ce téléphone aussi.
    final kept = (await SharedPreferences.getInstance()).getString(_keptId);
    if (kept != null) return _id = kept;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || ios)) {
      try {
        final m = await _channel.invokeMapMethod<String, String>('info');
        if (m != null) {
          _device = m;
          final a = m['id'] ?? '';
          // iPhone : l'identifiant vient du trousseau, qui survit à une réinstallation.
          if (a.length >= 8) return _id = '${ios ? 'i' : 'a'}-$a';
        }
      } catch (_) {}
    }
    final p = await SharedPreferences.getInstance();
    var id = p.getString('telemetry_id');
    if (id == null) {
      final r = math.Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString('telemetry_id', id);
    }
    return _id = id;
  }

  static String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Without a connection the game still plays: every report waits on the phone, in order,
  /// and leaves as soon as the server answers again.
  static const _box = 'chacha243.outbox';
  static bool _flushing = false, _again = false;

  /// While reports wait, the phone tries again every minute: as soon as the connection is back, they leave.
  static Timer? _retry;

  /// One connection kept open for every report, instead of a new one each time.
  static final _http = http.Client();

  /// Reports that waited go up together, [_batch] per request. A server that does not know batches yet
  /// answers 400: the phone then sends them one by one, as before.
  static const _batch = 25;
  static bool _batches = true;

  static Future<void> _post(Map<String, Object?> body) async {
    try {
      final id = await _playerId();
      final item = jsonEncode({
        'id': id,
        'name': pilotName.value ?? '',
        'platform': _platform,
        'version': _version,
        'device': {
          for (final k in const ['brand', 'manufacturer', 'model', 'os', 'operator', 'sim', 'simCountry'])
            k: _device[k] ?? '',
        },
        'missions': missionsDone.value,
        'at': DateTime.now().millisecondsSinceEpoch,
        ...body,
      });
      final p = await SharedPreferences.getInstance();
      // Only the latest resume point matters; the oldest reports go first when the box is full.
      await p.setStringList(_box, keep(p.getStringList(_box) ?? [], item, save: body['kind'] == 'save'));
    } catch (_) {}
    await _flush();
  }

  /// Sends the waiting reports one by one; stops at the first one the network refuses.
  static Future<void> _flush() async {
    if (_flushing) {
      _again = true;
      return;
    }
    _flushing = true;
    var left = false;
    try {
      final p = await SharedPreferences.getInstance();
      while (true) {
        final box = p.getStringList(_box) ?? [];
        if (box.isEmpty) break;
        final items = box.take(_batches && box.length > 1 ? _batch : 1).toList();
        final many = items.length > 1;
        final r = await _http
            .post(
              Uri.parse(_url),
              headers: {'content-type': 'application/json'},
              body: many ? '{"batch":[${items.join(',')}]}' : items.first,
            )
            .timeout(Duration(seconds: many ? 15 : 8));
        if (many && r.statusCode == 400) {
          _batches = false;
          continue;
        }
        // The server is down or busy: keep it for later. A refused report (4xx) is dropped.
        if (r.statusCode >= 500 || r.statusCode == 429) {
          left = true;
          break;
        }
        await p.setStringList(_box, sent(p.getStringList(_box) ?? [], items));
      }
    } catch (_) {
      // no connection: everything stays in the box
      left = true;
    } finally {
      _flushing = false;
    }
    if (left && _retry == null) {
      _retry = Timer(const Duration(minutes: 1), () {
        _retry = null;
        _flush();
      });
    }
    if (_again) {
      _again = false;
      await _flush();
    }
  }

  /// The box once [items] left: a report added meanwhile stays.
  @visibleForTesting
  static List<String> sent(List<String> box, List<String> items) {
    final now = [...box];
    for (final i in items) {
      now.remove(i);
    }
    return now;
  }

  /// What goes into the box: a new resume point replaces the one waiting, and the box keeps at most 200 reports.
  @visibleForTesting
  static List<String> keep(List<String> box, String item, {required bool save}) {
    final now = [...box];
    if (save) now.removeWhere((x) => x.contains('"kind":"save"'));
    now.add(item);
    if (now.length > 200) now.removeRange(0, now.length - 200);
    return now;
  }

  /// Called at launch and when the app comes back: sends what waited offline.
  static Future<void> flush() => _flush();

  static Future<void> send(
    String kind, {
    required double year,
    int score = 0,
    String stage = '',
    String detail = '',
    double seconds = 0,
  }) =>
      _post({'kind': kind, 'year': year, 'score': score, 'stage': stage, 'detail': detail, 'seconds': seconds.round()});

  /// Keeps the resume point on the server too (null once the flight reached 2027).
  static Future<void> saveProgress(Checkpoint? cp) => _post({
    'kind': 'save',
    'year': cp?.year ?? 1960,
    'save': cp == null
        ? null
        : {'year': cp.year, 'score': cp.score, 'medals': cp.medals, 'money': cp.money, 'seconds': cp.seconds.round()},
  });

  /// The pilot's photo goes to the ranking. The pilot exists on the server once a first report was sent.
  static Future<bool> uploadPhoto(Uint8List bytes) async {
    try {
      final id = await _playerId();
      for (var i = 0; i < 2; i++) {
        final r = await http
            .post(
              Uri.parse('$_url/photo'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({'id': id, 'image': base64Encode(bytes)}),
            )
            .timeout(const Duration(seconds: 15));
        if (r.statusCode == 204) return true;
        if (r.statusCode != 404) return false;
        await hello();
      }
    } catch (_) {}
    return false;
  }

  /// The game was opened: the phone counts among the players, even before a first flight.
  static Future<void> hello() => _post({'kind': 'hello', 'year': 1960});

  /// The championship in progress (title, prize, end), read with the news; null when there is none.
  static final championship = ValueNotifier<Championship?>(null);

  /// The latest message from the dashboard to every pilot, if this phone has not shown it yet.
  /// Also refreshes [championship].
  static Future<News?> news() async {
    try {
      final r = await http.get(Uri.parse('$_url/news')).timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return null;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final ch = b['championship'] as Map<String, dynamic>?;
      championship.value = ch == null || appStoreRules
          ? null
          : Championship(
              ch['title'] as String? ?? '',
              ch['prize'] as String? ?? '',
              ch['rule'] == 'first',
              DateTime.tryParse(ch['ends'] as String? ?? '')?.toLocal(),
            );
      final id = b['id'];
      if (id is! int) return null;
      final p = await SharedPreferences.getInstance();
      if (p.getInt('chacha243.news') == id) return null;
      final c = appStoreRules ? null : b['champion'] as Map<String, dynamic>?;
      Uint8List? photo;
      if (c != null && c['photo'] == true) {
        final ph = await http
            .get(Uri.parse('$_url/photo?id=${Uri.encodeQueryComponent(c['id'] as String)}'))
            .timeout(const Duration(seconds: 6));
        if (ph.statusCode == 200) photo = ph.bodyBytes;
      }
      return News(
        id,
        b['title'] as String? ?? '',
        b['body'] as String? ?? '',
        b['reward'] as String? ?? '',
        c?['name'] as String?,
        (c?['year'] as num?)?.toInt(),
        photo,
        (b['seconds'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// The five best pilots, shown one by one when the game opens to make the others want to beat them.
  /// Empty offline.
  static Future<List<TopPilot>> top() async {
    try {
      final r = await http.get(Uri.parse('$_url/top')).timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return const [];
      final list = (jsonDecode(r.body) as Map<String, dynamic>)['top'] as List<dynamic>? ?? const [];
      return Future.wait([
        for (final x in list.cast<Map<String, dynamic>>())
          () async {
            final place = (x['place'] as num?)?.toInt() ?? 0;
            Uint8List? photo;
            if (x['photo'] == true) {
              try {
                final ph = await http.get(Uri.parse('$_url/top?photo=$place')).timeout(const Duration(seconds: 6));
                if (ph.statusCode == 200) photo = ph.bodyBytes;
              } catch (_) {}
            }
            return TopPilot(
              place,
              x['name'] as String? ?? '',
              (x['year'] as num?)?.toInt() ?? 1960,
              x['arrived'] == true,
              (x['score'] as num?)?.toInt() ?? 0,
              photo,
            );
          }(),
      ]);
    } catch (_) {
      return const [];
    }
  }

  /// The Mobile Money number where a championship prize is sent. True once the server kept it.
  static Future<bool> sendMomo(String number) async {
    try {
      final id = await _playerId();
      final r = await http
          .post(
            Uri.parse('$_url/momo'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'id': id, 'number': number}),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 204) {
        await (await SharedPreferences.getInstance()).setString('chacha243.momo', number);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<String?> savedMomo() async {
    try {
      return (await SharedPreferences.getInstance()).getString('chacha243.momo');
    } catch (_) {
      return null;
    }
  }

  /// A photo chosen while offline, or before the pilot existed on the server, goes up at the next launch.
  static Future<void> syncPhoto() async {
    final ph = pilotPhoto.value;
    if (ph == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      final mark = '${ph.length}:${ph.isEmpty ? 0 : ph[ph.length ~/ 2]}';
      if (p.getString('chacha243.photo_sent') == mark) return;
      if (await uploadPhoto(ph)) await p.setString('chacha243.photo_sent', mark);
    } catch (_) {}
  }

  static Future<void> newsSeen(int id) async {
    try {
      await (await SharedPreferences.getInstance()).setInt('chacha243.news', id);
    } catch (_) {}
  }

  /// A proposal for the game (a date, a photo, a song), sent to the dashboard. Answers the server's status:
  /// 204 kept, 429 too many in an hour, 0 no connection.
  static Future<int> sendProposal({
    required String kind,
    required String title,
    String happened = '',
    String link = '',
    String message = '',
    Uint8List? image,
  }) async {
    try {
      final r = await _http
          .post(
            Uri.parse('$_url/proposal'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'id': await _playerId(),
              'source': 'app',
              'name': pilotName.value ?? '',
              'kind': kind,
              'title': title,
              'happened': happened,
              'link': link,
              'message': message,
              'image': image == null ? '' : base64Encode(image),
            }),
          )
          .timeout(const Duration(seconds: 20));
      return r.statusCode;
    } catch (_) {
      return 0;
    }
  }

  static const _duelBox = 'chacha243.duelq';

  /// A duel record for the dashboard: the terms accepted, a room joined, a final result. Tiny, and kept on the
  /// phone only while the network is down (at most six, tried again at the next launch).
  static Future<bool> sendDuel(Map<String, Object?> body, {bool queue = true}) async {
    try {
      body['id'] = await _playerId();
      body['name'] = pilotName.value ?? '';
      body['platform'] = _platform;
      final r = await _http
          .post(Uri.parse('$_url/duel'), headers: {'content-type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      // The pilot is not known to the server yet: a first report creates it, then once more.
      if (r.statusCode == 404 && queue) {
        await hello();
        return sendDuel(body, queue: false);
      }
      // 4xx: the server will never take it, so it is not kept.
      if (r.statusCode < 500) return r.statusCode == 204;
    } catch (_) {}
    if (queue) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_duelBox) ?? [];
        list.add(jsonEncode(body));
        await prefs.setStringList(_duelBox, list.length > 6 ? list.sublist(list.length - 6) : list);
      } catch (_) {}
    }
    return false;
  }

  /// Sends again what could not leave during a duel.
  static Future<void> flushDuels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_duelBox) ?? [];
      if (list.isEmpty) return;
      await prefs.remove(_duelBox);
      for (final j in list) {
        await sendDuel(Map<String, Object?>.from(jsonDecode(j) as Map), queue: true);
      }
    } catch (_) {}
  }

  /// True once when the server knows of a donation this pilot made and the phone did not thank for yet.
  static Future<bool> newGift() async {
    try {
      final id = await _playerId();
      final r = await _http
          .get(Uri.parse('$_url?id=${Uri.encodeQueryComponent(id)}'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return false;
      final gifts = ((jsonDecode(r.body) as Map<String, dynamic>)['gifts'] as num?)?.toInt() ?? 0;
      final p = await SharedPreferences.getInstance();
      if (gifts <= (p.getInt('chacha243.gifts') ?? 0)) return false;
      await p.setInt('chacha243.gifts', gifts);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The phone's id, for the donation link: the dashboard shows which pilot gave.
  static Future<String> playerId() => _playerId();

  /// The pilot rates the game: 1 to 5 stars and a short message. True once the server kept it.
  static Future<bool> sendRating(int stars, String comment) async {
    try {
      final id = await _playerId();
      for (var i = 0; i < 2; i++) {
        final r = await _http
            .post(
              Uri.parse('$_url/rating'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({'id': id, 'stars': stars, 'comment': comment, 'platform': _platform}),
            )
            .timeout(const Duration(seconds: 10));
        if (r.statusCode == 204) {
          await (await SharedPreferences.getInstance()).setInt('chacha243.stars', stars);
          return true;
        }
        if (r.statusCode != 404) return false;
        // the pilot does not exist on the server yet: a first report creates it
        await hello();
      }
    } catch (_) {}
    return false;
  }

  /// The stars this pilot gave before, or 0.
  static Future<int> myStars() async {
    try {
      return (await SharedPreferences.getInstance()).getInt('chacha243.stars') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// The pilot's place in the ranking; null when offline or not known yet.
  static const _standingBox = 'chacha243.standing';

  /// The pilot's place. Offline, the last standing the phone knew comes back marked [Standing.stale]
  /// (null when there never was one), and the screen asks again by itself.
  static Future<Standing?> standing() async {
    try {
      final id = await _playerId();
      final r = await _http
          .get(Uri.parse('$_url?id=${Uri.encodeQueryComponent(id)}'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final s = (jsonDecode(r.body) as Map<String, dynamic>)['standing'] as Map<String, dynamic>?;
        if (s != null) {
          final st = Standing.fromJson(s);
          try {
            await (await SharedPreferences.getInstance()).setString(_standingBox, jsonEncode(st.toJson()));
          } catch (_) {}
          return st;
        }
      }
    } catch (_) {}
    try {
      final j = (await SharedPreferences.getInstance()).getString(_standingBox);
      if (j != null) return Standing.fromJson(jsonDecode(j) as Map<String, dynamic>, stale: true);
    } catch (_) {}
    return null;
  }

  /// A jump asked from the dashboard for this pilot (the designer): the resume point moves to that year, once.
  /// Forward or back (2016, 2017, 2018, 2023…): the designer chose it. The server forgets the jump once it was taken.
  static Future<void> jump() async {
    try {
      final id = await _playerId();
      final r = await _http
          .get(Uri.parse('$_url?id=${Uri.encodeQueryComponent(id)}'))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final y = (b['jump'] as num?)?.toDouble();
      if (y == null || y < 1961 || y > 2027) return;
      final cur = await Checkpoint.load();
      await jumpedCheckpoint(y, cur).save();
      // The designer jumps to watch again: the cards and scenes already seen come back.
      await Checkpoint.saveSeen(const {});
      await _post({'kind': 'jumped', 'year': y});
    } catch (_) {}
  }

  /// The resume point after a jump to [year]: the medals of the moments passed, the money and flight time kept.
  @visibleForTesting
  static Checkpoint jumpedCheckpoint(double year, Checkpoint? cur) => Checkpoint(
    year,
    math.max(cur?.score ?? 0, 0),
    () {
      // Medals of the moments passed before [year]; a pilot already further keeps theirs when jumping ahead only.
      final passed = historyEvents
          .where((e) => e.year < year && (e.kind == EventKind.life || e.kind == EventKind.glory))
          .length;
      return cur != null && cur.year < year ? math.max(cur.medals, passed) : passed;
    }(),
    money: cur?.money ?? 3000,
    seconds: cur?.seconds ?? 0,
  );

  /// The pilot's secret code, shown as K7M2-Q9XD; null without a connection or before the first report.
  static Future<String?> pilotCode() async {
    try {
      final r = await http
          .post(
            Uri.parse('$_url/code'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'id': await _playerId()}),
          )
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return null;
      final c = (jsonDecode(r.body) as Map<String, dynamic>)['code'] as String;
      return '${c.substring(0, 4)}-${c.substring(4)}';
    } catch (_) {
      return null;
    }
  }

  /// Brings a pilot back on this phone from their code. True when the code was right.
  static Future<bool> claimCode(String code) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_url/code'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return false;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final id = b['id'] as String;
      await (await SharedPreferences.getInstance()).setString(_keptId, id);
      _id = id;
      await savePilotName((b['name'] as String?)?.trim() ?? 'Pilote');
      final m = b['missions'];
      if (m is int && m > missionsDone.value) await saveMissions(m);
      if (b['photo'] == true) {
        final ph = await http
            .get(Uri.parse('$_url/photo?id=${Uri.encodeQueryComponent(id)}'))
            .timeout(const Duration(seconds: 6));
        if (ph.statusCode == 200 && ph.bodyBytes.length > 100) await savePilotPhoto(ph.bodyBytes);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// After a reinstall: no name on the phone yet, so ask the server for the pilot's name and resume point.
  static Future<void> restore() async {
    if (pilotName.value != null) return;
    try {
      final id = await _playerId();
      final r = await http
          .get(Uri.parse('$_url?id=${Uri.encodeQueryComponent(id)}'))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final name = (b['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return;
      await savePilotName(name);
      final m = b['missions'];
      if (m is int && m > missionsDone.value) await saveMissions(m);
      if (b['photo'] == true) {
        final ph = await http
            .get(Uri.parse('$_url/photo?id=${Uri.encodeQueryComponent(id)}'))
            .timeout(const Duration(seconds: 6));
        if (ph.statusCode == 200 && ph.bodyBytes.length > 100) await savePilotPhoto(ph.bodyBytes);
      }
      // Le point de reprise ne revient pas : sur un téléphone neuf, le premier vol part toujours de 1960.
    } catch (_) {}
  }
}

/// Where the pilot stands among everyone who flew, as the dashboard ranks them.
class Standing {
  const Standing({
    required this.rank,
    required this.total,
    required this.bestYear,
    required this.bestScore,
    required this.wins,
    required this.crashes,
    required this.flights,
    required this.seconds,
    this.stale = false,
  });

  final int rank, total, bestScore, wins, crashes, flights, seconds;
  final double bestYear;

  /// True when the phone is offline and this is the last standing it knew.
  final bool stale;

  Map<String, Object> toJson() => {
    'rank': rank,
    'total': total,
    'bestYear': bestYear,
    'bestScore': bestScore,
    'wins': wins,
    'crashes': crashes,
    'flights': flights,
    'seconds': seconds,
  };

  static Standing fromJson(Map<String, dynamic> s, {bool stale = false}) {
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;
    return Standing(
      rank: n('rank'),
      total: n('total'),
      bestYear: (s['bestYear'] as num?)?.toDouble() ?? 1960,
      bestScore: n('bestScore'),
      wins: n('wins'),
      crashes: n('crashes'),
      flights: n('flights'),
      seconds: n('seconds'),
      stale: stale,
    );
  }
}

/// A message from the dashboard: the champion, the rewards.
class News {
  const News(this.id, this.title, this.body, this.reward, this.champion, this.championYear, this.photo, this.seconds);

  final int id;
  final String title, body, reward;
  final String? champion;
  final int? championYear;
  final Uint8List? photo;

  /// The champion's flight time from 1960 to 2027, when the message announces a winner.
  final int seconds;
}

/// A championship opened from the dashboard: the prize is written there, never in the game.
class Championship {
  const Championship(this.title, this.prize, this.first, this.ends);

  final String title, prize;

  /// The first to arrive wins; otherwise the fastest flight from 1960 to 2027.
  final bool first;
  final DateTime? ends;
}

/// One of the five best pilots.
class TopPilot {
  const TopPilot(this.place, this.name, this.year, this.arrived, this.score, this.photo);

  final int place, year, score;
  final String name;
  final bool arrived;
  final Uint8List? photo;
}
