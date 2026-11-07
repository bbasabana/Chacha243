import 'package:chacha243/app_state.dart';
import 'package:chacha243/ui/about_screen.dart';
import 'package:chacha243/ui/hangar_screen.dart';
import 'package:chacha243/ui/home_screen.dart';
import 'package:chacha243/ui/timeline_screen.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// L'accueil tient sur chaque écran de téléphone, couché : petit Android, TECNO, iPhone avec son îlot.
/// Un élément qui dépasse (« overflowed ») fait échouer le test.
void main() {
  // Largeur × hauteur en points, et la marge que le système réserve (îlot, barre du bas).
  const phones = <String, (Size, EdgeInsets)>{
    'petit Android 640 × 360': (Size(640, 360), EdgeInsets.zero),
    'TECNO KM7k 800 × 360': (Size(800, 360), EdgeInsets.zero),
    'iPhone SE 667 × 375': (Size(667, 375), EdgeInsets.zero),
    'iPhone 17 Pro 874 × 402': (Size(874, 402), EdgeInsets.fromLTRB(62, 0, 62, 21)),
    'iPhone 17 Pro Max 956 × 440': (Size(956, 440), EdgeInsets.fromLTRB(62, 0, 62, 21)),
    'iPad 1180 × 820': (Size(1180, 820), EdgeInsets.fromLTRB(0, 24, 0, 20)),
  };

  // La vraie police, celle du téléphone : la police des tests, plus large, ferait déborder tous les textes.
  setUpAll(() async {
    final dir = '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    final roboto = FontLoader('Roboto');
    for (final w in ['Thin', 'Light', 'Regular', 'Medium', 'Bold', 'Black']) {
      final f = File('$dir/Roboto-$w.ttf');
      if (f.existsSync()) roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await roboto.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Ni son ni capteurs dans les tests : les canaux répondent sans rien faire.
    for (final c in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global', 'chacha243/device']) {
      m.setMockMethodCallHandler(MethodChannel(c), (_) async => null);
    }
  });

  final screens = <String, Widget Function()>{
    'l\'accueil': () => const HomeScreen(),
    'le hangar': () => const HangarScreen(),
    'les dates': () => const TimelineScreen(),
    'à propos': () => const AboutScreen(),
  };

  for (final p in phones.entries) {
    for (final sc in screens.entries) {
      testWidgets('${sc.key} tient sur ${p.key}', (tester) async {
        await loadProfile();
        await savePilotName('Bbasabana');
        final (size, pad) = p.value;
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(
          left: pad.left * 3,
          top: pad.top * 3,
          right: pad.right * 3,
          bottom: pad.bottom * 3,
        );
        tester.view.viewPadding = tester.view.padding;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(home: sc.value()));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
