import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';

/// Tells the Chacha 243 board on waddiel.pro how a flight goes: takeoff, each new year, a failure, the arrival.
/// The player is an anonymous id made on this phone, with the pilot name typed in the game. Never blocks the game.
class Telemetry {
  Telemetry._();

  static const _url = 'https://waddiel.pro/api/v1/chacha';
  static const _version = '1.0.0';
  static String? _id;

  static Future<String> _playerId() async {
    if (_id != null) return _id!;
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

  static Future<void> send(
    String kind, {
    required double year,
    int score = 0,
    String stage = '',
    String detail = '',
  }) async {
    try {
      final body = jsonEncode({
        'id': await _playerId(),
        'kind': kind,
        'name': pilotName.value ?? '',
        'platform': _platform,
        'version': _version,
        'year': year,
        'score': score,
        'stage': stage,
        'detail': detail,
      });
      await http
          .post(Uri.parse(_url), headers: {'content-type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
