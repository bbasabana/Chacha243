import 'package:chacha243/app_state.dart';
import 'package:chacha243/ui/about_screen.dart';
import 'package:chacha243/ui/duel_screen.dart';
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

  // Les fenêtres de note et de proposition défilent : aucun écran, même petit ou avec le clavier ouvert, ne déborde.
  for (final p in phones.entries) {
    for (final label in ['Noter l\'application', 'Proposer une photo, une date']) {
      testWidgets('« $label » tient sur ${p.key}', (tester) async {
        await loadProfile();
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
        await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
        await tester.pump(const Duration(seconds: 1));
        final button = find.text(label);
        await tester.scrollUntilVisible(button, 100, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text(label == 'Noter l\'application' ? 'Pesa note na yo' : 'Proposer au jeu'), findsOneWidget);
      });
    }
  }

  // Le duel : le guide, les règles, le menu et la création d'une salle tiennent sur chaque écran.
  for (final p in phones.entries) {
    for (final step in ['guide', 'règles', 'menu', 'création']) {
      testWidgets('le duel (« $step ») tient sur ${p.key}', (tester) async {
        SharedPreferences.setMockInitialValues({
          if (step != 'guide') 'chacha243.guide': true,
          if (step == 'menu' || step == 'création') 'chacha243.duelTerms': 1,
        });
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
        await tester.runAsync(() async {
          await tester.pumpWidget(const MaterialApp(home: DuelScreen()));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump(const Duration(seconds: 1));
        if (step == 'création') {
          await tester.tap(find.text('Créer un duel'));
          await tester.pump(const Duration(seconds: 1));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
