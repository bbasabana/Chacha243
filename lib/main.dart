import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'data/aircraft_types.dart';
import 'theme/chacha_colors.dart';
import 'ui/game_screen.dart';
import 'ui/hangar_screen.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadProfile();
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
      home: switch (Uri.base.queryParameters) {
        {'demo': '1'} && final q => GameScreen(type: selectedAircraft.value = aircraftById(q['avion'] ?? 'dc6')),
        {'ecran': 'hangar'} => const HangarScreen(),
        _ => const HomeScreen(),
      },
    );
  }
}
