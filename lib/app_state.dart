import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/aircraft_types.dart';

/// La version App Store : ni don, ni championnat à prix, ni enjeu, ni lien vers une autre boutique (règles d'Apple).
bool get appStoreRules => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// L'avion choisi pour le décollage de 1960 (parmi ceux qui volaient en 1960).
final selectedAircraft = ValueNotifier<AircraftType>(aircraftById('dc6'));

/// Le nom du pilote, demandé une seule fois puis gardé sur le téléphone.
final pilotName = ValueNotifier<String?>(null);

/// La photo du pilote (un petit JPEG), choisie avec son nom ; elle part aussi au classement en ligne.
final pilotPhoto = ValueNotifier<Uint8List?>(null);
const _kPhoto = 'chacha243.photo';

Future<void> savePilotPhoto(Uint8List? bytes) async {
  pilotPhoto.value = bytes;
  try {
    final p = await SharedPreferences.getInstance();
    bytes == null ? await p.remove(_kPhoto) : await p.setString(_kPhoto, base64Encode(bytes));
  } catch (_) {}
}

/// Volume de la musique (0 à 1), réglable depuis l'accueil.
final musicVolume = ValueNotifier<double>(0.7);

/// Les réglages du vol : la musique, les petits sons, les vibrations (tout est allumé au départ).
final musicOn = ValueNotifier<bool>(true);
final soundsOn = ValueNotifier<bool>(true);
final vibrationsOn = ValueNotifier<bool>(true);

const _kMusicOn = 'chacha243.musique', _kSoundsOn = 'chacha243.sons', _kVibrationsOn = 'chacha243.vibrations';

/// Allume ou éteint un réglage, et le garde sur le téléphone.
Future<void> saveSwitch(ValueNotifier<bool> which, bool on) async {
  which.value = on;
  final key = identical(which, musicOn)
      ? _kMusicOn
      : identical(which, soundsOn)
      ? _kSoundsOn
      : _kVibrationsOn;
  try {
    await (await SharedPreferences.getInstance()).setBool(key, on);
  } catch (_) {}
}

/// Missions de passagers réussies : le titre de « bon pilote » grandit avec elles.
final missionsDone = ValueNotifier<int>(0);

/// Les vols déjà faits, du plus récent au plus ancien : le joueur retrouve son historique.
final flights = ValueNotifier<List<FlightRecord>>(const []);

const _kName = 'chacha243.pilote', _kVolume = 'chacha243.volume', _kMissions = 'chacha243.missions';
const _kFlights = 'chacha243.vols';

/// Un vol terminé : arrivé le 30 juin 2027, ou arrêté en route.
class FlightRecord {
  const FlightRecord(this.date, this.score, this.medals, this.money, this.currency, this.won, this.year);

  final DateTime date;
  final int score, medals, money;
  final String currency;
  final bool won;

  /// L'année où le vol s'est arrêté (2027.5 pour une arrivée).
  final double year;

  String encode() => [date.toIso8601String(), score, medals, money, currency, won ? 1 : 0, year].join('|');

  static FlightRecord? decode(String v) {
    final f = v.split('|');
    if (f.length != 7) return null;
    try {
      return FlightRecord(
        DateTime.parse(f[0]),
        int.parse(f[1]),
        int.parse(f[2]),
        int.parse(f[3]),
        f[4],
        f[5] == '1',
        double.parse(f[6]),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Le meilleur score parmi les vols gardés.
int get bestScore => flights.value.fold(0, (b, f) => f.score > b ? f.score : b);

/// Garde le vol en tête de l'historique (les 20 derniers).
Future<void> saveFlight(FlightRecord f) async {
  flights.value = [f, ...flights.value].take(20).toList();
  try {
    await (await SharedPreferences.getInstance()).setStringList(_kFlights, [for (final r in flights.value) r.encode()]);
  } catch (_) {}
}

Future<void> loadProfile() async {
  try {
    final p = await SharedPreferences.getInstance();
    pilotName.value = p.getString(_kName);
    final photo = p.getString(_kPhoto);
    if (photo != null) pilotPhoto.value = base64Decode(photo);
    musicVolume.value = p.getDouble(_kVolume) ?? 0.7;
    musicOn.value = p.getBool(_kMusicOn) ?? true;
    soundsOn.value = p.getBool(_kSoundsOn) ?? true;
    vibrationsOn.value = p.getBool(_kVibrationsOn) ?? true;
    missionsDone.value = p.getInt(_kMissions) ?? 0;
    flights.value = [for (final v in p.getStringList(_kFlights) ?? const <String>[]) ?FlightRecord.decode(v)];
  } catch (_) {}
}

Future<void> savePilotName(String name) async {
  pilotName.value = name;
  try {
    await (await SharedPreferences.getInstance()).setString(_kName, name);
  } catch (_) {}
}

Future<void> saveVolume(double v) async {
  musicVolume.value = v;
  try {
    await (await SharedPreferences.getInstance()).setDouble(_kVolume, v);
  } catch (_) {}
}

/// Les missions retrouvées après une réinstallation.
Future<void> saveMissions(int n) async {
  missionsDone.value = n;
  try {
    await (await SharedPreferences.getInstance()).setInt(_kMissions, n);
  } catch (_) {}
}

Future<void> addMission() async {
  missionsDone.value++;
  try {
    await (await SharedPreferences.getInstance()).setInt(_kMissions, missionsDone.value);
  } catch (_) {}
}

/// Le titre du pilote selon ses missions réussies.
String pilotRank(int missions) => switch (missions) {
  0 => 'Élève pilote',
  < 3 => 'Copilote',
  < 8 => 'Commandant',
  < 15 => 'Bon pilote',
  _ => 'Très bon pilote',
};
