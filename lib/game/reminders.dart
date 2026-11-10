import '../ui/onboarding_screen.dart';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Les rappels du jeu, préparés sur le téléphone : rien ne passe par un serveur.
/// À chaque ouverture, le calendrier repart à zéro : un joueur qui revient n'est pas relancé pour son absence.
class Reminders {
  Reminders._();

  static const _asked = 'notifications_asked';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _launches = 'reminders_launches';

  /// Les jours d'absence après lesquels on écrit, en alternant français et lingala.
  static const _absentDays = [3, 6, 10, 15, 21];
  static const _weekends = 4;

  static const _absent = [
    ('Commandant, votre avion vous attend', 'Cela fait quelques jours que vous n\'avez pas joué à Chacha 243.'),
    ('Chacha 243', 'Esali mikolo ebele obeti Jeu te. Mpepo na yo ezali kozela yo.'),
    (
      'Votre voyage continue',
      'Objectif : arriver à Kinshasa le 30 juin 2027. Reprenez les commandes quand vous voulez.',
    ),
    ('Chacha 243', 'Commandant, zonga ! Kinshasa ezali kozela yo, 30 juin 2027.'),
    ('Un moment d\'histoire vous attend', 'Quelques minutes de vol pour redécouvrir l\'histoire du Congo.'),
  ];

  static const _friday = [
    ('C\'est vendredi, commandant', 'Un petit vol pour bien commencer le week-end ?'),
    ('Mokolo ya mitano', 'Commandant, ya kobeta Chacha 243 mwa moke ?'),
  ];

  static const _saturday = [
    (
      'Un petit jeu en famille ?',
      'Faites jouer vos enfants : ils découvriront les grands moments du pays en s\'amusant.',
    ),
    ('Weekend elamu', 'Tika bana na yo babeta Chacha 243, bayeba lisolo ya ekolo na biso.'),
  ];

  static NotificationDetails _details(int count) => NotificationDetails(
    android: AndroidNotificationDetails(
      'rappels_jeu',
      'Rappels',
      channelDescription: 'Les invitations à reprendre le vol',
      icon: '@mipmap/ic_launcher_monochrome',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      channelShowBadge: true,
      number: count,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true, badgeNumber: count),
  );

  /// Une erreur de rappel ne doit jamais gêner le jeu.
  static Future<void> start() async {
    try {
      tz.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher_monochrome'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      await _askOnce();
      await _clearBadge();
      await _plugin.cancelAll();
      final now = DateTime.now();
      final plan = <(DateTime, (String, String))>[];
      for (final (i, days) in _absentDays.indexed) {
        final at = DateTime(now.year, now.month, now.day + days, 18, 30);
        // Le vendredi et le samedi ont déjà leur message.
        if (at.weekday == DateTime.friday || at.weekday == DateTime.saturday) continue;
        plan.add((at, _absent[i]));
      }
      for (var week = 0; week < _weekends; week++) {
        final fromToday = (DateTime.friday - now.weekday) % 7 + week * 7;
        final friday = DateTime(now.year, now.month, now.day + fromToday, 18);
        final saturday = DateTime(now.year, now.month, now.day + fromToday + 1, 10);
        plan.add((friday, _friday[week % _friday.length]));
        plan.add((saturday, _saturday[week % _saturday.length]));
      }
      // Dans l'ordre du calendrier : la pastille de l'icône compte 1, 2, 3… tant que le joueur ne revient pas.
      plan.sort((a, b) => a.$1.compareTo(b.$1));
      var id = 0;
      for (final (at, text) in plan.where((p) => p.$1.isAfter(now))) {
        await _at(id, at, text, id + 1);
        id++;
      }
    } catch (_) {}
  }

  /// La demande d'autorisation attend la deuxième ouverture, et jamais par-dessus l'explication du jeu.
  static Future<void> _askOnce() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_launches, (p.getInt(_launches) ?? 0) + 1);
    if (!Onboarding.pending) await askIfDue();
  }

  /// Appelé aussi quand le joueur quitte l'explication.
  static Future<void> askIfDue() async {
    final p = await SharedPreferences.getInstance();
    if ((p.getInt(_launches) ?? 0) < 2 || (p.getBool(_asked) ?? false)) return;
    await p.setBool(_asked, true);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Le joueur est revenu : la pastille disparaît de l'icône (Android le fait seul avec les notifications).
  static Future<void> _clearBadge() async {
    if (!Platform.isIOS) return;
    await _plugin.show(
      id: 900,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentList: false,
          presentSound: false,
          presentBadge: true,
          badgeNumber: 0,
        ),
      ),
    );
  }

  static Future<void> _at(int id, DateTime when, (String, String) text, int count) async {
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
      notificationDetails: _details(count),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: text.$1,
      body: text.$2,
    );
  }
}
