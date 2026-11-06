import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'data/aircraft_types.dart';
import 'game/telemetry.dart';
import 'theme/chacha_colors.dart';
import 'ui/game_screen.dart';
import 'ui/hangar_screen.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadProfile();
  // Réinstallé ? Le nom du pilote et son point de reprise reviennent depuis le serveur.
  if (!kIsWeb) await Telemetry.restore();
  if (!kIsWeb) Telemetry.hello();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const Chacha243App());
}

class Chacha243App extends StatelessWidget {
  const Chacha243App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chacha243',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ChachaColors.sky,
          brightness: Brightness.dark,
          primary: ChachaColors.sky,
          secondary: ChachaColors.yellow,
          error: ChachaColors.red,
        ),
        scaffoldBackgroundColor: ChachaColors.night,
        useMaterial3: true,
      ),
      // `?demo=1&avion=b747` ouvre directement un vol en pilote automatique.
      // `?ecran=hangar` ouvre le hangar.
      // Le jeu se joue couché. Sur le web, on ne peut pas tourner l'écran : on demande de tourner le téléphone.
      builder: (context, child) {
        final size = MediaQuery.sizeOf(context);
        if (size.height <= size.width) return child!;
        if (kIsWeb && size.width <= 700) return const _TurnPhone();
        if (kIsWeb) return child!;
        // Sur le téléphone, si le système tourne quand même l'écran en portrait (en voiture, un réglage
        // du constructeur…), le jeu reste couché : on le dessine tourné d'un quart de tour.
        final mq = MediaQuery.of(context);
        return RotatedBox(
          quarterTurns: 1,
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(size.height, size.width),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: child!,
          ),
        );
      },
      home: switch (Uri.base.queryParameters) {
        {'demo': '1'} && final q => GameScreen(type: selectedAircraft.value = aircraftById(q['avion'] ?? 'dc6')),
        {'ecran': 'hangar'} => const HangarScreen(),
        _ => const HomeScreen(),
      },
    );
  }
}

class _TurnPhone extends StatelessWidget {
  const _TurnPhone();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ChachaColors.night,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screen_rotation_rounded, color: ChachaColors.yellow, size: 64),
            SizedBox(height: 16),
            Text(
              'Tourne ton téléphone',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text('Chacha243 se joue en paysage', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
