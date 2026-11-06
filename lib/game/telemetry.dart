import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import 'checkpoint.dart';

/// Tells the Chacha 243 board on waddiel.pro how a flight goes: takeoff, each new year, a failure, the arrival.
/// It also keeps a copy of the pilot's name and resume point there, so a reinstalled game finds them again.
/// The player id comes from the phone (Android keeps it across reinstalls). Never blocks the game.
class Telemetry {
  Telemetry._();

  static const _url = 'https://waddiel.pro/api/v1/chacha';
  static const _version = '1.0.0';
  static const _channel = MethodChannel('chacha243/device');
  static String? _id;
  static Map<String, String> _device = const {};

  /// The phone's id and details, read once.
  static Future<String> _playerId() async {
    if (_id != null) return _id!;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final m = await _channel.invokeMapMethod<String, String>('info');
        if (m != null) {
          _device = m;
          final a = m['id'] ?? '';
          if (a.length >= 8) return _id = 'a-$a';
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

  static Future<void> _post(Map<String, Object?> body) async {
    try {
      final id = await _playerId();
      await http
          .post(
            Uri.parse(_url),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'name': pilotName.value ?? '',
              'platform': _platform,
              'version': _version,
              'device': {
                for (final k in const ['brand', 'manufacturer', 'model', 'os', 'operator', 'sim', 'simCountry'])
                  k: _device[k] ?? '',
              },
              'missions': missionsDone.value,
              ...body,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static Future<void> send(String kind, {required double year, int score = 0, String stage = '', String detail = ''}) =>
      _post({'kind': kind, 'year': year, 'score': score, 'stage': stage, 'detail': detail});

  /// Keeps the resume point on the server too (null once the flight reached 2027).
  static Future<void> saveProgress(Checkpoint? cp) => _post({
    'kind': 'save',
    'year': cp?.year ?? 1960,
    'save': cp == null ? null : {'year': cp.year, 'score': cp.score, 'medals': cp.medals, 'money': cp.money},
  });

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
      final s = b['save'];
      if (s is Map<String, dynamic>) {
        await Checkpoint(
          (s['year'] as num).toDouble(),
          (s['score'] as num).toInt(),
          (s['medals'] as num).toInt(),
          money: (s['money'] as num).toInt(),
        ).save(sync: false);
      }
    } catch (_) {}
  }
}
