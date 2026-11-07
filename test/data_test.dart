import 'package:chacha243/data/archive.dart';
import 'package:chacha243/data/history_events.dart';
import 'package:chacha243/data/war_zones.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les données de l'histoire se tiennent : dans l'ordre, sans photo ni chanson introuvable.
void main() {
  test('les événements sont dans l\'ordre des années', () {
    for (var i = 1; i < historyEvents.length; i++) {
      expect(
        historyEvents[i].year >= historyEvents[i - 1].year,
        isTrue,
        reason: '${historyEvents[i].title} (${historyEvents[i].year}) avant ${historyEvents[i - 1].title}',
      );
    }
  });

  test('chaque photo et chaque chanson d\'un événement existe', () {
    for (final e in historyEvents) {
      if (e.photo != null) expect(archivePhotos.containsKey(e.photo), isTrue, reason: '${e.title} : photo ${e.photo}');
      if (e.song != null) expect(momentSongs.containsKey(e.song), isTrue, reason: '${e.title} : chanson ${e.song}');
    }
  });

  test('une chanson qui en enchaîne une autre la trouve', () {
    for (final s in momentSongs.entries) {
      if (s.value.then != null) expect(momentSongs.containsKey(s.value.then), isTrue, reason: s.key);
      expect(s.value.level, inInclusiveRange(0, 1), reason: s.key);
    }
  });

  test('les annonces courtes tiennent sur une ligne', () {
    for (final e in historyEvents) {
      if (e.intro != null) expect(e.intro!.length, lessThanOrEqualTo(70), reason: e.title);
    }
  });

  test('les zones de guerre se suivent sans se chevaucher', () {
    for (var i = 0; i < warZones.length; i++) {
      expect(warZones[i].to > warZones[i].from, isTrue, reason: warZones[i].name);
      if (i > 0) expect(warZones[i].from >= warZones[i - 1].to, isTrue, reason: warZones[i].name);
    }
  });

  test('la guerre de l\'AFDL part de l\'est du Congo', () {
    final afdl = warZones.firstWhere((z) => z.name.contains('AFDL'));
    expect(afdl.place, contains('est du Congo'));
  });

  test('la monnaie suit les dates de la Banque centrale', () {
    expect(currencyAt(1960.5), 'F');
    expect(currencyAt(1971), 'Z');
    expect(currencyAt(1994), 'NZ');
    expect(currencyAt(1998.4), 'NZ');
    expect(currencyAt(1998.6), 'FC');
    expect(currencyAt(2026), 'FC');
  });

  test('1990, 1997 et 2001 sont racontés', () {
    final emotion = historyEvents.firstWhere((e) => e.title.contains('Comprenez mon émotion'));
    expect(emotion.year.floor(), 1990);
    expect(emotion.text, contains('multipartisme'));
    expect(emotion.photo, 'emotion');
    final mzee = historyEvents.firstWhere((e) => e.title.contains('Mzee') && e.title.contains('assassiné'));
    expect(mzee.date, '16 janvier 2001');
    final oath = historyEvents.firstWhere((e) => e.title.contains('Joseph Kabila prête serment'));
    expect(oath.date, '26 janvier 2001');
    expect(oath.year > mzee.year, isTrue);
    expect(historyEvents.firstWhere((e) => e.title.contains('Outeniqua')).text, contains('Mandela'));
  });
}
