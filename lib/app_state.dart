import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/aircraft_types.dart';

/// L'avion choisi pour le décollage de 1960 (parmi ceux qui volaient en 1960).
final selectedAircraft = ValueNotifier<AircraftType>(aircraftById('dc6'));

/// Le nom du pilote, demandé une seule fois puis gardé sur le téléphone.
final pilotName = ValueNotifier<String?>(null);

/// Volume de la musique (0 à 1), réglable depuis l'accueil.
final musicVolume = ValueNotifier<double>(0.7);

/// Missions de passagers réussies : le titre de « bon pilote » grandit avec elles.
final missionsDone = ValueNotifier<int>(0);

const _kName = 'chacha243.pilote', _kVolume = 'chacha243.volume', _kMissions = 'chacha243.missions';

Future<void> loadProfile() async {
  try {
    final p = await SharedPreferences.getInstance();
    pilotName.value = p.getString(_kName);
    musicVolume.value = p.getDouble(_kVolume) ?? 0.7;
    missionsDone.value = p.getInt(_kMissions) ?? 0;
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
